import { fail } from './http.js';

const api = async (env, method, body) => {
  if (!env.CF_API_TOKEN || !env.CF_ZONE_ID) fail(501, 'catch-all control needs the CF_API_TOKEN secret and CF_ZONE_ID var');
  const res = await fetch(`https://api.cloudflare.com/client/v4/zones/${env.CF_ZONE_ID}/email/routing/rules/catch_all`, {
    method,
    headers: { authorization: `Bearer ${env.CF_API_TOKEN}`, 'content-type': 'application/json' },
    body: body && JSON.stringify(body),
  });
  const data = await res.json();
  if (!data.success) fail(502, `cloudflare: ${data.errors?.map((e) => e.message).join(', ')}`);
  return data.result;
};

const workerName = (env) => env.WORKER_NAME || 'bridgewood-mail';
const routesToWorker = (env, rule) =>
  rule.enabled && rule.actions?.some((a) => a.type === 'worker' && a.value?.includes(workerName(env)));
const shape = (env, rule) => ({ toWorker: routesToWorker(env, rule), enabled: rule.enabled, actions: rule.actions });

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
