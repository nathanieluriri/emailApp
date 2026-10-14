export function createDb(env) {
  if (env.DB_DRIVER === 'libsql') return libsql(env.LIBSQL_URL, env.LIBSQL_TOKEN);
  return d1(env.DB);
}

function d1(db) {
  const prep = ([sql, ...params]) => db.prepare(sql).bind(...params);
  return {
    all: async (sql, ...p) => (await prep([sql, ...p]).all()).results,
    first: (sql, ...p) => prep([sql, ...p]).first(),
    run: (sql, ...p) => prep([sql, ...p]).run(),
    batch: (stmts) => db.batch(stmts.map(prep)),
  };
}

function libsql(url, token) {
  const arg = (v) =>
    v == null ? { type: 'null' }
      : typeof v === 'boolean' ? { type: 'integer', value: v ? '1' : '0' }
      : Number.isInteger(v) ? { type: 'integer', value: String(v) }
      : typeof v === 'number' ? { type: 'float', value: v }
      : { type: 'text', value: String(v) };
  const value = (v) => (v.type === 'null' ? null : v.type === 'integer' ? Number(v.value) : v.value);

  const exec = async (stmts) => {
    const res = await fetch(`${url.replace(/^libsql:/, 'https:')}/v2/pipeline`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        requests: [
          ...stmts.map(([sql, ...p]) => ({ type: 'execute', stmt: { sql, args: p.map(arg) } })),
          { type: 'close' },
        ],
      }),
    });
    if (!res.ok) throw new Error(`libsql ${res.status}`);
    const { results } = await res.json();
    return results.slice(0, -1).map((r) => {
      if (r.type === 'error') throw new Error(r.error.message);
      const { cols, rows } = r.response.result;
      return rows.map((row) => Object.fromEntries(row.map((v, i) => [cols[i].name, value(v)])));
    });
  };

  return {
    all: async (sql, ...p) => (await exec([[sql, ...p]]))[0],
    first: async (sql, ...p) => (await exec([[sql, ...p]]))[0][0] ?? null,
    run: (sql, ...p) => exec([[sql, ...p]]),
    batch: exec,
  };
}
