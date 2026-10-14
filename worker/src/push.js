import { fail } from './http.js';

const QUIET_MS = 60_000;
const EARLIER_LINES = 3;
const enc = new TextEncoder();

const clip = (s, n) => (s && s.length > n ? `${s.slice(0, n - 1).trimEnd()}…` : s || '');
const sender = (m) => m.from_name || m.from_addr;
const fnv = (s) => [...s].reduce((h, c) => Math.imul(h ^ c.charCodeAt(0), 16777619) >>> 0, 2166136261).toString(36);

async function hostOf(env, db) {
  return env.PUBLIC_HOST || (await db.first("SELECT value FROM meta WHERE key = 'host'"))?.value;
}

async function sign(env, threadId, address) {
  const key = await crypto.subtle.importKey('raw', enc.encode(`actions:${env.API_KEYS}`), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(`${threadId}\n${address}`)));
  return btoa(String.fromCharCode(...mac.slice(0, 18))).replace(/\+/g, '-').replace(/\//g, '_');
}

async function send(env, body) {
  const res = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: { authorization: `Key ${env.ONESIGNAL_REST_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ app_id: env.ONESIGNAL_APP_ID, ...body }),
  });
  const out = await res.json().catch(() => ({}));
  const errors = Array.isArray(out.errors) ? out.errors : out.errors ? Object.keys(out.errors) : [];
  if (!res.ok || !out.id) throw Object.assign(new Error(`OneSignal: ${errors.join(', ') || res.status}`), { status: 502 });
  return out;
}

function mailNotification({ host, account, messages, quiet, token, kind = 'mail' }) {
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
    existing_android_channel_id: 'mail',
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
    const devices = await db.all('SELECT subscription_id FROM devices WHERE address = ?', account);
    if (!devices.length) continue;
    const earlier = await db.all(
      `SELECT m.id, m.thread_id, m.direction, m.from_addr, m.from_name, m.subject, m.snippet, m.date FROM messages m
       WHERE m.thread_id = ? AND m.id != ? AND m.date <= ? AND m.id IN (SELECT message_id FROM message_owners WHERE address = ?)
       ORDER BY m.date DESC LIMIT ${EARLIER_LINES}`,
      m.thread_id, id, m.date, account,
    );
    const recent = await db.first(
      `SELECT count(*) AS n FROM messages m JOIN message_owners o ON o.message_id = m.id AND o.address = ? AND o.role = 'to'
       WHERE m.created_at < ? AND m.created_at > ?`,
      account, m.created_at, m.created_at - QUIET_MS,
    );
    await send(env, {
      include_subscription_ids: devices.map((d) => d.subscription_id),
      ...mailNotification({
        host,
        account,
        messages: [...earlier.reverse(), m],
        quiet: recent.n > 0,
        token: await sign(env, m.thread_id, account),
      }),
    });
  }
}

export async function registerDevice({ db, req, params }) {
  const { addresses = [] } = await req.json().catch(() => ({}));
  const list = [...new Set(addresses.map((a) => String(a).trim().toLowerCase()).filter(Boolean))];
  await db.batch([
    ['DELETE FROM devices WHERE subscription_id = ?', params.id],
    ...list.map((a) => ['INSERT INTO devices (subscription_id, address, updated_at) VALUES (?, ?, ?)', params.id, a, Date.now()]),
  ]);
  return { ok: true, addresses: list };
}

export async function testPush({ env, db, req, url, mailbox }) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) fail(503, 'OneSignal is not configured on the worker');
  const { subscriptionId } = await req.json().catch(() => ({}));
  if (!subscriptionId) fail(400, '"subscriptionId" is required');
  const host = (await hostOf(env, db)) || url.host;
  const account = mailbox || `hello@${env.ALLOWED_DOMAIN}`;
  const now = Date.now();
  const line = (from, snippet, date) => ({ id: 'test', thread_id: 'test', direction: 'in', from_addr: `hello@${env.ALLOWED_DOMAIN}`, from_name: from, subject: 'Notifications are on', snippet, date });
  const out = await send(env, {
    include_subscription_ids: [subscriptionId],
    ...mailNotification({
      host,
      account,
      kind: 'test',
      messages: [
        line('Quirepost', 'This is how new mail shows up: who sent it, the subject and the first lines.', now - 60_000),
        line('Quirepost', 'Replies in the same conversation stack here, so you can follow the thread at a glance.', now),
      ],
    }),
    collapse_id: `test-${subscriptionId}`.slice(0, 64),
  });
  return { ok: true, id: out.id };
}

export async function act({ env, db, req, params }) {
  const { token, address = '' } = await req.json().catch(() => ({}));
  const expected = enc.encode(await sign(env, params.thread, address));
  const given = enc.encode(token || '');
  if (given.byteLength !== expected.byteLength || !crypto.subtle.timingSafeEqual(given, expected)) fail(403, 'invalid token');
  if (!['read', 'archive'].includes(params.action)) fail(404, 'unknown action');
  const mine = "id IN (SELECT message_id FROM message_owners WHERE address = ? AND role = 'to')";
  const stmts = [[`UPDATE messages SET read = 1 WHERE thread_id = ? AND ${mine}`, params.thread, address]];
  if (params.action === 'archive') {
    stmts.push(
      [`UPDATE messages SET archived = 1 WHERE thread_id = ? AND ${mine}`, params.thread, address],
      [`DELETE FROM message_labels WHERE label_id = 'inbox' AND message_id IN (SELECT id FROM messages WHERE thread_id = ? AND ${mine})`, params.thread, address],
    );
  }
  await db.batch(stmts);
  return { ok: true };
}
