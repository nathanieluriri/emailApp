import { fail, parseJson } from './http.js';
import { storeMessage } from './store.js';
import { htmlToText } from './text.js';
import { routeHere } from './routing.js';

const DEFAULT_SENDERS = ['admin', 'info', 'support', 'noreply'];

const recipients = (list) =>
  (Array.isArray(list) ? list : list ? [list] : [])
    .map((r) => (typeof r === 'string' ? { address: r.trim(), name: '' } : { address: r.address?.trim(), name: r.name || '' }))
    .filter((r) => r.address);

const toApi = (list) => list.map((r) => (r.name ? { email: r.address, name: r.name } : r.address));

const decode = (b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

export function senders({ env, url, ctx, db }) {
  ctx.waitUntil(db.run("INSERT OR REPLACE INTO meta (key, value) VALUES ('host', ?)", url.host).catch(() => {}));
  const locals = env.SENDERS ? env.SENDERS.split(',').map((s) => s.trim()).filter(Boolean) : DEFAULT_SENDERS;
  return {
    domain: env.ALLOWED_DOMAIN,
    senders: locals.map((l) => ({ address: `${l}@${env.ALLOWED_DOMAIN}`, name: l[0].toUpperCase() + l.slice(1) })),
  };
}

async function deliver(env, db, b, mailbox, ctx) {
  const domain = env.ALLOWED_DOMAIN.toLowerCase();
  const from = b.from?.trim().toLowerCase();
  if (!from?.endsWith(`@${domain}`)) fail(400, `"from" must end with @${domain}`);
  const to = recipients(b.to);
  const cc = recipients(b.cc);
  const bcc = recipients(b.bcc);
  if (!to.length) fail(400, '"to" needs at least one recipient');
  if (to.length + cc.length + bcc.length > 50) fail(400, 'at most 50 recipients');
  if (!b.html && !b.text) fail(400, '"html" or "text" is required');

  const text = b.text || htmlToText(b.html);
  const headers = {};
  let parent = null;
  if (b.inReplyTo) {
    parent = await db.first('SELECT * FROM messages WHERE id = ? OR message_id_header = ?', b.inReplyTo, b.inReplyTo);
    if (parent?.message_id_header) {
      headers['In-Reply-To'] = parent.message_id_header;
      headers.References = [parent.references_hdr, parent.message_id_header].filter(Boolean).join(' ');
    }
  }
  const attachments = (b.attachments || []).map((a) => ({
    filename: a.filename || 'attachment',
    mimeType: a.type || a.mimeType || 'application/octet-stream',
    content: decode(a.content),
  }));

  let result;
  try {
    result = await env.EMAIL.send({
      from: b.fromName ? { email: from, name: b.fromName } : from,
      to: toApi(to),
      ...(cc.length && { cc: toApi(cc) }),
      ...(bcc.length && { bcc: toApi(bcc) }),
      subject: b.subject || '',
      ...(b.html && { html: b.html }),
      text,
      ...(Object.keys(headers).length && { headers }),
      ...(attachments.length && {
        attachments: attachments.map((a) => ({ filename: a.filename, type: a.mimeType, content: a.content, disposition: 'attachment' })),
      }),
    });
  } catch (e) {
    fail(502, `send failed${e.code ? ` (${e.code})` : ''}: ${e.message}`);
  }

  const messageIdHeader = result?.messageId
    ? (result.messageId.startsWith('<') ? result.messageId : `<${result.messageId}>`)
    : `<${crypto.randomUUID()}@${domain}>`;
  const stored = await storeMessage(db, env, {
    direction: 'out',
    messageIdHeader,
    inReplyTo: headers['In-Reply-To'],
    references: headers.References,
    from,
    fromName: b.fromName,
    to, cc, bcc,
    subject: b.subject,
    html: b.html,
    text,
    read: true,
    labels: ['sent'],
    owners: [...new Set([from, mailbox].filter(Boolean))].map((address) => ({ address, role: 'from' })),
    attachments,
  });
  ctx?.waitUntil(routeHere(env, db, [from, mailbox].filter(Boolean)).catch((e) => console.error('routing failed', e)));
  return { ...stored, messageIdHeader };
}

export async function send({ env, db, req, mailbox, ctx }) {
  return deliver(env, db, await req.json(), mailbox, ctx);
}

export async function reply({ env, db, req, params, mailbox, ctx }) {
  const orig = await db.first('SELECT * FROM messages WHERE id = ?', params.id);
  if (!orig) fail(404, 'message not found');
  return replyTo(env, db, orig, await req.json(), mailbox, ctx);
}

export function replyTo(env, db, orig, b, mailbox, ctx) {
  const incoming = orig.direction === 'in';
  const own = (r) => r.address.toLowerCase().endsWith(`@${env.ALLOWED_DOMAIN.toLowerCase()}`);
  const to = b.to?.length ? b.to : incoming ? [{ address: orig.from_addr, name: orig.from_name || '' }] : parseJson(orig.to_json, []);
  const cc = b.cc ?? (b.replyAll ? [...parseJson(orig.to_json, []), ...parseJson(orig.cc_json, [])].filter((r) => !own(r)) : []);
  const subject = /^re:/i.test(orig.subject || '') ? orig.subject : `Re: ${orig.subject || ''}`;
  return deliver(env, db, {
    ...b,
    from: b.from || (incoming ? null : orig.from_addr),
    to,
    cc,
    subject: b.subject || subject,
    inReplyTo: orig.id,
  }, mailbox, ctx);
}
