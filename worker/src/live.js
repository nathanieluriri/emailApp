import { fail } from './http.js';

const hub = (env, address) => env.HUB.get(env.HUB.idFromName(address.toLowerCase()));

export function live({ env, req, mailbox }) {
  if (!env.HUB) fail(501, 'live updates are not set up on this server');
  if (!mailbox) fail(400, 'X-Mailbox is required');
  if (req.headers.get('upgrade')?.toLowerCase() !== 'websocket') fail(426, 'expected a websocket');
  return hub(env, mailbox).fetch(req);
}

// Tells the phones of each mailbox that something in it changed.
export function touch(env, ctx, addresses) {
  if (!env?.HUB) return;
  for (const address of new Set(addresses.filter(Boolean).map((a) => a.toLowerCase()))) {
    const done = hub(env, address).changed().catch((e) => console.error('live update failed', e));
    if (ctx) ctx.waitUntil(done);
  }
}
