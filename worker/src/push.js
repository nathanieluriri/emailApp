import { fail } from './http.js';
import { routeHere } from './routing.js';
import { replyTo } from './send.js';
import { touch } from './live.js';

const QUIET_MS = 60_000;
const EARLIER_LINES = 3;
const REMIND_AFTER = [3_600_000, 86_400_000];
const REMIND_GAP = 12 * 3_600_000;
const REMIND_WITHIN = 3 * 86_400_000;
const AWAKE_HOURS = [8, 21];
const LIST_LINES = 6;
const enc = new TextEncoder();

const clip = (s, n) => (s && s.length > n ? `${s.slice(0, n - 1).trimEnd()}…` : s || '');
const sender = (m) => m.from_name || m.from_addr;
const fnv = (s) => [...s].reduce((h, c) => Math.imul(h ^ c.charCodeAt(0), 16777619) >>> 0, 2166136261).toString(36);

async function hostOf(env, db) {
  return env.PUBLIC_HOST || (await db.first("SELECT value FROM meta WHERE key = 'host'"))?.value;
}

const TOKEN_DAYS = 30;

async function mac(env, text) {
  const key = await crypto.subtle.importKey('raw', enc.encode(`actions:${env.API_KEYS}`), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(text)));
  return btoa(String.fromCharCode(...sig.slice(0, 18))).replace(/\+/g, '-').replace(/\//g, '_');
}

// A notification's buttons act on one mailbox's copy of one conversation, for a month.
async function sign(env, threadId, address) {
  const expires = Math.floor(Date.now() / 1000 + TOKEN_DAYS * 86400).toString(36);
  return `${expires}.${await mac(env, `${threadId}\n${address}\n${expires}`)}`;
}

async function verify(env, threadId, address, token) {
  const [expires, sig] = String(token || '').split('.');
  if (!expires || !sig || parseInt(expires, 36) * 1000 < Date.now()) return false;
  const expected = enc.encode(await mac(env, `${threadId}\n${address}\n${expires}`));
  const given = enc.encode(sig);
  return given.byteLength === expected.byteLength && crypto.subtle.timingSafeEqual(given, expected);
}

const onesignal = (env, path, init = {}) =>
  fetch(`https://api.onesignal.com${path}`, {
    ...init,
    headers: { authorization: `Key ${env.ONESIGNAL_REST_KEY}`, 'content-type': 'application/json' },
  });

// Phones sign in to OneSignal with a device id that survives reinstalls, so mail targets the phone, not one install.
const toDevices = (ids) => ({ include_aliases: { external_id: ids }, target_channel: 'push' });

async function send(env, body) {
  const res = await onesignal(env, '/notifications', { method: 'POST', body: JSON.stringify({ app_id: env.ONESIGNAL_APP_ID, ...body }) });
  const out = await res.json().catch(() => ({}));
  const errors = Array.isArray(out.errors) ? out.errors : out.errors ? Object.keys(out.errors) : [];
  if (!res.ok || !out.id) throw Object.assign(new Error(`OneSignal: ${errors.join(', ') || res.status}`), { status: 502 });
  return out;
}

function mailNotification({ host, account, messages, quiet, token, kind = 'mail', reminder = false }) {
  const latest = messages[messages.length - 1];
  const subject = latest.subject || '(no subject)';
  return {
    headings: { en: sender(latest) },
    subtitle: { en: subject },
    contents: { en: clip(latest.snippet, 180) || subject },
    data: {
      kind,
      host,
      account,
      threadId: latest.thread_id,
      messageId: latest.id,
      subject: clip(subject, 120),
      quiet: quiet ? 1 : 0,
      ...(token && { token }),
      ...(reminder && { reminder: 1 }),
      lines: messages.map((m) => ({
        from: sender(m),
        address: m.from_addr,
        out: m.from_addr?.toLowerCase() === account ? 1 : 0,
        text: clip(m.snippet, 160),
        at: m.date,
      })),
    },
    collapse_id: `t-${latest.thread_id}-${fnv(account)}`,
    android_group: account,
    android_group_message: { en: '$[notif_count] new emails' },
    existing_android_channel_id: 'mail_chime',
    priority: 10,
    thread_id: account,
    summary_arg: account,
    ios_interruption_level: quiet ? 'passive' : 'active',
    ios_badgeType: 'Increase',
    ios_badgeCount: 1,
  };
}

