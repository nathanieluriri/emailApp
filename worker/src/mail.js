import { fail, parseJson } from './http.js';

const PAGE = 50;
const LIST_COLUMNS = `m.id, m.thread_id, m.direction, m.from_addr, m.from_name, m.to_json, m.subject, m.snippet, m.date,
  m.read, m.starred, m.archived, m.has_attachments,
  (SELECT message_count FROM threads WHERE id = m.thread_id) AS thread_count,
  (SELECT group_concat(label_id) FROM message_labels WHERE message_id = m.id) AS label_ids`;

const summary = (m) => ({
  id: m.id,
  threadId: m.thread_id,
  direction: m.direction,
  from: { address: m.from_addr, name: m.from_name || '' },
  to: parseJson(m.to_json, []),
  subject: m.subject,
  snippet: m.snippet,
  date: m.date,
  read: !!m.read,
  starred: !!m.starred,
  archived: !!m.archived,
  hasAttachments: !!m.has_attachments,
  threadCount: m.thread_count ?? 1,
  labels: m.label_ids ? m.label_ids.split(',') : [],
});

const detail = (m, attachments) => ({
  ...summary(m),
  cc: parseJson(m.cc_json, []),
  bcc: parseJson(m.bcc_json, []),
  messageIdHeader: m.message_id_header,
  inReplyTo: m.in_reply_to,
  html: m.html,
  text: m.text,
  attachments: attachments.map((a) => ({
    id: a.id,
    filename: a.filename,
    mimeType: a.mime_type,
    size: a.size,
    contentId: a.content_id,
  })),
});

const ftsQuery = (q) =>
  q.split(/\s+/).filter(Boolean).map((w) => `"${w.replace(/"/g, '""')}"*`).join(' ');

export async function listMessages({ db, url }) {
  const s = url.searchParams;
  const label = s.get('label') || 'inbox';
  const where = [];
  const params = [];

  if (label === 'starred') where.push('m.starred = 1');
  else if (label !== 'all') {
    where.push('m.id IN (SELECT message_id FROM message_labels WHERE label_id = ?)');
    params.push(label);
  }
  if (label !== 'trash' && label !== 'spam' && label !== 'all') {
    where.push("m.id NOT IN (SELECT message_id FROM message_labels WHERE label_id IN ('trash', 'spam'))");
  }
  const q = s.get('q')?.trim();
  if (q) {
    where.push('m.rowid IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH ?)');
    params.push(ftsQuery(q));
  }
  if (['1', 'true'].includes(s.get('unread'))) where.push('m.read = 0');
  const cursor = s.get('cursor');
  if (cursor) {
    const [date, id] = cursor.split('_');
    where.push('(m.date < ? OR (m.date = ? AND m.id < ?))');
    params.push(+date, +date, id);
  }

  const rows = await db.all(
    `SELECT ${LIST_COLUMNS} FROM messages m ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
     ORDER BY m.date DESC, m.id DESC LIMIT ${PAGE + 1}`,
    ...params,
  );
  const page = rows.slice(0, PAGE);
  const last = page[page.length - 1];
  return {
    messages: page.map(summary),
    nextCursor: rows.length > PAGE ? `${last.date}_${last.id}` : null,
  };
}

async function loadMessages(db, column, value) {
  const rows = await db.all(`SELECT m.*, ${LIST_COLUMNS} FROM messages m WHERE m.${column} = ? ORDER BY m.date`, value);
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const atts = await db.all(
    `SELECT * FROM attachments WHERE message_id IN (${ids.map(() => '?').join(',')})`,
    ...ids,
  );
  return rows.map((r) => detail(r, atts.filter((a) => a.message_id === r.id)));
}

export async function getMessage({ db, params }) {
  const [m] = await loadMessages(db, 'id', params.id);
  return m || fail(404, 'message not found');
}

export async function getThread({ db, params }) {
  const thread = await db.first('SELECT * FROM threads WHERE id = ?', params.id);
  if (!thread) fail(404, 'thread not found');
  return {
    id: thread.id,
    subject: thread.subject,
    lastMessageAt: thread.last_message_at,
    messageCount: thread.message_count,
    messages: await loadMessages(db, 'thread_id', params.id),
  };
}

export async function patchMessage({ db, req, params }) {
  const b = await req.json();
  const id = params.id;
  if (!(await db.first('SELECT id FROM messages WHERE id = ?', id))) fail(404, 'message not found');
  const stmts = [];
  const flag = (key) => {
    if (typeof b[key] === 'boolean') stmts.push([`UPDATE messages SET ${key} = ? WHERE id = ?`, b[key] ? 1 : 0, id]);
  };
  ['read', 'starred', 'archived'].forEach(flag);
  if (Array.isArray(b.labels)) {
    stmts.push(['DELETE FROM message_labels WHERE message_id = ?', id]);
    b.labels.forEach((l) => stmts.push(['INSERT OR IGNORE INTO message_labels (message_id, label_id) SELECT ?, id FROM labels WHERE id = ?', id, l]));
  }
  if (b.archived === true) stmts.push(["DELETE FROM message_labels WHERE message_id = ? AND label_id = 'inbox'", id]);
  if (b.archived === false) stmts.push(["INSERT OR IGNORE INTO message_labels (message_id, label_id) VALUES (?, 'inbox')", id]);
  if (stmts.length) await db.batch(stmts);
  return getMessage({ db, params });
}

export async function getAttachment({ db, env, params }) {
  const a = await db.first('SELECT * FROM attachments WHERE id = ?', params.id);
  if (!a) fail(404, 'attachment not found');
  const obj = await env.FILES.get(a.r2_key);
  if (!obj) fail(404, 'attachment content missing');
  return new Response(obj.body, {
    headers: {
      'content-type': a.mime_type,
      'content-disposition': `inline; filename="${(a.filename || 'attachment').replace(/"/g, '')}"`,
      'access-control-allow-origin': '*',
    },
  });
}
