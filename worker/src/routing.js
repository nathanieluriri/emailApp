import { fail } from './http.js';

const rules = async (env, method, path = '', body) => {
  if (!env.CF_API_TOKEN || !env.CF_ZONE_ID) fail(501, 'mail routing needs the CF_API_TOKEN secret and CF_ZONE_ID var');
  const res = await fetch(`https://api.cloudflare.com/client/v4/zones/${env.CF_ZONE_ID}/email/routing/rules${path}`, {
    method,
    headers: { authorization: `Bearer ${env.CF_API_TOKEN}`, 'content-type': 'application/json' },
    body: body && JSON.stringify(body),
  });
  const data = await res.json();
  if (!data.success) fail(502, `cloudflare: ${data.errors?.map((e) => e.message).join(', ')}`);
  return data.result;
};
const api = (env, method, body) => rules(env, method, '/catch_all', body);

const workerName = (env) => env.WORKER_NAME || 'bridgewood-mail';
const routesToWorker = (env, rule) =>
  rule.enabled && rule.actions?.some((a) => a.type === 'worker' && a.value?.includes(workerName(env)));
const shape = (env, rule) => ({ toWorker: routesToWorker(env, rule), enabled: rule.enabled, actions: rule.actions });

// Mail to an address without a rule of its own falls to the zone's catch-all, so every address the app uses gets one.
// Addresses that already have a rule pointing elsewhere are left alone.
export async function routeHere(env, db, addresses) {
  const domain = `@${(env.ALLOWED_DOMAIN || '').toLowerCase()}`;
  const ours = [...new Set(addresses.map((a) => String(a).toLowerCase()))].filter((a) => a.endsWith(domain));
  if (!ours.length || !env.CF_API_TOKEN || !env.CF_ZONE_ID) return;
  const known = await db.all(`SELECT address FROM routed_addresses WHERE address IN (${ours.map(() => '?').join(',')})`, ...ours);
  const missing = ours.filter((a) => !known.some((k) => k.address === a));
  if (!missing.length) return;
  const existing = new Map(
    (await rules(env, 'GET', '?per_page=50')).flatMap((r) =>
      r.matchers.filter((m) => m.type === 'literal' && m.field === 'to').map((m) => [m.value.toLowerCase(), r])),
  );
  for (const address of missing) {
    const rule = existing.get(address);
    if (!rule) {
      await rules(env, 'POST', '', {
        name: `${address.split('@')[0]} to ${workerName(env)}`,
        enabled: true,
        matchers: [{ type: 'literal', field: 'to', value: address }],
        actions: [{ type: 'worker', value: [workerName(env)] }],
      });
    }
    if (!rule || routesToWorker(env, rule)) {
      await db.run('INSERT OR IGNORE INTO routed_addresses (address, routed_at) VALUES (?, ?)', address, Date.now());
    }
  }
}

export async function getCatchAll({ env }) {
  return shape(env, await api(env, 'GET'));
}

export async function setCatchAll({ env, db, req }) {
  const token = req.headers.get('authorization').split(/\s+/)[1];
  const allowed = (env.ROUTING_KEYS || '').split(',').map((k) => k.trim()).filter(Boolean);
  if (allowed.length && !allowed.includes(token)) fail(403, 'this API key cannot change routing');

  const { toWorker } = await req.json();
  const current = await api(env, 'GET');
  if (!!toWorker === routesToWorker(env, current)) return shape(env, current);

  let next;
  if (toWorker) {
    await db.run("INSERT OR REPLACE INTO meta (key, value) VALUES ('catch_all_backup', ?)", JSON.stringify(current));
    next = { matchers: [{ type: 'all' }], actions: [{ type: 'worker', value: [workerName(env)] }], enabled: true };
  } else {
    const saved = await db.first("SELECT value FROM meta WHERE key = 'catch_all_backup'");
    const backup = saved && JSON.parse(saved.value);
    next = backup
      ? { matchers: backup.matchers, actions: backup.actions, enabled: backup.enabled }
      : { matchers: [{ type: 'all' }], actions: [{ type: 'drop' }], enabled: false };
  }
  return shape(env, await api(env, 'PUT', { name: current.name || '', ...next }));
}
