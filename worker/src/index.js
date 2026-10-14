import { createDb } from './db.js';
import { CORS, json } from './http.js';
import { receive } from './inbound.js';
import { routes } from './routes.js';

function authorized(req, env) {
  const token = req.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
  const keys = (env.API_KEYS || '').split(',').map((k) => k.trim()).filter(Boolean);
  return !!token && keys.includes(token);
}

export default {
  async fetch(req, env, ctx) {
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const url = new URL(req.url);
    const pathname = url.pathname.replace(/\/+$/, '') || '/';

    for (const r of routes) {
      const match = r.method === req.method && pathname.match(r.re);
      if (!match) continue;
      if (!r.public && !authorized(req, env)) return json({ error: 'unauthorized' }, 401);
      try {
        const params = Object.fromEntries(Object.entries(match.groups || {}).map(([k, v]) => [k, decodeURIComponent(v)]));
        const result = await r.handler({ req, env, ctx, url, params, db: createDb(env), routes });
        return result instanceof Response ? result : json(result);
      } catch (e) {
        if (!e.status) console.error(e);
        return json({ error: e.message }, e.status || 500);
      }
    }
    return json({ error: 'not found' }, 404);
  },

  email: (message, env, ctx) => receive(message, env, ctx),
};
