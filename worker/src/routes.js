import * as mail from './mail.js';
import * as labels from './labels.js';
import { send, reply, senders } from './send.js';
import { templates, signatures } from './content.js';
import { upload, image } from './uploads.js';
import { health } from './health.js';
import { getCatchAll, setCatchAll } from './routing.js';

const route = (method, path, handler, isPublic = false) => ({
  method,
  signature: `${method} ${path}`,
  re: new RegExp(`^${path.replace(/:(\w+)/g, '(?<$1>[^/]+)')}$`),
  handler,
  public: isPublic,
});

const crudRoutes = (base, c) => [
  route('GET', base, c.list),
  route('POST', base, c.create),
  route('GET', `${base}/:id`, c.get),
  route('PATCH', `${base}/:id`, c.update),
  route('DELETE', `${base}/:id`, c.remove),
];

export const routes = [
  route('GET', '/health', health, true),
  route('GET', '/img/:key', image, true),
  route('GET', '/messages', mail.listMessages),
  route('GET', '/messages/:id', mail.getMessage),
  route('PATCH', '/messages/:id', mail.patchMessage),
  route('POST', '/messages/:id/reply', reply),
  route('GET', '/threads/:id', mail.getThread),
  route('GET', '/attachments/:id', mail.getAttachment),
  route('GET', '/labels', labels.listLabels),
  route('POST', '/labels', labels.createLabel),
  route('PATCH', '/labels/:id', labels.updateLabel),
  route('DELETE', '/labels/:id', labels.deleteLabel),
  route('POST', '/send', send),
  route('GET', '/senders', senders),
  ...crudRoutes('/templates', templates),
  ...crudRoutes('/signatures', signatures),
  route('POST', '/uploads', upload),
  route('GET', '/routing/catch-all', getCatchAll),
  route('PUT', '/routing/catch-all', setCatchAll),
];