export async function notifyNewMail(env, db, id, addresses) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) return;
  const host = await hostOf(env, db);
  const m = host && (await db.first('SELECT * FROM messages WHERE id = ?', id));
  if (!m) return;
  for (const account of addresses) {
    const devices = await db.all('SELECT device_id FROM device_mailboxes WHERE address = ?', account);
    if (!devices.length) continue;
    const recent = await db.first(
      `SELECT count(*) AS n FROM messages m JOIN message_owners o ON o.message_id = m.id AND o.address = ? AND o.role = 'to'
       WHERE m.created_at < ? AND m.created_at > ?`,
      account, m.created_at, m.created_at - QUIET_MS,
    );
    await send(env, {
      ...toDevices(devices.map((d) => d.device_id)),
      ...mailNotification({
        host,
        account,
        messages: await withEarlier(db, m, account),
        quiet: recent.n > 0,
        token: await sign(env, m.thread_id, account),
      }),
    });
  }
}

async function withEarlier(db, m, account) {
  const earlier = await db.all(
    `SELECT m.id, m.thread_id, m.direction, m.from_addr, m.from_name, m.subject, m.snippet, m.date FROM messages m
     WHERE m.thread_id = ? AND m.id != ? AND m.date <= ? AND m.id IN (SELECT message_id FROM message_owners WHERE address = ?)
     ORDER BY m.date DESC LIMIT ${EARLIER_LINES}`,
    m.thread_id, m.id, m.date, account,
  );
  return [...earlier.reverse(), m];
}

// Unread inbox mail is pushed again an hour after it arrived and once more a day later, while the phone's owner is
// likely awake. One notification per mailbox: a single conversation comes back as itself, several as a list.
export async function remindUnread(env, db, now = Date.now()) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) return;
  const host = await hostOf(env, db);
  if (!host) return;
  const phones = await db.all(
    `SELECT d.address, d.device_id, coalesce(v.utc_offset, 0) AS utc_offset FROM device_mailboxes d
     LEFT JOIN devices v ON v.device_id = d.device_id WHERE coalesce(v.remind, 1) = 1`,
  );
  const awake = (offset) => {
    const hour = new Date(now + offset * 60_000).getUTCHours();
    return hour >= AWAKE_HOURS[0] && hour < AWAKE_HOURS[1];
  };
  const mailboxes = new Map();
  for (const p of phones.filter((p) => awake(p.utc_offset))) mailboxes.set(p.address, [...(mailboxes.get(p.address) ?? []), p.device_id]);

  for (const [account, devices] of mailboxes) {
    const due = await db.all(
      `SELECT m.* FROM messages m
       JOIN message_owners o ON o.message_id = m.id AND o.address = ? AND o.role = 'to'
       LEFT JOIN reminders r ON r.message_id = m.id AND r.address = o.address
       WHERE m.read = 0 AND m.created_at > ?
         AND m.id IN (SELECT message_id FROM message_labels WHERE label_id = 'inbox')
         AND m.id NOT IN (SELECT message_id FROM message_labels WHERE label_id IN ('trash', 'spam'))
         AND m.id NOT IN (SELECT message_id FROM message_owners WHERE address = ? AND role = 'from')
         AND ((r.sent IS NULL AND m.created_at <= ?) OR (r.sent = 1 AND m.created_at <= ? AND r.at <= ?))
       ORDER BY m.date DESC`,
      account, now - REMIND_WITHIN, account, now - REMIND_AFTER[0], now - REMIND_AFTER[1], now - REMIND_GAP,
    );
    if (!due.length) continue;
    const threads = new Map();
    for (const m of due) if (!threads.has(m.thread_id)) threads.set(m.thread_id, m);
    const newest = [...threads.values()];
    const [m] = newest;
    await send(env, {
      ...toDevices(devices),
      ...(newest.length === 1
        ? mailNotification({ host, account, messages: await withEarlier(db, m, account), token: await sign(env, m.thread_id, account), reminder: true })
        : unreadList(host, account, newest)),
    });
    await db.batch(
      due.map((x) => [
        `INSERT INTO reminders (message_id, address, sent, at) VALUES (?, ?, 1, ?)
         ON CONFLICT (message_id, address) DO UPDATE SET sent = sent + 1, at = excluded.at`,
        x.id, account, now,
      ]),
    );
  }
}

