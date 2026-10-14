import { test } from 'node:test';
import assert from 'node:assert/strict';
import { register } from 'node:module';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { timingSafeEqual } from 'node:crypto';

import PostalMime from 'postal-mime';

register(`data:text/javascript,${encodeURIComponent(`
  export async function resolve(specifier, context, next) {
    if (specifier !== 'cloudflare:email') return next(specifier, context);
    const stub = 'export class EmailMessage { constructor(from, to, raw) { Object.assign(this, { from, to, raw }); } }';
    return { url: 'data:text/javascript,' + encodeURIComponent(stub), shortCircuit: true };
  }`)}`);

const { default: worker } = await import('../src/index.js');
import { createDb } from '../src/db.js';
import { receive } from '../src/inbound.js';
import { send, senders } from '../src/send.js';
import { listMessages, getThread, patchThread } from '../src/mail.js';
import { listLabels } from '../src/labels.js';
import { registerDevice, act, remindUnread } from '../src/push.js';
import { routeHere } from '../src/routing.js';
import { react } from '../src/reactions.js';

crypto.subtle.timingSafeEqual ??= (a, b) => timingSafeEqual(a, b);

const schema = readFileSync(new URL('../schema.sql', import.meta.url), 'utf8');
const sqlite = new DatabaseSync(':memory:');
sqlite.exec(schema);

const bind = (p) => p.map((v) => (v === undefined ? null : typeof v === 'boolean' ? +v : v instanceof Uint8Array ? Buffer.from(v) : v));
const stmt = (sql, params = []) => ({
  sql,
  params,
  bind: (...p) => stmt(sql, p),
  all: async () => ({ results: sqlite.prepare(sql).all(...bind(params)) }),
  first: async () => sqlite.prepare(sql).get(...bind(params)) ?? null,
  run: async () => sqlite.prepare(sql).run(...bind(params)),
});
const D1 = {
  prepare: (sql) => stmt(sql),
  batch: async (list) => {
    sqlite.exec('BEGIN');
    try {
      for (const s of list) sqlite.prepare(s.sql).run(...bind(s.params));
      sqlite.exec('COMMIT');
    } catch (e) {
      sqlite.exec('ROLLBACK');
      throw e;
    }
  },
};

const pushes = [];
const deleted = [];
globalThis.fetch = async (url, o = {}) => {
  const path = new URL(url).pathname;
  if (path === '/notifications') {
    pushes.push(JSON.parse(o.body));
    return new Response(JSON.stringify({ id: `n${pushes.length}` }));
  }
  if (path === '/apps/app/users/by/external_id/phone-nat') {
    const subscriptions = [{ id: 'old-install', type: 'AndroidPush' }, { id: 'live', type: 'AndroidPush' }, { id: 'mail', type: 'Email' }];
    return new Response(JSON.stringify({ subscriptions }));
  }
  if (o.method === 'DELETE') deleted.push(path.split('/').pop());
  return new Response('{}', { status: o.method === 'DELETE' ? 202 : 404 });
};
const env = {
  DB: D1,
  ALLOWED_DOMAIN: 'bw.ng',
  PUBLIC_HOST: 'mail.example.dev',
  API_KEYS: 'k1',
  ONESIGNAL_APP_ID: 'app',
  ONESIGNAL_REST_KEY: 'rk',
  FILES: { put: async () => {} },
  EMAIL: { send: async () => ({ messageId: `<${crypto.randomUUID()}@bw.ng>` }) },
};
const db = createDb(env);
const waits = [];
const ctx = { waitUntil: (p) => waits.push(p) };

