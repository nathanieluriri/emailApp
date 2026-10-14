const WINDOW_MS = 60_000;

export async function notifyNewMail(env, db) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) return;
  const host = env.PUBLIC_HOST || (await db.first("SELECT value FROM meta WHERE key = 'host'"))?.value;
  if (!host) return;

  const recent = await db.all(
    "SELECT id, thread_id, from_name, from_addr, subject FROM messages WHERE direction = 'in' AND created_at > ? ORDER BY created_at",
    Date.now() - WINDOW_MS,
  );
  if (!recent.length) return;
  const latest = recent[recent.length - 1];
  const single = recent.length === 1;

  const res = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: { authorization: `Key ${env.ONESIGNAL_REST_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      app_id: env.ONESIGNAL_APP_ID,
      filters: [
        { field: 'tag', key: 'worker_host', relation: '=', value: host },
        { operator: 'OR' },
        { field: 'tag', key: `wh_${host}`, relation: 'exists' },
      ],
      headings: { en: single ? latest.from_name || latest.from_addr : `${recent.length} new emails` },
      contents: {
        en: single
          ? latest.subject || '(no subject)'
          : [...new Set(recent.map((m) => m.from_name || m.from_addr))].slice(0, 3).join(', '),
      },
      data: single ? { host, messageId: latest.id, threadId: latest.thread_id } : { host },
      collapse_id: `mail-${recent[0].id}`.slice(0, 64),
      thread_id: host,
      android_group: host,
    }),
  });
  if (!res.ok) throw new Error(`onesignal ${res.status}: ${await res.text()}`);
}