function unreadList(host, account, newest) {
  const title = `${newest.length} unread emails`;
  return {
    headings: { en: title },
    contents: { en: clip([...new Set(newest.map(sender))].join(', '), 120) },
    data: {
      kind: 'unread',
      host,
      account,
      subject: title,
      more: Math.max(0, newest.length - LIST_LINES),
      lines: newest.slice(0, LIST_LINES).map((m) => ({ from: sender(m), address: m.from_addr, out: 0, text: clip(m.subject || '(no subject)', 90), at: m.date })),
    },
    collapse_id: `u-${fnv(account)}`,
    android_group: account,
    android_group_message: { en: '$[notif_count] new emails' },
    existing_android_channel_id: 'mail_chime',
    priority: 10,
    thread_id: account,
    summary_arg: account,
    ios_interruption_level: 'active',
  };
}

export async function notifyReaction(env, db, target, account, who, emoji) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) return;
  const devices = await db.all('SELECT device_id FROM device_mailboxes WHERE address = ?', account);
  const host = devices.length && (await hostOf(env, db));
  if (!host) return;
  await send(env, {
    ...toDevices(devices.map((d) => d.device_id)),
    ...mailNotification({
      host,
      account,
      kind: 'reaction',
      quiet: true,
      messages: [{ ...target, from_name: who, from_addr: '', snippet: `${emoji} reacted to "${clip(target.snippet, 90)}"`, date: Date.now() }],
    }),
    collapse_id: `r-${target.id}-${fnv(account)}`,
  });
}

export async function registerDevice({ env, db, req, params, ctx }) {
  const { addresses = [], subscriptionId, utcOffset = 0, remind = true } = await req.json().catch(() => ({}));
  const list = [...new Set(addresses.map((a) => String(a).trim().toLowerCase()).filter(Boolean))];
  const offset = Number.isFinite(+utcOffset) ? Math.max(-840, Math.min(840, Math.round(+utcOffset))) : 0;
  await db.batch([
    ['DELETE FROM device_mailboxes WHERE device_id = ?', params.id],
    ...list.map((a) => ['INSERT INTO device_mailboxes (device_id, address, updated_at) VALUES (?, ?, ?)', params.id, a, Date.now()]),
    [
      `INSERT INTO devices (device_id, utc_offset, remind, updated_at) VALUES (?, ?, ?, ?)
       ON CONFLICT (device_id) DO UPDATE SET utc_offset = excluded.utc_offset, remind = excluded.remind, updated_at = excluded.updated_at`,
      params.id, offset, remind === false ? 0 : 1, Date.now(),
    ],
  ]);
  if (subscriptionId) ctx.waitUntil(pruneSubscriptions(env, params.id, subscriptionId).catch((e) => console.error('prune failed', e)));
  ctx.waitUntil(routeHere(env, db, list).catch((e) => console.error('routing failed', e)));
  return { ok: true, addresses: list };
}

