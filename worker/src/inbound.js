import PostalMime from 'postal-mime';
import { createDb } from './db.js';
import { storeMessage } from './store.js';
import { notifyNewMail } from './push.js';

const addresses = (list) => (list || []).filter((a) => a.address).map((a) => ({ address: a.address, name: a.name || '' }));

export async function receive(message, env, ctx) {
  const db = createDb(env);
  const mail = await PostalMime.parse(await new Response(message.raw).arrayBuffer());
  const date = Date.parse(mail.date);

  const stored = await storeMessage(db, env, {
    direction: 'in',
    messageIdHeader: mail.messageId,
    inReplyTo: mail.inReplyTo,
    references: mail.references,
    from: mail.from?.address || message.from,
    fromName: mail.from?.name,
    to: addresses(mail.to),
    cc: addresses(mail.cc),
    subject: mail.subject,
    html: mail.html,
    text: mail.text,
    date: Number.isNaN(date) ? Date.now() : date,
    labels: ['inbox'],
    attachments: mail.attachments.map((a) => ({
      filename: a.filename,
      mimeType: a.mimeType,
      contentId: a.contentId,
      content: a.content,
    })),
  });

  if (stored) {
    ctx.waitUntil(notifyNewMail(env, db, stored).catch((e) => console.error('push failed', e)));
  }
}
