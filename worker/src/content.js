import { fail, parseJson } from './http.js';

const TEMPLATE = {
  table: 'templates',
  fields: { name: 'name', subject: 'subject', html: 'html', blocks_json: 'blocks_json', variables: 'variables_json' },
  json: ['variables'],
};

const SIGNATURE = {
  table: 'signatures',
  fields: { name: 'name', html: 'html', senderAddress: 'sender_address', isDefault: 'is_default' },
  bool: ['isDefault'],
  async afterWrite(db, row) {
    if (row.is_default) {
      await db.run('UPDATE signatures SET is_default = 0 WHERE id != ? AND sender_address IS ?', row.id, row.sender_address ?? null);
    }
  },
};

function toApi(spec, row) {
  const out = { id: row.id, updatedAt: row.updated_at };
  for (const [key, col] of Object.entries(spec.fields)) {
    out[key] = spec.json?.includes(key) ? parseJson(row[col], []) : spec.bool?.includes(key) ? !!row[col] : row[col] ?? null;
  }
  return out;
}

function toRow(spec, body, existing = {}) {
  const row = { ...existing };
  for (const [key, col] of Object.entries(spec.fields)) {
    if (!(key in body)) continue;
    const v = body[key];
    row[col] = spec.json?.includes(key) ? JSON.stringify(v ?? []) : spec.bool?.includes(key) ? (v ? 1 : 0) : v ?? null;
  }
  return row;
}

function crud(spec) {
  const cols = Object.values(spec.fields);
  const get = async (db, id) => (await db.first(`SELECT * FROM ${spec.table} WHERE id = ?`, id)) || fail(404, 'not found');
  const save = async (db, row) => {
    await db.run(
      `INSERT OR REPLACE INTO ${spec.table} (id, ${cols.join(', ')}, updated_at) VALUES (?, ${cols.map(() => '?').join(', ')}, ?)`,
      row.id, ...cols.map((c) => row[c] ?? null), row.updated_at,
    );
    await spec.afterWrite?.(db, row);
    return toApi(spec, row);
  };
  return {
    list: async ({ db }) => (await db.all(`SELECT * FROM ${spec.table} ORDER BY updated_at DESC`)).map((r) => toApi(spec, r)),
    get: async ({ db, params }) => toApi(spec, await get(db, params.id)),
    create: async ({ db, req }) => {
      const body = await req.json();
      if (!body.name?.trim()) fail(400, 'name is required');
      return save(db, { ...toRow(spec, body), id: body.id || crypto.randomUUID(), updated_at: Date.now() });
    },
    update: async ({ db, req, params }) => {
      const existing = await get(db, params.id);
      return save(db, { ...toRow(spec, await req.json(), existing), updated_at: Date.now() });
    },
    remove: async ({ db, params }) => {
      await get(db, params.id);
      await db.run(`DELETE FROM ${spec.table} WHERE id = ?`, params.id);
      return { ok: true };
    },
  };
}

export const templates = crud(TEMPLATE);
export const signatures = crud(SIGNATURE);