let tick = 0;
async function arrive(envelopeTo, { from, to, cc, subject, body, id = `<m${++tick}@ext.com>`, inReplyTo, at = Date.now() + ++tick * 1000 }) {
  const headers = [`From: ${from}`, `To: ${to}`, cc && `Cc: ${cc}`, `Subject: ${subject}`, `Message-ID: ${id}`,
    inReplyTo && `In-Reply-To: ${inReplyTo}`, `Date: ${new Date(at).toUTCString()}`];
  await receive({ raw: `${headers.filter(Boolean).join('\r\n')}\r\n\r\n${body}`, to: envelopeTo, from }, env, ctx);
  await Promise.all(waits.splice(0));
}
const req = (body) => ({ json: async () => body, headers: new Headers() });
const rows = async (mailbox, label = 'inbox') =>
  (await listMessages({ db, mailbox, url: new URL(`https://w.dev/messages?label=${label}`) })).messages;
const list = async (mailbox, label = 'inbox', q = '') =>
  (await listMessages({ db, mailbox, url: new URL(`https://w.dev/messages?label=${label}${q}`) })).messages.map(
    (m) => `${m.direction}:${m.subject}:${m.threadCount}`,
  );
const sentTo = () => pushes.splice(0).map((p) => `${p.data.account}>${p.include_aliases.external_id}${p.data.quiet ? ' quiet' : ''}`);

test('each address sees and is notified about its own mail only', async () => {
  await registerDevice({ env, db, ctx, req: req({ addresses: ['Nat@bw.ng'], subscriptionId: 'live' }), params: { id: 'phone-nat' } });
  await registerDevice({ env, db, ctx, req: req({ addresses: ['admin@bw.ng'] }), params: { id: 'phone-admin' } });
  await Promise.all(waits.splice(0));
  assert.deepEqual(deleted, ['old-install']);

  await arrive('admin@bw.ng', { from: 'David <david@x.com>', to: 'admin@bw.ng', subject: 'Application', body: 'Attached' });
  assert.deepEqual(sentTo(), ['admin@bw.ng>phone-admin']);

  const lease = { from: 'Ada <ada@x.com>', to: 'nat@bw.ng', cc: 'admin@bw.ng', subject: 'Lease', body: 'Clause 4', id: '<lease@x.com>' };
  await arrive('nat@bw.ng', lease);
  await arrive('admin@bw.ng', lease);
  assert.deepEqual(sentTo().sort(), ['admin@bw.ng>phone-admin quiet', 'nat@bw.ng>phone-nat']);

  const visit = await send({ env, db, mailbox: 'nat@bw.ng', req: req({ from: 'nat@bw.ng', to: ['tunde@x.com'], subject: 'Visit', text: 'Thursday?' }) });
  const memo = await send({ env, db, mailbox: 'nat@bw.ng', req: req({ from: 'nat@bw.ng', to: ['admin@bw.ng'], subject: 'Memo', text: 'Hi' }) });
  const delivery = { from: 'Nat <nat@bw.ng>', to: 'admin@bw.ng', subject: 'Memo', body: 'Hi', id: memo.messageIdHeader };
  await arrive('admin@bw.ng', delivery);
  await arrive('admin@bw.ng', delivery);
  assert.deepEqual(sentTo(), ['admin@bw.ng>phone-admin quiet']);

  assert.deepEqual(await list('nat@bw.ng'), ['in:Lease:1']);
  assert.deepEqual((await list('nat@bw.ng', 'sent')).sort(), ['out:Memo:1', 'out:Visit:1']);
  assert.deepEqual(await list('admin@bw.ng'), ['in:Lease:1', 'in:Application:1', 'in:Memo:1']);
  assert.deepEqual(await list('admin@bw.ng', 'sent'), []);
  assert.deepEqual(await list('info@bw.ng', 'all'), []);
  assert.deepEqual(await list('admin@bw.ng', 'all', '&q=clause'), ['in:Lease:1']);
  assert.deepEqual(await list('info@bw.ng', 'all', '&q=clause'), []);

  const [memoForAdmin] = (await listMessages({ db, mailbox: 'admin@bw.ng', url: new URL('https://w.dev/messages?label=inbox') })).messages.slice(-1);
  const [memoForNat] = (await listMessages({ db, mailbox: 'nat@bw.ng', url: new URL('https://w.dev/messages?label=sent') })).messages;
  assert.deepEqual([memoForAdmin.read, memoForNat.read], [false, true]);

  const visitHeader = (await db.first('SELECT message_id_header FROM messages WHERE id = ?', visit.id)).message_id_header;
  await arrive('nat@bw.ng', { from: 'Tunde <tunde@x.com>', to: 'nat@bw.ng', subject: 'Re: Visit', body: '2pm', inReplyTo: visitHeader });
  assert.deepEqual(pushes.at(-1).data.lines.map((l) => [l.from, l.out]), [['nat@bw.ng', 1], ['Tunde', 0]]);
  sentTo();
  const thread = await getThread({ db, mailbox: 'nat@bw.ng', params: { id: visit.threadId } });
  assert.deepEqual(thread.messages.map((m) => `${m.direction}:${m.subject}`), ['out:Visit', 'in:Re: Visit']);
  await assert.rejects(getThread({ db, mailbox: 'admin@bw.ng', params: { id: visit.threadId } }), { status: 404 });

  const counts = async (mailbox) =>
    Object.fromEntries((await listLabels({ db, mailbox })).filter((l) => l.system && l.total).map((l) => [l.id, [l.unread, l.total]]));
  assert.deepEqual(await counts('nat@bw.ng'), { inbox: [2, 2], sent: [0, 2] });
  assert.deepEqual(await counts('admin@bw.ng'), { inbox: [3, 3] });

  await arrive('admin@bw.ng', { from: 'David <david@x.com>', to: 'admin@bw.ng', subject: 'Follow up', body: 'News?' });
  const { token, threadId } = pushes.at(-1).data;
  await assert.rejects(act({ env, db, req: req({ token, address: 'nat@bw.ng' }), params: { thread: threadId, action: 'archive' } }), { status: 403 });
  await act({ env, db, req: req({ token, address: 'admin@bw.ng' }), params: { thread: threadId, action: 'archive' } });
  assert.equal((await list('admin@bw.ng')).includes('in:Follow up:1'), false);

  const res = await worker.fetch(
    new Request('https://w.dev/messages?label=sent', { headers: { authorization: 'Bearer k1', 'x-mailbox': 'Nat@BW.ng' } }),
    env,
    ctx,
  );
  assert.deepEqual((await res.json()).messages.map((m) => m.subject).sort(), ['Memo', 'Visit']);

  sqlite.exec('DELETE FROM message_owners');
  sqlite.exec(schema);
  assert.deepEqual((await list('nat@bw.ng', 'sent')).sort(), ['out:Memo:1', 'out:Visit:2']);
});

