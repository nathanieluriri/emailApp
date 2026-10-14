import { snippetOf, htmlToText } from './text.js';

const splitRefs = (s) => (s ? s.match(/<[^>]+>/g) || [] : []);

async function resolveThread(db, inReplyTo, references) {
  const refs = [...new Set([inReplyTo, ...splitRefs(references)].filter(Boolean))];
  if (!refs.length) return null;
  const row = await db.first(
    `SELECT thread_id FROM messages WHERE message_id_header IN (${refs.map(() => '?').join(',')}) LIMIT 1`,
    ...refs,
  );
  return row?.thread_id ?? null;
}

export async function storeMessage(db, env, m) {
  if (m.messageIdHeader && (await db.first('SELECT id FROM messages WHERE message_id_header = ?', m.messageIdHeader))) {
    return null;
  }
  const id = crypto.randomUUID();
  const now = Date.now();
  const date = m.date || now;
  const threadId = (await resolveThread(db, m.inReplyTo, m.references)) || crypto.randomUUID();
  const text = m.text || htmlToText(m.html);

  const attachments = await Promise.all(
    (m.attachments || []).map(async (a) => {
      const attId = crypto.randomUUID();
      const key = `att/${id}/${attId}`;
      await env.FILES.put(key, a.content, { httpMetadata: { contentType: a.mimeType } });
      return { id: attId, key, ...a, size: a.content.byteLength ?? a.content.length };
    }),
  );

  await db.batch([
    [
      `INSERT INTO threads (id, subject, last_message_at, message_count) VALUES (?, ?, ?, 1)
       ON CONFLICT(id) DO UPDATE SET last_message_at = MAX(last_message_at, excluded.last_message_at), message_count = message_count + 1`,
      threadId, m.subject || '', date,
    ],
    [
      `INSERT INTO messages (id, thread_id, message_id_header, in_reply_to, references_hdr, direction, from_addr, from_name,
        to_json, cc_json, bcc_json, subject, snippet, html, text, date, created_at, read, has_attachments)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      id, threadId, m.messageIdHeader || null, m.inReplyTo || null, m.references || null, m.direction,
      m.from, m.fromName || null, JSON.stringify(m.to || []), JSON.stringify(m.cc || []), JSON.stringify(m.bcc || []),
      m.subject || '', snippetOf(text), m.html || null, text, date, now, m.read ? 1 : 0, attachments.length ? 1 : 0,
    ],
    ...m.labels.map((l) => ['INSERT OR IGNORE INTO message_labels (message_id, label_id) VALUES (?, ?)', id, l]),
    ...attachments.map((a) => [
      'INSERT INTO attachments (id, message_id, filename, mime_type, size, content_id, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?)',
      a.id, id, a.filename || 'attachment', a.mimeType || 'application/octet-stream', a.size, a.contentId || null, a.key,
    ]),
  ]);
  return { id, threadId };
}
