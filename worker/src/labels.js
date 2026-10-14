import { fail } from './http.js';

const shape = (l) => ({ id: l.id, name: l.name, color: l.color, system: !!l.system, unread: l.unread, total: l.total });

export async function listLabels({ db, mailbox }) {
  const owned = `AND ml.message_id IN (SELECT message_id FROM message_owners WHERE address = ?
    AND role = CASE l.id WHEN 'inbox' THEN 'to' WHEN 'sent' THEN 'from' ELSE role END)`;
  const unsent = "AND ml.message_id NOT IN (SELECT message_id FROM message_owners WHERE address = ? AND role = 'from')";
  const rows = await db.all(
    `SELECT l.*,
      (SELECT count(*) FROM message_labels ml JOIN messages m ON m.id = ml.message_id
        WHERE ml.label_id = l.id AND m.read = 0 ${mailbox ? `${owned} ${unsent}` : ''}) AS unread,
      (SELECT count(*) FROM message_labels ml WHERE ml.label_id = l.id ${mailbox ? owned : ''}) AS total
     FROM labels l ORDER BY l.system DESC, l.name`,
    ...(mailbox ? [mailbox, mailbox, mailbox] : []),
  );
  return rows.map(shape);
}

export async function createLabel({ db, req }) {
  const { name, color = null } = await req.json();
  if (!name?.trim()) fail(400, 'name is required');
  if (await db.first('SELECT id FROM labels WHERE name = ?', name.trim())) fail(409, 'label exists');
  const id = crypto.randomUUID();
  await db.run('INSERT INTO labels (id, name, color) VALUES (?, ?, ?)', id, name.trim(), color);
  return shape({ id, name: name.trim(), color, system: 0, unread: 0, total: 0 });
}

export async function updateLabel({ db, req, params }) {
  const l = await db.first('SELECT * FROM labels WHERE id = ?', params.id);
  if (!l) fail(404, 'label not found');
  const b = await req.json();
  if (l.system && b.name && b.name !== l.name) fail(400, 'system labels cannot be renamed');
  await db.run('UPDATE labels SET name = ?, color = ? WHERE id = ?', b.name?.trim() || l.name, b.color ?? l.color, l.id);
  return shape({ ...l, name: b.name?.trim() || l.name, color: b.color ?? l.color });
}

export async function deleteLabel({ db, params }) {
  const l = await db.first('SELECT * FROM labels WHERE id = ?', params.id);
  if (!l) fail(404, 'label not found');
  if (l.system) fail(400, 'system labels cannot be deleted');
  await db.batch([
    ['DELETE FROM message_labels WHERE label_id = ?', l.id],
    ['DELETE FROM labels WHERE id = ?', l.id],
  ]);
  return { ok: true };
}