test('addresses used in the app are routed to the worker unless they already have a rule', async () => {
  const created = [];
  const listed = [
    { matchers: [{ type: 'literal', field: 'to', value: 'admin@bw.ng' }], actions: [{ type: 'worker', value: ['bridgewood-mail'] }], enabled: true },
    { matchers: [{ type: 'literal', field: 'to', value: 'boss@bw.ng' }], actions: [{ type: 'forward', value: ['boss@x.com'] }], enabled: true },
    { matchers: [{ type: 'all' }], actions: [{ type: 'forward', value: ['owner@x.com'] }], enabled: true },
  ];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, o = {}) => {
    if (o.method === 'POST') created.push(JSON.parse(o.body).matchers[0].value);
    return Response.json({ success: true, result: o.method === 'POST' ? {} : listed });
  };
  try {
    const routing = { ...env, CF_API_TOKEN: 't', CF_ZONE_ID: 'z' };
    await routeHere(routing, db, ['Test@bw.ng', 'admin@bw.ng', 'boss@bw.ng', 'someone@x.com']);
    assert.deepEqual(created, ['test@bw.ng']);
    assert.deepEqual((await db.all('SELECT address FROM routed_addresses ORDER BY address')).map((r) => r.address), ['admin@bw.ng', 'test@bw.ng']);
    await routeHere(routing, db, ['test@bw.ng', 'admin@bw.ng']);
    assert.deepEqual(created, ['test@bw.ng']);
  } finally {
    globalThis.fetch = original;
  }
});

