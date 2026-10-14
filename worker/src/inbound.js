import PostalMime from 'postal-mime';
import { createDb } from './db.js';
import { storeMessage } from './store.js';
import { notifyNewMail } from './push.js';
import { receiveReaction } from './reactions.js';
import { touch } from './live.js';

const addresses = (list) => (list || []).filter((a) => a.address).map((a) => ({ address: a.address, name: a.name || '' }));

export async function receive(message, env, ctx) {
  const db = createDb(env);
  const mail = await PostalMime.parse(await new Response(message.raw).arrayBuffer());
  const date = Date.parse(mail.date);
  const to = addresses(mail.to);
  const cc = addresses(mail.cc);
  const delivered = message.to.toLowerCase();
  if (await receiveReaction(env, db, ctx, mail, delivered)) return;
  const owners = [...new Set([delivered, ...[...to, ...cc].map((a) => a.address.toLowerCase())])];

  const stored = await storeMessage(db, env, {
    direction: 'in',
    messageIdHeader: mail.messageId,
    inReplyTo: mail.inReplyTo,
    references: mail.references,
    from: mail.from?.address || message.from,
    fromName: mail.from?.name,
    to,
    cc,
    subject: mail.subject,
    html: mail.html,
    text: mail.text,
    date: Number.isNaN(date) ? Date.now() : date,
    labels: ['inbox'],
    owners: owners.map((address) => ({ address, role: 'to' })),
    attachments: mail.attachments.map((a) => ({
      filename: a.filename,
      mimeType: a.mimeType,
      contentId: a.contentId,
      content: a.content,
    })),
  });

  let notify = owners;
  if (stored.duplicate) {
    // Mail between two of our addresses is stored when sent; its delivery only adds the recipient's copy.
    const known = await db.first("SELECT 1 AS hit FROM message_owners WHERE message_id = ? AND address = ? AND role = 'to'", stored.id, delivered);
    notify = known ? [] : [delivered];
    if (!known) {
      await db.batch([
        ["INSERT OR IGNORE INTO message_owners (message_id, address, role) VALUES (?, ?, 'to')", stored.id, delivered],
        ["INSERT OR IGNORE INTO message_labels (message_id, label_id) VALUES (?, 'inbox')", stored.id],
        ['UPDATE messages SET read = 0 WHERE id = ?', stored.id],
      ]);
    }
  }
  touch(env, ctx, notify);
  if (notify.length) ctx.waitUntil(notifyNewMail(env, db, stored.id, notify).catch((e) => console.error('push failed', e)));
}
