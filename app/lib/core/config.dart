abstract final class AppConfig {
  static const workerSubdomain = 'uririnathaniel';
  static const defaultWorkerUrl = 'https://bridgewood-mail.$workerSubdomain.workers.dev';
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: 'a96bfc98-6997-42fc-8625-1ef053460c62');
  static const serviceName = 'bridgewood-mail';
  static const requiredRoutes = [
    'GET /health',
    'GET /messages',
    'GET /messages/:id',
    'PATCH /messages/:id',
    'POST /messages/:id/reply',
    'GET /threads/:id',
    'GET /attachments/:id',
    'GET /labels',
    'POST /labels',
    'PATCH /labels/:id',
    'DELETE /labels/:id',
    'POST /send',
    'GET /senders',
    'GET /templates',
    'POST /templates',
    'PATCH /templates/:id',
    'DELETE /templates/:id',
    'GET /signatures',
    'POST /signatures',
    'PATCH /signatures/:id',
    'DELETE /signatures/:id',
    'POST /uploads',
    'GET /img/:key',
  ];
  static const requiredChecks = ['db', 'r2', 'email', 'onesignal'];
}