// Each reinstall leaves its old subscription on the phone's OneSignal user; keep only the live one.
async function pruneSubscriptions(env, device, keep) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) return;
  const res = await onesignal(env, `/apps/${env.ONESIGNAL_APP_ID}/users/by/external_id/${encodeURIComponent(device)}`);
  if (!res.ok) return;
  const { subscriptions = [] } = await res.json();
  const stale = subscriptions.filter((s) => s.id !== keep && /Push$/.test(s.type || ''));
  await Promise.all(stale.map((s) => onesignal(env, `/apps/${env.ONESIGNAL_APP_ID}/subscriptions/${s.id}`, { method: 'DELETE' })));
}

export async function testPush({ env, db, req, url, mailbox }) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) fail(503, 'OneSignal is not configured on the worker');
  const { device, subscriptionId } = await req.json().catch(() => ({}));
  if (!device && !subscriptionId) fail(400, '"device" is required');
  const linked = device ? (await db.all('SELECT address FROM device_mailboxes WHERE device_id = ?', device)).map((r) => r.address) : [];
  const host = (await hostOf(env, db)) || url.host;
  const account = mailbox || linked[0] || `hello@${env.ALLOWED_DOMAIN}`;
  const now = Date.now();
  const line = (from, snippet, date) => ({ id: 'test', thread_id: 'test', direction: 'in', from_addr: `hello@${env.ALLOWED_DOMAIN}`, from_name: from, subject: 'Notifications are on', snippet, date });
  const out = await send(env, {
    ...(device ? toDevices([device]) : { include_subscription_ids: [subscriptionId] }),
    ...mailNotification({
      host,
      account,
      kind: 'test',
      messages: [
        line('Quirepost', 'This is how new mail shows up: who sent it, the subject and the first lines.', now - 60_000),
        line('Quirepost', 'Replies in the same conversation stack here, so you can follow the thread at a glance.', now),
      ],
    }),
    collapse_id: `test-${fnv(device || subscriptionId)}`,
  });
  return { ok: true, id: out.id, linked };
}

const asHtml = (text) =>
  `<div>${text.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]).replace(/\n/g, '<br>')}</div>`;

export async function act({ env, db, req, params, ctx }) {
  const { token, address = '', text = '', messageId } = await req.json().catch(() => ({}));
  if (!(await verify(env, params.thread, address, token))) fail(403, 'invalid token');
  if (!['read', 'archive', 'reply'].includes(params.action)) fail(404, 'unknown action');
  const mine = "id IN (SELECT message_id FROM message_owners WHERE address = ? AND role = 'to')";
  if (params.action === 'reply') {
    if (!text.trim()) fail(400, 'reply text is required');
    const orig = await db.first(
      `SELECT * FROM messages WHERE thread_id = ? AND ${mine} ${messageId ? 'AND id = ?' : ''} ORDER BY date DESC LIMIT 1`,
      params.thread, address, ...(messageId ? [messageId] : []),
    );
    if (!orig) fail(404, 'message not found');
    const named = await db.first(
      "SELECT from_name FROM messages WHERE from_addr = ? AND direction = 'out' AND from_name IS NOT NULL ORDER BY date DESC LIMIT 1",
      address,
    );
    await replyTo(env, db, orig, { from: address, fromName: named?.from_name || '', text: text.trim(), html: asHtml(text.trim()) }, address, ctx);
  }
  const stmts = [[`UPDATE messages SET read = 1 WHERE thread_id = ? AND ${mine}`, params.thread, address]];
  if (params.action === 'archive') {
    stmts.push(
      [`UPDATE messages SET archived = 1 WHERE thread_id = ? AND ${mine}`, params.thread, address],
      [`DELETE FROM message_labels WHERE label_id = 'inbox' AND message_id IN (SELECT id FROM messages WHERE thread_id = ? AND ${mine})`, params.thread, address],
    );
  }
  await db.batch(stmts);
  touch(env, ctx, [address]);
  return { ok: true };
}
