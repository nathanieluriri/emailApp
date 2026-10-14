import { fail } from './http.js';

const MAX_BYTES = 5 * 1024 * 1024;

export async function upload({ req, env, url }) {
  let body, type;
  if ((req.headers.get('content-type') || '').startsWith('multipart/form-data')) {
    const file = (await req.formData()).get('file');
    if (!file || typeof file === 'string') fail(400, 'multipart field "file" is required');
    body = await file.arrayBuffer();
    type = file.type;
  } else {
    body = await req.arrayBuffer();
    type = req.headers.get('content-type');
  }
  if (!type?.startsWith('image/')) fail(415, 'only images are allowed');
  if (body.byteLength > MAX_BYTES) fail(413, 'image is larger than 5 MB');
  const ext = type.split('/')[1].replace('svg+xml', 'svg').replace('jpeg', 'jpg');
  const key = `${crypto.randomUUID()}.${ext}`;
  await env.FILES.put(`img/${key}`, body, { httpMetadata: { contentType: type } });
  return { key, url: `${url.origin}/img/${key}` };
}

export async function image({ env, params }) {
  const obj = await env.FILES.get(`img/${params.key}`);
  if (!obj) fail(404, 'image not found');
  return new Response(obj.body, {
    headers: {
      'content-type': obj.httpMetadata?.contentType || 'application/octet-stream',
      'cache-control': 'public, max-age=31536000, immutable',
      'access-control-allow-origin': '*',
    },
  });
}
