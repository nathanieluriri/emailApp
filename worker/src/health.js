export const VERSION = '1.0.0';

async function check(fn) {
  try {
    return (await fn()) !== false;
  } catch {
    return false;
  }
}

export async function health({ env, db, url, ctx, routes }) {
  const checks = {
    db: await check(() => db.first('SELECT count(*) AS n FROM labels')),
    r2: await check(() => env.FILES.head('health').then(() => true)),
    email: typeof env.EMAIL?.send === 'function',
    onesignal: !!(env.ONESIGNAL_APP_ID && env.ONESIGNAL_REST_KEY),
  };
  if (checks.db) ctx.waitUntil(db.run("INSERT OR REPLACE INTO meta (key, value) VALUES ('host', ?)", url.host).catch(() => {}));
  return {
    ok: Object.values(checks).every(Boolean),
    service: 'bridgewood-mail',
    version: VERSION,
    domain: env.ALLOWED_DOMAIN,
    routes: routes.map((r) => r.signature),
    checks,
  };
}
