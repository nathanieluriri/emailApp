import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../core/api/api_client.dart';
import '../core/brand.dart';
import '../core/config.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/easings.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import '../notifications/push_service.dart';
import '../notifications/reminders.dart';
import 'account.dart';
import 'accounts_controller.dart';
import 'domain_field.dart';
import 'health_check.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

enum _Step { welcome, email, key, profile, notifications }

/// Add an account the way Outlook does: your address first, then access, then how you appear to others.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.adding = false});
  final bool adding;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late _Step _step = widget.adding ? _Step.email : _Step.welcome;
  final _email = TextEditingController();
  final _server = TextEditingController(text: AppConfig.defaultWorkerUrl);
  final _key = TextEditingController();
  final _name = TextEditingController();
  final _emailField = GlobalKey<DomainFieldState>();
  Timer? _serverPause;
  late String _domainUrl = _workerUrl;
  bool _customServer = false;
  bool _busy = false;
  bool _showChecks = false;
  String? _error;
  HealthReport? _report;

  String get _workerUrl => (_customServer ? _server.text.trim() : AppConfig.defaultWorkerUrl).replaceAll(RegExp(r'/+$'), '');
  String get _address => _email.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    for (final c in [_email, _key, _name]) {
      c.addListener(() => setState(() => _error = null));
    }
    _server.addListener(() {
      _serverPause?.cancel();
      _serverPause = Timer(const Duration(milliseconds: 600), () => setState(() => _domainUrl = _workerUrl));
    });
  }

  @override
  void dispose() {
    _serverPause?.cancel();
    for (final c in [_email, _server, _key, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The chosen server's domain, which the email field offers to finish the address with.
  String? get _domain => ref.read(serverDomainProvider(_domainUrl)).value;

  void _go(_Step step) {
    FocusScope.of(context).unfocus();
    Feel.turn.ring();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _back() {
    if (_step.index <= (widget.adding ? _Step.email.index : _Step.welcome.index)) {
      if (context.canPop()) context.pop();
      return;
    }
    _go(_Step.values[_step.index - 1]);
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _submitEmail() async {
    if (!_emailPattern.hasMatch(_address)) return _fail('Enter a full email address, like you@${_domain ?? 'company.com'}');
    if (_domain != null && !_address.endsWith('@$_domain')) return _fail('This server sends from @$_domain. Use an address on it.');
    final uri = Uri.tryParse(_workerUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return _fail('Enter the full server address, starting with https://');
    setState(() => _busy = true);
    final report = await checkWorker(_workerUrl);
    if (!mounted) return;
    _report = report;
    if (!report.ok) {
      _showChecks = true;
      return _fail(
        report.error ?? 'This server is missing ${report.missing.length} thing${report.missing.length == 1 ? '' : 's'}. See below.',
      );
    }
    setState(() => _busy = false);
    _go(_Step.key);
  }

  Future<void> _submitKey() async {
    if (_key.text.trim().isEmpty) return _fail('Paste your access key');
    setState(() => _busy = true);
    try {
      final senders = await ApiClient(_workerUrl, _key.text.trim(), mailbox: _address).senders();
      if (!_address.endsWith('@${senders.domain.toLowerCase()}')) {
        return _fail('This server only sends from @${senders.domain}. Go back and use an address on that domain.');
      }
      if (_name.text.isEmpty) {
        final name = senders.name.isNotEmpty ? senders.name : _suggestName(_address);
        // With a caret already placed, the autofocused field does not raise Android's selection handle.
        _name.value = TextEditingValue(text: name, selection: TextSelection.collapsed(offset: name.length));
      }
      Feel.commit.ring();
      setState(() => _busy = false);
      _go(_Step.profile);
    } catch (e) {
      final error = ApiException.from(e);
      _fail(error.status == 401 ? 'That key was not accepted. Check it and try again.' : error.message);
    }
  }

  String _suggestName(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    return local.split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Future<void> _submitProfile() async {
    if (_name.text.trim().isEmpty) return _fail('Add the name people will see');
    await ref
        .read(accountsProvider.notifier)
        .add(
          Account(id: const Uuid().v4(), email: _address, displayName: _name.text.trim(), workerUrl: _workerUrl, apiKey: _key.text.trim()),
        );
    Feel.commit.ring();
    if (widget.adding && PushService.status.permission) return _finish();
    _go(_Step.notifications);
  }

  Future<void> _enableNotifications() async {
    setState(() => _busy = true);
    await PushService.enable();
    final state = ref.read(accountsProvider).value;
    if (state != null) await PushService.register(state.accounts);
    await Reminders.schedule(ref.read(settingsProvider).reminderMinutes);
    if (mounted) _finish();
  }

  void _finish() {
    Feel.commit.ring();
    context.go('/inbox');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(serverDomainProvider(_domainUrl));
    final welcome = _step == _Step.welcome;
    return Scaffold(
      appBar: welcome
          ? null
          : AppBar(
              leading: _step == _Step.notifications ? null : IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: _back),
              automaticallyImplyLeading: false,
              title: Text(_step == _Step.notifications ? 'Stay in the loop' : 'Add account'),
            ),
      body: SafeArea(
        top: welcome,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: easeOutCubic,
          switchOutCurve: easeInCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_step), child: _page()),
        ),
      ),
    );
  }

  Widget _page() => switch (_step) {
    _Step.welcome => _Welcome(onStart: () => _go(_Step.email)),
    _Step.email => _Form(
      art: const _MarkTile(icon: LucideIcons.atSign),
      title: 'What\'s your email?',
      body: _domain == null
          ? 'The address you will send from, on your company domain.'
          : 'The address you will send from. Type your name and your server adds the rest.',
      error: _error,
      action: 'Continue',
      busy: _busy,
      onAction: _email.text.trim().isEmpty ? null : () => _emailField.currentState?.complete(submit: true),
      children: [
        DomainField(
          key: _emailField,
          controller: _email,
          domain: _domain,
          onSubmitted: _submitEmail,
          decoration: InputDecoration(labelText: 'Enter your email', hintText: 'you@${_domain ?? 'company.com'}'),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), minimumSize: const Size(0, 48)),
            onPressed: () {
              Feel.tap.ring();
              setState(() {
                _customServer = !_customServer;
                _domainUrl = _workerUrl;
              });
            },
            child: Text(
              _customServer ? 'Use the default server' : 'Use a custom server',
              style: AppText.label.copyWith(color: AppColors.accentBright),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: easeOutCubic,
          child: _customServer
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'Server address', helperText: 'Your Cloudflare worker URL'),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (_report != null && !_report!.ok) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _showChecks = !_showChecks),
            child: Text(
              _showChecks ? 'Hide details' : 'Show what is missing',
              style: AppText.label.copyWith(color: AppColors.accentBright),
            ),
          ),
          if (_showChecks) HealthChecklist(report: _report!),
        ],
      ],
    ),
    _Step.key => _Form(
      art: const _MarkTile(icon: LucideIcons.keyRound),
      title: 'Enter your access key',
      body:
          'Connecting $_address to ${Uri.parse(_workerUrl).host}. The key is one of the worker\'s API_KEYS and stays in this phone\'s secure storage.',
      error: _error,
      action: 'Sign in',
      busy: _busy,
      onAction: _key.text.trim().isEmpty ? null : _submitKey,
      children: [
        TextField(
          controller: _key,
          autofocus: true,
          obscureText: true,
          onSubmitted: (_) => _submitKey(),
          decoration: InputDecoration(
            labelText: 'Access key',
            suffixIcon: IconPress(
              icon: LucideIcons.clipboardPaste,
              label: 'Paste',
              size: 18,
              onTap: () async => _key.text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '',
            ),
          ),
        ),
      ],
    ),
    _Step.profile => _Form(
      art: ListenableBuilder(
        listenable: _name,
        builder: (_, _) => Avatar(name: _name.text.isEmpty ? _address : _name.text, size: 88),
      ),
      title: 'How should people see you?',
      body: 'Your display name goes out with every email you send from this app.',
      error: _error,
      action: 'Done',
      onAction: _submitProfile,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submitProfile(),
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: _name,
          builder: (_, _) => SenderPreview(name: _name.text.trim(), email: _address),
        ),
      ],
    ),
    _Step.notifications => _Form(
      art: const _MarkTile(icon: LucideIcons.bellRing),
      title: 'Know when mail arrives',
      body: 'Get a notification the moment new mail lands, and a gentle nudge when unread mail is waiting.',
      action: 'Turn on notifications',
      busy: _busy,
      onAction: _enableNotifications,
      secondary: 'Not now',
      onSecondary: _finish,
      children: const [],
    ),
  };
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      children: [
        const Spacer(flex: 3),
        const BrandMark(size: 104),
        const SizedBox(height: 16),
        const Wordmark(),
        const SizedBox(height: 10),
        Text(
          'Your company mail, gathered and sent from your own server.',
          textAlign: TextAlign.center,
          style: AppText.bodyTight.copyWith(color: AppColors.inkSoft, fontSize: 15),
        ),
        const Spacer(flex: 4),
        PillButton(label: 'Add account', expand: true, onTap: onStart),
      ],
    ),
  );
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(22)),
    child: Icon(icon, size: 32, color: AppColors.accentBright),
  );
}

