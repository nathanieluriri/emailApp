import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../core/api/api_client.dart';
import '../core/config.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/easings.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import '../mail/models.dart';
import '../notifications/push_service.dart';
import '../notifications/reminders.dart';
import 'account.dart';
import 'accounts_controller.dart';
import 'health_check.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.adding = false});
  final bool adding;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _pages = PageController(initialPage: widget.adding ? 1 : 0);
  final _url = TextEditingController(text: AppConfig.defaultWorkerUrl);
  final _key = TextEditingController();
  final _nickname = TextEditingController(text: 'Bridgewood');
  bool _custom = false;
  bool _busy = false;
  HealthReport? _report;
  Senders? _senders;
  String? _keyError;

  String get _workerUrl => (_custom ? _url.text.trim() : AppConfig.defaultWorkerUrl).replaceAll(RegExp(r'/+$'), '');

  @override
  void dispose() {
    _pages.dispose();
    _url.dispose();
    _key.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    Feel.turn.ring();
    _pages.nextPage(duration: kPageTurn, curve: easeInOutCubic);
  }

  Future<void> _checkWorker() async {
    final uri = Uri.tryParse(_workerUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return setState(() => _report = HealthReport(const [], error: 'Enter a full URL, like https://mail.example.workers.dev'));
    }
    setState(() {
      _busy = true;
      _report = null;
    });
    final report = await checkWorker(_workerUrl);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _report = report;
    });
    report.ok ? Feel.commit.ring() : HapticFeedback.heavyImpact();
  }

  Future<void> _verifyKey() async {
    if (_key.text.trim().isEmpty) return setState(() => _keyError = 'Paste the API key from the worker');
    setState(() {
      _busy = true;
      _keyError = null;
    });
    try {
      final senders = await ApiClient(_workerUrl, _key.text.trim()).senders();
      final account = Account(
        id: const Uuid().v4(),
        nickname: _nickname.text.trim().isEmpty ? Uri.parse(_workerUrl).host : _nickname.text.trim(),
        workerUrl: _workerUrl,
        apiKey: _key.text.trim(),
      );
      await ref.read(accountsProvider.notifier).add(account);
      Feel.commit.ring();
      setState(() {
        _busy = false;
        _senders = senders;
      });
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _keyError = ApiException.from(e).status == 401 ? 'The worker did not accept this key' : '${ApiException.from(e)}';
      });
    }
  }

  Future<void> _enableNotifications() async {
    setState(() => _busy = true);
    await PushService.requestPermission();
    final state = ref.read(accountsProvider).value;
    if (state != null) await PushService.syncTags(state.accounts, active: state.active);
    await Reminders.schedule(ref.read(settingsProvider).reminderMinutes);
    if (mounted) _finish();
  }

  void _finish() {
    Feel.commit.ring();
    context.go('/inbox');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Step(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/brand/quire-mark.png', width: 96, height: 96),
                const SizedBox(height: 12),
                Text('Bridgewood Mail', style: AppText.markName.copyWith(color: AppColors.ink)),
                const SizedBox(height: 14),
                Text(
                  'Your domain\'s mail, on your own worker',
                  textAlign: TextAlign.center,
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Read, write and get notified, all through a Cloudflare worker you control.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyTight.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 24),
                PillButton(label: 'Get started', onTap: _next),
              ],
            ),
          ),
          _Step(
            title: 'Connect your worker',
            body: 'The app talks to one worker per account. The default is ready to go.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _custom,
                  title: Text('Use custom worker', style: AppText.rowTitle.copyWith(color: AppColors.ink)),
                  subtitle: Text(
                    _custom ? 'Enter its URL below' : AppConfig.defaultWorkerUrl,
                    style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                  ),
                  onChanged: (v) {
                    Feel.tap.ring();
                    setState(() {
                      _custom = v;
                      _report = null;
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: _custom
                      ? TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(labelText: 'Worker URL'),
                          onChanged: (_) => setState(() => _report = null),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _report == null
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_report!.ok && _report!.error == null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'This worker is missing ${_report!.missing.length} thing${_report!.missing.length == 1 ? '' : 's'}. Fix them on the worker, then check again.',
                                    style: AppText.bodyTight.copyWith(color: AppColors.damage),
                                  ),
                                ),
                              HealthChecklist(report: _report!),
                            ],
                          ),
                        ),
                ),
                Row(
                  children: [
                    PillButton(
                      label: _report == null ? 'Check worker' : 'Check again',
                      filled: _report?.ok != true,
                      busy: _busy,
                      onTap: _checkWorker,
                    ),
                    const Spacer(),
                    if (_report?.ok == true) PillButton(label: 'Continue', icon: LucideIcons.arrowRight, onTap: _next),
                  ],
                ),
              ],
            ),
          ),
          _Step(
            title: 'Add your API key',
            body: 'It is one of the keys in the worker\'s API_KEYS secret. It stays in this phone\'s secure storage.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nickname,
                  decoration: const InputDecoration(labelText: 'Nickname for this account'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    errorText: _keyError,
                    suffixIcon: IconPress(
                      icon: LucideIcons.clipboardPaste,
                      label: 'Paste',
                      size: 18,
                      onTap: () async => _key.text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_senders != null)
                  Expanded(
                    child: ListView(
                      children: [
                        Text('Verified. You can send as:', style: AppText.label.copyWith(color: AppColors.inkSoft)),
                        const SizedBox(height: 8),
                        for (final (i, s) in _senders!.senders.indexed)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 260 + 60 * i),
                            curve: Curves.easeOutBack,
                            builder: (context, t, child) =>
                                Transform.scale(scale: t.clamp(0, 2), alignment: Alignment.centerLeft, child: child),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.atSign, size: 16, color: AppColors.accentBright),
                                  const SizedBox(width: 8),
                                  Text(s.address, style: AppText.bodyTight.copyWith(color: AppColors.ink)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                Row(
                  children: [
                    if (_senders == null) PillButton(label: 'Verify key', busy: _busy, onTap: _verifyKey),
                    const Spacer(),
                    if (_senders != null)
                      PillButton(
                        label: 'Continue',
                        icon: LucideIcons.arrowRight,
                        onTap: widget.adding && PushService.permitted ? _enableNotifications : _next,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _Step(
            title: 'Notifications',
            body: 'Get a push the moment mail arrives, plus a gentle reminder when unread mail is waiting.',
            child: Column(
              children: [
                const Spacer(),
                Icon(LucideIcons.bellRing, size: 72, color: AppColors.accentBright),
                const Spacer(),
                Row(
                  children: [
                    PillButton(label: 'Not now', filled: false, onTap: _finish),
                    const Spacer(),
                    PillButton(label: 'Allow notifications', icon: LucideIcons.bell, busy: _busy, onTap: _enableNotifications),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

const kPageTurn = Duration(milliseconds: 420);

class _Step extends StatelessWidget {
  const _Step({required this.child, this.title, this.body});
  final Widget child;
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: AppText.display.copyWith(color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(body ?? '', style: AppText.bodyTight.copyWith(color: AppColors.inkSoft)),
          const SizedBox(height: 20),
        ],
        Expanded(child: child),
      ],
    ),
  );
}
