import { DurableObject } from 'cloudflare:workers';

// One per mailbox. Phones with the app open hold a WebSocket to it; every change to the mailbox bumps its version and
// sends the new one down every socket, so the app refreshes the moment mail moves. Sockets are accepted with the
// hibernation API: an idle connection costs no duration, and pings never wake the object.
export class MailboxHub extends DurableObject {
  async fetch(req) {
    if (req.headers.get('upgrade')?.toLowerCase() !== 'websocket') return new Response('expected a websocket', { status: 426 });
    const { 0: client, 1: server } = new WebSocketPair();
    this.ctx.acceptWebSocket(server);
    server.send(JSON.stringify({ version: (await this.ctx.storage.get('version')) ?? 0 }));
    return new Response(null, { status: 101, webSocket: client });
  }

  async changed() {
    const version = ((await this.ctx.storage.get('version')) ?? 0) + 1;
    await this.ctx.storage.put('version', version);
    const message = JSON.stringify({ version });
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(message);
      } catch {}
    }
  }

  webSocketMessage() {}

  webSocketClose(ws, code, reason) {
    try {
      ws.close(code, reason);
    } catch {}
  }
}