test('lists show one row per conversation and act on all of it', async () => {
  await registerDevice({ env, db, ctx, req: req({ addresses: ['amy@bw.ng'] }), params: { id: 'phone-amy' } });
  await arrive('amy@bw.ng', { from: 'Kofi <kofi@x.com>', to: 'amy@bw.ng', subject: 'Plan', body: 'Draft plan', id: '<plan@x.com>' });
  const mine = await send({ env, db, ctx, mailbox: 'amy@bw.ng', req: req({ from: 'amy@bw.ng', fromName: 'Amy', to: ['kofi@x.com'], subject: 'Re: Plan', text: 'Looks good', inReplyTo: '<plan@x.com>' }) });
  await arrive('amy@bw.ng', { from: 'Kofi <kofi@x.com>', to: 'amy@bw.ng', subject: 'Re: Plan', body: 'Thanks', inReplyTo: mine.messageIdHeader });

  const [row] = await rows('amy@bw.ng');
  assert.equal((await rows('amy@bw.ng')).length, 1);
  assert.deepEqual([row.subject, row.threadCount, row.read], ['Re: Plan', 3, false]);
  assert.deepEqual(row.participants.map((p) => [p.name, p.me]).sort(), [['Amy', true], ['Kofi', false]]);

  const change = (body) => patchThread({ db, mailbox: 'amy@bw.ng', req: req(body), params: { id: row.threadId } });
  await change({ archived: true });
  assert.deepEqual(await list('amy@bw.ng'), []);
  assert.deepEqual(await list('amy@bw.ng', 'sent'), ['out:Re: Plan:3']);
  await change({ archived: false });
  await change({ add: ['trash'] });
  assert.deepEqual([await list('amy@bw.ng'), await list('amy@bw.ng', 'trash')], [[], ['in:Re: Plan:3']]);
  await change({ remove: ['trash'] });
  await change({ starred: true, read: true });
  assert.deepEqual([await list('amy@bw.ng'), await list('amy@bw.ng', 'starred')], [['in:Re: Plan:3'], ['in:Re: Plan:3']]);
  assert.equal((await rows('amy@bw.ng'))[0].read, true);
  await change({ starred: false });
  assert.deepEqual(await list('amy@bw.ng', 'starred'), []);
});