/// One step: art, a headline, one line of why, the fields, and a full-width action at the bottom.
class _Form extends StatelessWidget {
  const _Form({
    required this.art,
    required this.title,
    required this.body,
    required this.children,
    required this.action,
    required this.onAction,
    this.error,
    this.busy = false,
    this.secondary,
    this.onSecondary,
  });

  final Widget art;
  final String title;
  final String body;
  final List<Widget> children;
  final String action;
  final VoidCallback? onAction;
  final String? error;
  final bool busy;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          children: [
            Align(alignment: Alignment.centerLeft, child: art),
            const SizedBox(height: 24),
            Text(title, style: AppText.display.copyWith(color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(body, style: AppText.bodyTight.copyWith(color: AppColors.inkSoft, fontSize: 15, height: 1.4)),
            const SizedBox(height: 28),
            ...children,
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.circleAlert, size: 18, color: AppColors.damage),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error!, style: AppText.bodyTight.copyWith(color: AppColors.damage)),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          children: [
            PillButton(label: action, expand: true, busy: busy, onTap: onAction),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              PillButton(label: secondary!, expand: true, filled: false, onTap: onSecondary),
            ],
          ],
        ),
      ),
    ],
  );
}

/// What the recipient's inbox shows for a message from this account.
class SenderPreview extends StatelessWidget {
  const SenderPreview({super.key, required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IN THEIR INBOX', style: AppText.chipLabel.copyWith(color: AppColors.inkFaint)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(name: name.isEmpty ? email : name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? email : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '<$email>',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quarterly update',
                    style: AppText.bodyTight.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
