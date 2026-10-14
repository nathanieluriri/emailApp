import { fail, parseJson } from './http.js';
import { notifyReaction } from './push.js';
import { touch } from './live.js';

// Gmail's reaction format: https://developers.google.com/workspace/gmail/reactions/format
const REACTION_TYPE = 'text/vnd.google.email-reaction+json';
const MAX_PEOPLE = 20;
const enc = new TextEncoder();

export function isEmoji(s) {
  if (typeof s !== 'string' || !s.trim()) return false;
  const graphemes = [...new Intl.Segmenter('en', { granularity: 'grapheme' }).segment(s.trim())];
  return graphemes.length === 1 && /\p{Extended_Pictographic}|\p{Regional_Indicator}/u.test(s);
}

function emojiOf(attachments) {
  const part = attachments?.find((a) => a.mimeType?.toLowerCase() === REACTION_TYPE);
  if (!part) return null;
  const body = typeof part.content === 'string' ? part.content : new TextDecoder().decode(part.content);
  const json = parseJson(body, null);
  return json?.version === 1 && isEmoji(json.emoji) ? json.emoji.trim() : null;
}

// Records a Gmail-style reaction email as a reaction on the message it answers. Returns false when it is not one.
export async function receiveReaction(env, db, ctx, mail, delivered) {
  const emoji = emojiOf(mail.attachments);
  const target = emoji && mail.inReplyTo && (await db.first('SELECT * FROM messages WHERE message_id_header = ?', mail.inReplyTo.trim()));
  if (!target) return false;
  const address = (mail.from?.address || '').toLowerCase();
  const name = mail.from?.name || '';
  await db.run(
    'INSERT OR IGNORE INTO reactions (message_id, address, name, emoji, created_at) VALUES (?, ?, ?, ?, ?)',
    target.id, address, name, emoji, Date.now(),
  );
  touch(env, ctx, [delivered]);
  ctx.waitUntil(notifyReaction(env, db, target, delivered, name || address, emoji).catch((e) => console.error('push failed', e)));
  return true;
}

const b64 = (s) => {
  let bin = '';
  for (const byte of enc.encode(s)) bin += String.fromCharCode(byte);
  return btoa(bin);
};
const word = (s) => (/^[\x20-\x7e]*$/.test(s) ? s : `=?UTF-8?B?${b64(s)}?=`);
const mailbox = ({ name, address }) =>
  name ? `${/^[\x20-\x7e]*$/.test(name) ? `"${name.replace(/["\\]/g, '\\$&')}"` : word(name)} <${address}>` : address;
const escape = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

export function reactionMime({ from, to, subject, messageId, inReplyTo, references, emoji }) {
  const boundary = `quirepost-${crypto.randomUUID()}`;
  const part = (type, body) =>
    [`--${boundary}`, `Content-Type: ${type}; charset="UTF-8"`, 'Content-Transfer-Encoding: base64', '', b64(body).replace(/.{76}/g, '$&\r\n')].join('\r\n');
  const who = from.name || from.address;
  return [
    `From: ${mailbox(from)}`,
    `To: ${to.map(mailbox).join(', ')}`,
    `Subject: ${word(subject)}`,
    `Message-ID: ${messageId}`,
    `In-Reply-To: ${inReplyTo}`,
    `References: ${references}`,
    `Date: ${new Date().toUTCString()}`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    '',
    part('text/plain', `${emoji}\r\n\r\n${who} reacted via Quirepost`),
    part(REACTION_TYPE, JSON.stringify({ emoji, version: 1 })),
    part('text/html', `<div><p style="font-size:50px;margin:0">${emoji}</p><p style="margin:10px 0 0">${escape(who)} reacted via Quirepost</p></div>`),
    `--${boundary}--`,
    '',
  ].join('\r\n');
}

export async function react({ env, db, req, params, ctx, mailbox: me }) {
  const { emoji, fromName = '' } = await req.json().catch(() => ({}));
  if (!me) fail(400, 'X-Mailbox is required');
  if (!isEmoji(emoji)) fail(400, '"emoji" must be one emoji');
  const m = await db.first(
    'SELECT * FROM messages WHERE id = ? AND id IN (SELECT message_id FROM message_owners WHERE address = ?)',
    params.id, me,
  );
  if (!m) fail(404, 'message not found');
  if (!m.message_id_header) fail(400, 'this message cannot take reactions');
  const listed = [...parseJson(m.to_json, []), ...parseJson(m.cc_json, [])];
  const mine = m.from_addr.toLowerCase() === me;
  if (!mine && !listed.some((r) => r.address?.toLowerCase() === me)) fail(400, 'you can only react to mail sent to you directly');
  const people = [...(mine ? [] : [{ address: m.from_addr, name: m.from_name || '' }]), ...listed]
    .filter((p, i, all) => p.address && p.address.toLowerCase() !== me && all.findIndex((q) => q.address?.toLowerCase() === p.address.toLowerCase()) === i);
  if (!people.length) fail(400, 'nobody else is on this message');
  if (people.length > MAX_PEOPLE) fail(400, `reactions work on messages with up to ${MAX_PEOPLE} people`);

  const raw = reactionMime({
    from: { address: me, name: fromName },
    to: people,
    subject: /^re:/i.test(m.subject || '') ? m.subject : `Re: ${m.subject || ''}`,
    messageId: `<${crypto.randomUUID()}@${env.ALLOWED_DOMAIN}>`,
    inReplyTo: m.message_id_header,
    references: [m.references_hdr, m.message_id_header].filter(Boolean).join(' '),
    emoji: emoji.trim(),
  });
  const { EmailMessage } = await import('cloudflare:email');
  try {
    for (const p of people) await env.EMAIL.send(new EmailMessage(me, p.address, raw));
  } catch (e) {
    fail(502, `reaction not sent: ${e.message}`);
  }
  await db.run(
    'INSERT OR IGNORE INTO reactions (message_id, address, name, emoji, created_at) VALUES (?, ?, ?, ?, ?)',
    m.id, me, fromName, emoji.trim(), Date.now(),
  );
  touch(env, ctx, [me]);
  const all = await db.all('SELECT * FROM reactions WHERE message_id = ? ORDER BY created_at', m.id);
  return { reactions: all.map((r) => ({ emoji: r.emoji, address: r.address, name: r.name || '', mine: r.address === me })) };
}