test('Gmail reactions land on the message, and ours are sent the way Gmail reads them', async () => {
  const sent = await db.first("SELECT * FROM messages WHERE subject = 'Re: Plan' AND direction = 'out'");
  const before = (await db.first('SELECT count(*) AS n FROM messages')).n;
  const reaction = [
    'From: Kofi <kofi@x.com>', 'To: amy@bw.ng', 'Subject: Re: Plan', 'Message-ID: <react@x.com>', `In-Reply-To: ${sent.message_id_header}`,
    'MIME-Version: 1.0', 'Content-Type: multipart/alternative; boundary="b"', '',
    '--b', 'Content-Type: text/plain; charset="UTF-8"', '', '🎉', '', 'Kofi reacted via Gmail',
    '--b', 'Content-Type: text/vnd.google.email-reaction+json; charset="UTF-8"', '', '{"emoji":"🎉","version":1}',
    '--b', 'Content-Type: text/html; charset="UTF-8"', '', '<p>🎉</p>', '--b--', '',
  ].join('\r\n');
  await receive({ raw: reaction, to: 'amy@bw.ng', from: 'kofi@x.com' }, env, ctx);
  await Promise.all(waits.splice(0));
  assert.equal((await db.first('SELECT count(*) AS n FROM messages')).n, before);
  assert.equal(pushes.at(-1).data.kind, 'reaction');
  const thread = await getThread({ db, mailbox: 'amy@bw.ng', params: { id: sent.thread_id } });
  assert.deepEqual(thread.messages.find((m) => m.id === sent.id).reactions.map((r) => [r.emoji, r.name, r.mine]), [['🎉', 'Kofi', false]]);

  const mails = [];
  const original = env.EMAIL.send;
  env.EMAIL.send = async (m) => mails.push(m);
  try {
    const kofi = thread.messages.at(-1);
    const out = await react({ env, db, mailbox: 'amy@bw.ng', req: req({ emoji: '👍', fromName: 'Amy' }), params: { id: kofi.id } });
    assert.deepEqual(out.reactions.map((r) => [r.emoji, r.mine]), [['👍', true]]);
    assert.deepEqual(mails.map((m) => [m.from, m.to]), [['amy@bw.ng', 'kofi@x.com']]);
    const parsed = await PostalMime.parse(mails[0].raw);
    assert.equal(parsed.inReplyTo, kofi.messageIdHeader);
    const order = ['text/plain', 'text/vnd.google.email-reaction+json', 'text/html'].map((t) => mails[0].raw.indexOf(`Content-Type: ${t}`));
    assert.deepEqual([...order].sort((a, b) => a - b), order);
    const part = parsed.attachments.find((a) => a.mimeType === 'text/vnd.google.email-reaction+json');
    assert.deepEqual(JSON.parse(new TextDecoder().decode(part.content)), { emoji: '👍', version: 1 });
    await assert.rejects(react({ env, db, mailbox: 'amy@bw.ng', req: req({ emoji: '👍👍' }), params: { id: kofi.id } }), { status: 400 });
  } finally {
    env.EMAIL.send = original;
  }
});

test('a notification can reply inline with a token for that mailbox only', async () => {
  const push = pushes.findLast((p) => p.data.kind === 'mail' && p.data.account === 'amy@bw.ng');
  const { token, threadId, messageId } = push.data;
  assert.match(token, /^[0-9a-z]+\.[\w-]+$/);
  const reply = (body) => act({ env, db, ctx, req: req(body), params: { thread: threadId, action: 'reply' } });
  await assert.rejects(reply({ token, address: 'nat@bw.ng', text: 'hi' }), { status: 403 });
  await assert.rejects(reply({ token: `1.${token.split('.')[1]}`, address: 'amy@bw.ng', text: 'hi' }), { status: 403 });
  await reply({ token, address: 'amy@bw.ng', text: 'On it', messageId });
  const sent = (await getThread({ db, mailbox: 'amy@bw.ng', params: { id: threadId } })).messages.find((m) => m.text === 'On it');
  const answered = await db.first('SELECT message_id_header FROM messages WHERE id = ?', messageId);
  assert.deepEqual([sent.direction, sent.from.name, sent.inReplyTo], ['out', 'Amy', answered.message_id_header]);
});

test('my reply brings its conversation back to the top of the inbox, showing what I wrote', async () => {
  const hour = Date.now() - 3_600_000;
  await arrive('zed@bw.ng', { from: 'Ola <ola@x.com>', to: 'zed@bw.ng', subject: 'Lunch', body: 'Free today?', id: '<lunch@x.com>', at: hour });
  await arrive('zed@bw.ng', { from: 'Bisi <bisi@x.com>', to: 'zed@bw.ng', subject: 'Report', body: 'See attached', at: hour + 60_000 });
  const before = await rows('zed@bw.ng');
  assert.deepEqual(before.map((m) => m.subject), ['Report', 'Lunch']);
  await send({ env, db, ctx, mailbox: 'zed@bw.ng', req: req({ from: 'zed@bw.ng', fromName: 'Zed', to: ['ola@x.com'], subject: 'Re: Lunch', text: 'Yes, 1pm', inReplyTo: '<lunch@x.com>' }) });
  const after = await rows('zed@bw.ng');
  assert.deepEqual(after.map((m) => [m.subject, m.direction, m.snippet, m.threadCount]), [['Re: Lunch', 'out', 'Yes, 1pm', 2], ['Report', 'in', 'See attached', 1]]);
  assert.deepEqual(after[0].participants.map((p) => [p.name, p.me]), [['Ola', false], ['Zed', true]]);
  assert.deepEqual(await list('zed@bw.ng', 'sent'), ['out:Re: Lunch:2']);
});

