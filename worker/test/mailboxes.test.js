import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { timingSafeEqual } from 'node:crypto';

import worker from '../src/index.js';
import { createDb } from '../src/db.js';
import { receive } from '../src/inbound.js';
import { send } from '../src/send.js';
import { listMessages, getThread } from '../src/mail.js';
import { listLabels } from '../src/labels.js';
import { registerDevice, act } from '../src/push.js';
import { routeHere } from '../src/routing.js';

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
async function arrive(envelopeTo, { from, to, cc, subject, body, id = `<m${++tick}@ext.com>`, inReplyTo }) {
  const headers = [`From: ${from}`, `To: ${to}`, cc && `Cc: ${cc}`, `Subject: ${subject}`, `Message-ID: ${id}`,
    inReplyTo && `In-Reply-To: ${inReplyTo}`, `Date: ${new Date(Date.now() + ++tick * 1000).toUTCString()}`];
  await receive({ raw: `${headers.filter(Boolean).join('\r\n')}\r\n\r\n${body}`, to: envelopeTo, from }, env, ctx);
  await Promise.all(waits.splice(0));
}
const req = (body) => ({ json: async () => body, headers: new Headers() });
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
  assert.deepEqual(await list('nat@bw.ng', 'sent'), ['out:Memo:1', 'out:Visit:1']);
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
  assert.deepEqual((await res.json()).messages.map((m) => m.subject), ['Memo', 'Visit']);

  sqlite.exec('DELETE FROM message_owners');
  sqlite.exec(schema);
  assert.deepEqual(await list('nat@bw.ng', 'sent'), ['out:Memo:1', 'out:Visit:2']);
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