test('unread mail comes back an hour after it lands and once more a day later, in daytime only', async () => {
  const base = Date.now();
  const t1 = base + 2 * 3_600_000;
  const offsetFor = (hour, at) => {
    const shift = (((hour - new Date(at).getUTCHours()) % 24) + 24) % 24;
    return (shift > 12 ? shift - 24 : shift) * 60;
  };
  await registerDevice({ env, db, ctx, req: req({ addresses: ['kemi@bw.ng'], utcOffset: offsetFor(12, t1) }), params: { id: 'phone-kemi' } });
  await registerDevice({ env, db, ctx, req: req({ addresses: ['lola@bw.ng'], utcOffset: offsetFor(2, t1) }), params: { id: 'phone-lola' } });
  await arrive('kemi@bw.ng', { from: 'Tola <tola@x.com>', to: 'kemi@bw.ng', subject: 'Invoice', body: 'Please pay' });
  await arrive('kemi@bw.ng', { from: 'Ife <ife@x.com>', to: 'kemi@bw.ng', subject: 'Lunch?', body: 'Free today?' });
  await arrive('lola@bw.ng', { from: 'Tola <tola@x.com>', to: 'lola@bw.ng', subject: 'Hello', body: 'Hi' });
  pushes.splice(0);
  const phones = ['phone-kemi', 'phone-lola'];
  const ours = () => pushes.splice(0).filter((p) => phones.includes(p.include_aliases.external_id[0]));
  const remind = async (at) => {
    await remindUnread(env, db, at);
    return ours().map((p) => [p.include_aliases.external_id[0], p.data.kind, p.data.reminder ?? 0, p.data.subject]);
  };

  assert.deepEqual(await remind(base + 30 * 60_000), []);
  assert.deepEqual(await remind(t1), [['phone-kemi', 'unread', 0, '2 unread emails']]);
  assert.deepEqual(await remind(t1 + 30 * 60_000), []);
  assert.deepEqual(await remind(t1 + 10 * 3_600_000), [['phone-lola', 'mail', 1, 'Hello']]);

  const lunch = await db.first("SELECT thread_id FROM messages WHERE subject = 'Lunch?'");
  await patchThread({ db, mailbox: 'kemi@bw.ng', req: req({ read: true }), params: { id: lunch.thread_id } });
  await remindUnread(env, db, t1 + 23 * 3_600_000);
  const again = ours();
  assert.deepEqual(again.map((p) => [p.include_aliases.external_id[0], p.data.kind, p.data.subject]), [['phone-kemi', 'mail', 'Invoice']]);
  assert.match(again[0].data.token, /^[0-9a-z]+\.[\w-]+$/);
  assert.deepEqual(await remind(t1 + 47 * 3_600_000), []);
});

test('the server tells the app the name an address goes by', async () => {
  const name = async (mailbox) => (await senders({ env, db, ctx, url: new URL('https://w.dev/senders'), mailbox })).name;
  await arrive('yemi@bw.ng', { from: 'Tola <tola@x.com>', to: 'Yemi Ade <yemi@bw.ng>', subject: 'Welcome', body: 'Hi Yemi' });
  assert.deepEqual([await name('amy@bw.ng'), await name('yemi@bw.ng'), await name('kemi@bw.ng')], ['Amy', 'Yemi Ade', '']);
});
