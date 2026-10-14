import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../accounts/accounts_controller.dart';
import '../builder/upload.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/quire/widgets/quire_spinner.dart';
import '../core/widgets.dart';
import '../mail/format.dart';
import '../mail/inbox_screen.dart' show composeFlight;
import '../mail/mail_providers.dart';
import '../mail/models.dart';
import '../signatures/signature.dart';
import '../signatures/signatures_repository.dart';
import '../templates/template.dart';
import '../templates/templates_repository.dart';
import '../templates/variables.dart';
import 'body_editor.dart';
import 'compose_args.dart';
import 'compose_draft.dart';
import 'html_tools.dart';
import 'preview.dart';
import 'recipient_field.dart';
import 'variables_form.dart';

class _Attachment {
  const _Attachment(this.name, this.type, this.bytes);
  final String name;
  final String type;
  final Uint8List bytes;
}

const _mimes = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'zip': 'application/zip',
};

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.args = const ComposeArgs()});
  final ComposeArgs args;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final String _draftId = widget.args.draftId ?? const Uuid().v4();
  late ComposeKind _kind = widget.args.kind;
  final _subject = TextEditingController();
  final _body = BodyEditorController();
  final _toKey = GlobalKey<RecipientFieldState>();
  List<String> _to = [], _cc = [], _bcc = [];
  bool _showCopies = false;
  String _from = '';
  String _fromName = '';
  Senders? _senders;
  List<Signature> _signatures = [];
  Signature? _signature;
  bool _signatureOff = false;
  String? _quote;
  String? _sourceId;
  final _attachments = <_Attachment>[];
  bool _sending = false;
  Timer? _autosave;

  @override
  void initState() {
    super.initState();
    _sourceId = widget.args.source?.id;
    _subject.addListener(_changed);
    _body.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    final account = ref.read(activeAccountProvider)!;
    final db = ref.read(databaseProvider);
    if (widget.args.draftId != null) {
      final drafts = await db.draftsFor(account.id);
      final raw = drafts.where((d) => d.id == widget.args.draftId).firstOrNull;
      if (raw != null) _restore(ComposeDraft.fromJson(jsonDecode(raw.json)));
    } else {
      _prefill();
    }
    try {
      final results = await Future.wait([api.senders(), ref.read(signaturesProvider.future)]);
      _senders = results[0] as Senders;
      _signatures = results[1] as List<Signature>;
    } catch (e) {
      if (mounted) showToast(context, 'Could not load senders: $e');
    }
    if (!mounted) return;
    final own = {for (final s in _senders?.senders ?? <Sender>[]) s.address};
    setState(() {
      _cc = _cc.where((a) => !own.contains(a.toLowerCase())).toList();
      _showCopies = _showCopies && (_cc.isNotEmpty || _bcc.isNotEmpty);
      if (_from.isEmpty) _from = _defaultFrom();
      if (_fromName.isEmpty) _fromName = _senders?.senders.where((s) => s.address == _from).firstOrNull?.name ?? '';
      _pickSignature();
    });
  }

  String _defaultFrom() {
    final senders = _senders?.senders ?? [];
    final source = widget.args.source;
    final mine = source == null
        ? null
        : [...source.to, ...source.cc].map((a) => a.address.toLowerCase()).where((a) => senders.any((s) => s.address == a)).firstOrNull;
    return mine ?? senders.where((s) => s.localPart == 'admin').firstOrNull?.address ?? senders.firstOrNull?.address ?? '';
  }

  void _pickSignature() {
    if (_signatureOff) return;
    if (_signature != null && _signature!.appliesTo(_from)) return;
    _signature = defaultSignatureFor(_signatures, _from);
  }

  void _prefill() {
    final s = widget.args.source;
    final t = widget.args.template;
    if (t != null) _applyTemplate(t);
    if (s == null) return;
    String quoteHeader(String line) =>
        '<div style="margin-top:20px;color:#49454F;font-size:13px;">$line</div><blockquote style="margin:8px 0 0;padding-left:12px;border-left:3px solid #CAC4D0;">${s.html ?? escapeHtml(s.text ?? '').replaceAll('\n', '<br>')}</blockquote>';
    final sender = escapeHtml('${s.from.display} <${s.from.address}>');
    switch (_kind) {
      case ComposeKind.reply || ComposeKind.replyAll:
        _to = s.outgoing ? s.to.map((a) => a.address).toList() : [s.from.address];
        if (_kind == ComposeKind.replyAll) {
          _cc = [...s.to, ...s.cc].map((a) => a.address).where((a) => !_to.contains(a)).toList();
          _showCopies = _cc.isNotEmpty;
        }
        _subject.text = RegExp(r'^re:', caseSensitive: false).hasMatch(s.subject) ? s.subject : 'Re: ${s.subject}';
        _quote = quoteHeader('On ${longDate(s.sentAt)}, $sender wrote:');
      case ComposeKind.forward:
        _subject.text = RegExp(r'^fwd?:', caseSensitive: false).hasMatch(s.subject) ? s.subject : 'Fwd: ${s.subject}';
        _quote = quoteHeader(
          '---------- Forwarded message ----------<br>From: $sender<br>Date: ${longDate(s.sentAt)}<br>'
          'Subject: ${escapeHtml(s.subject)}<br>To: ${escapeHtml(s.to.map((a) => a.address).join(', '))}',
        );
        _fetchForwardedAttachments(s);
      case ComposeKind.fresh:
        break;
    }
  }

  Future<void> _fetchForwardedAttachments(Message s) async {
    for (final a in s.attachments) {
      try {
        final bytes = await ref.read(apiProvider).attachment(a.id);
        if (mounted) setState(() => _attachments.add(_Attachment(a.filename, a.mimeType, bytes)));
      } catch (_) {}
    }
  }

  void _applyTemplate(MailTemplate t) {
    if ((t.subject ?? '').isNotEmpty && _subject.text.isEmpty) _subject.text = t.subject!;
    if ((t.blocksJson ?? '').length > 2) {
      _body.loadBlocks(t.blocksJson!);
    } else if ((t.html ?? '').isNotEmpty) {
      _body.loadHtml(t.html!);
    }
  }

  void _restore(ComposeDraft d) {
    setState(() {
      _kind = ComposeKind.values.byName(d.kind);
      _sourceId = d.sourceId;
      _from = d.from;
      _fromName = d.fromName;
      _to = d.to;
      _cc = d.cc;
      _bcc = d.bcc;
      _showCopies = d.cc.isNotEmpty || d.bcc.isNotEmpty;
      _subject.text = d.subject;
      _signatureOff = d.signatureOff;
      _quote = d.quoteHtml;
      final restored = BodyEditorController.fromJson(d.body);
      _body
        ..mode = restored.mode
        ..html.text = restored.html.text
        ..blocks = restored.blocks
        ..quill.document = restored.quill.document;
    });
    _signature = _signatures.where((s) => s.id == d.signatureId).firstOrNull;
  }

  ComposeDraft get _draft => ComposeDraft(
    id: _draftId,
    kind: _kind.name,
    sourceId: _sourceId,
    from: _from,
    fromName: _fromName,
    to: _to,
    cc: _cc,
    bcc: _bcc,
    subject: _subject.text,
    body: _body.toJson(),
    signatureId: _signature?.id,
    signatureOff: _signatureOff,
    quoteHtml: _quote,
  );

  bool get _blank => _to.isEmpty && _subject.text.trim().isEmpty && _body.isEmpty;

  void _changed() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_blank || _sending) return;
    final account = ref.read(activeAccountProvider);
    if (account != null) await ref.read(databaseProvider).putDraft(_draftId, account.id, jsonEncode(_draft.toJson()));
  }

  String _assemble() {
    var html = _body.render();
    final sig = _signature;
    if (sig != null && !_signatureOff && ref.read(settingsProvider).autoSignature && !containsSignature(html, sig)) {
      html = appendToBody(html, wrapSignature(sig));
    }
    if (_quote != null) html = appendToBody(html, _quote!);
    return html;
  }

  Future<(String, String)?> _withVariables(String subject, String html) async {
    final names = findVariables([subject, html]);
    if (names.isEmpty) return (subject, html);
    final values = await askVariables(context, names);
    if (values == null) return null;
    return (fillVariables(subject, values), fillVariables(html, values));
  }

  Future<void> _send({bool test = false}) async {
    _toKey.currentState?.commit();
    final recipients = test ? [_from] : _to;
    if (_from.isEmpty) return showToast(context, 'Choose who this is from');
    if (recipients.isEmpty) return showToast(context, 'Add at least one recipient');
    final bad = [...recipients, ..._cc, ..._bcc].where((a) => !isValidEmail(a)).toList();
    if (bad.isNotEmpty) return showToast(context, 'Check ${bad.join(', ')}');
    if (_body.isEmpty && _subject.text.trim().isEmpty) return showToast(context, 'Write something first');

    final filled = await _withVariables(_subject.text.trim(), _assemble());
    if (filled == null || !mounted) return;
    final (subject, html) = filled;
    setState(() => _sending = true);
    final payload = {
      'from': _from,
      'fromName': _fromName,
      'to': recipients,
      'cc': test ? [] : _cc,
      'bcc': test ? [] : _bcc,
      'subject': test ? '[Test] $subject' : subject,
      'html': html,
      'text': htmlToPlain(html),
      'attachments': [
        for (final a in _attachments) {'filename': a.name, 'type': a.type, 'content': base64Encode(a.bytes)},
      ],
    };
    try {
      final api = ref.read(apiProvider);
      final isReply = !test && _sourceId != null && (_kind == ComposeKind.reply || _kind == ComposeKind.replyAll);
      isReply ? await api.reply(_sourceId!, payload) : await api.send(payload);
      Feel.commit.ring();
      if (!mounted) return;
      if (test) {
        showToast(context, 'Test sent to $_from');
        setState(() => _sending = false);
        return;
      }
      _autosave?.cancel();
      await ref.read(databaseProvider).deleteDraft(_draftId);
      ref.invalidate(inboxProvider('sent'));
      if (!mounted) return;
      showToast(context, 'Sent');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, 'Not sent: $e');
    }
  }

  Future<void> _attach() async {
    final files = await FilePicker.pickFiles();
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final ext = (f.extension ?? '').toLowerCase();
      setState(() => _attachments.add(_Attachment(f.name, _mimes[ext] ?? 'application/octet-stream', bytes)));
    }
    if (files.isNotEmpty) Feel.turn.ring();
  }

  Future<void> _chooseFrom() async {
    final senders = _senders?.senders ?? [];
    final domain = _senders?.domain ?? _from.split('@').last;
    final local = TextEditingController(text: _from.split('@').first);
    final name = TextEditingController(text: _fromName);
    final picked = await showQuireSheet<(String, String)>(
      context,
      (sheet) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Send from'),
            for (final s in senders)
              SheetRow(
                label: s.address,
                icon: LucideIcons.atSign,
                selected: s.address == _from,
                onTap: () => Navigator.pop(sheet, (s.address, name.text.trim().isEmpty ? s.name : name.text.trim())),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: local,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('@$domain', style: AppText.search.copyWith(color: AppColors.inkSoft)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: PillButton(
                  label: 'Use this',
                  onTap: () => Navigator.pop(sheet, ('${local.text.trim().toLowerCase()}@$domain', name.text.trim())),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.$1;
      _fromName = picked.$2;
      _pickSignature();
    });
    _changed();
  }

  Future<void> _chooseSignature() async {
    final options = _signatures.where((s) => s.appliesTo(_from)).toList();
    final picked = await showQuireSheet<Object>(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetTitle('Signature for this email'),
          for (final s in options)
            SheetRow(
              label: s.name,
              icon: LucideIcons.signature,
              selected: s.id == _signature?.id && !_signatureOff,
              onTap: () => Navigator.pop(sheet, s),
            ),
          SheetRow(label: 'No signature', icon: LucideIcons.ban, onTap: () => Navigator.pop(sheet, false)),
          SheetRow(label: 'Manage signatures', icon: LucideIcons.settings, onTap: () => Navigator.pop(sheet, 'manage')),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == 'manage') {
      await context.push('/signatures');
      _signatures = await ref.refresh(signaturesProvider.future);
      setState(_pickSignature);
      return;
    }
    setState(() {
      _signatureOff = picked == false;
      if (picked is Signature) _signature = picked;
    });
    _changed();
  }

  Future<void> _menu() async {
    final action = await showQuireSheet<String>(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetRow(label: 'Preview', icon: LucideIcons.eye, onTap: () => Navigator.pop(sheet, 'preview')),
          SheetRow(label: 'Send test to myself', icon: LucideIcons.sendHorizontal, onTap: () => Navigator.pop(sheet, 'test')),
          SheetRow(label: 'Use a template', icon: LucideIcons.layoutTemplate, onTap: () => Navigator.pop(sheet, 'template')),
          SheetRow(label: 'Save as template', icon: LucideIcons.bookmarkPlus, onTap: () => Navigator.pop(sheet, 'save')),
          SheetRow(label: 'Discard draft', icon: LucideIcons.trash2, destructive: true, onTap: () => Navigator.pop(sheet, 'discard')),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'preview':
        showPreview(context, _assemble());
      case 'test':
        await _send(test: true);
      case 'template':
        final t = await context.push<MailTemplate>('/templates?pick=1');
        if (t != null) setState(() => _applyTemplate(t));
      case 'save':
        final name = await promptText(context, title: 'Save as template', initial: _subject.text, action: 'Save template');
        if (name == null || name.isEmpty) return;
        final html = _body.render();
        try {
          await ref
              .read(templatesProvider.notifier)
              .save(
                MailTemplate(
                  id: '',
                  name: name,
                  subject: _subject.text,
                  html: html,
                  blocksJson: _body.mode == BodyMode.builder ? _body.toJson()['blocks'] : null,
                  variables: findVariables([_subject.text, html]),
                ),
              );
          if (mounted) showToast(context, 'Template saved');
        } catch (e) {
          if (mounted) showToast(context, '$e');
        }
      case 'discard':
        _autosave?.cancel();
        await ref.read(databaseProvider).deleteDraft(_draftId);
        if (mounted) context.pop();
    }
  }

  Future<void> _close() async {
    _autosave?.cancel();
    await _saveDraft();
    if (!mounted) return;
    if (!_blank) showToast(context, 'Saved to drafts');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, color: AppColors.hairline);
    return Hero(
      tag: 'compose',
      flightShuttleBuilder: composeFlight,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Close', onTap: _close),
            actions: [
              IconPress(icon: LucideIcons.paperclip, label: 'Attach', onTap: _attach),
              _sending
                  ? const Padding(padding: EdgeInsets.all(12), child: QuireSpinner(size: 22))
                  : IconPress(icon: LucideIcons.sendHorizontal, label: 'Send', color: AppColors.accentBright, onTap: _send),
              IconPress(icon: LucideIcons.ellipsisVertical, label: 'More', onTap: _menu),
            ],
          ),
          body: Column(
            children: [
              PaperPress(
                onTap: _chooseFrom,
                semanticLabel: 'Change sender',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text('From', style: AppText.search.copyWith(color: AppColors.inkSoft)),
                      ),
                      Expanded(
                        child: Text(
                          _from.isEmpty ? 'Loading senders' : (_fromName.isEmpty ? _from : '$_fromName <$_from>'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.search.copyWith(color: AppColors.ink),
                        ),
                      ),
                      Icon(LucideIcons.chevronDown, size: 18, color: AppColors.inkSoft),
                    ],
                  ),
                ),
              ),
              divider,
              RecipientField(
                key: _toKey,
                label: 'To',
                values: _to,
                onChanged: (v) {
                  setState(() => _to = v);
                  _changed();
                },
                trailing: IconPress(
                  icon: _showCopies ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  label: 'Cc and Bcc',
                  size: 18,
                  onTap: () => setState(() => _showCopies = !_showCopies),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _showCopies
                    ? Column(
                        children: [
                          divider,
                          RecipientField(label: 'Cc', values: _cc, onChanged: (v) => setState(() => _cc = v)),
                          divider,
                          RecipientField(label: 'Bcc', values: _bcc, onChanged: (v) => setState(() => _bcc = v)),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
              divider,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _subject,
                  style: AppText.search.copyWith(color: AppColors.ink),
                  decoration: const InputDecoration(hintText: 'Subject', fillColor: Colors.transparent),
                ),
              ),
              divider,
              if (_attachments.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    children: [
                      for (final a in _attachments)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            avatar: Icon(LucideIcons.paperclip, size: 16, color: AppColors.accentBright),
                            label: Text('${a.name}  ${fileSize(a.bytes.length)}', style: AppText.label.copyWith(color: AppColors.ink)),
                            onDeleted: () => setState(() => _attachments.remove(a)),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: BodyEditor(controller: _body, uploadImage: () => pickAndUploadImage(context, ref)),
              ),
              _SignatureBar(
                signature: _signatureOff ? null : _signature,
                autoOn: ref.watch(settingsProvider).autoSignature,
                hasQuote: _quote != null,
                onChoose: _chooseSignature,
                onRemove: () {
                  Feel.tap.ring();
                  setState(() => _signatureOff = true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureBar extends StatelessWidget {
  const _SignatureBar({
    required this.signature,
    required this.autoOn,
    required this.hasQuote,
    required this.onChoose,
    required this.onRemove,
  });
  final Signature? signature;
  final bool autoOn;
  final bool hasQuote;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = signature;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                PaperPress(
                  onTap: onChoose,
                  semanticLabel: 'Choose signature',
                  washRadius: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.signature, size: 16, color: AppColors.accentBright),
                        const SizedBox(width: 6),
                        Text(
                          s == null ? 'No signature' : (autoOn ? s.name : '${s.name} (auto off)'),
                          style: AppText.label.copyWith(color: AppColors.ink),
                        ),
                        Icon(LucideIcons.chevronDown, size: 14, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                ),
                if (s != null) IconPress(icon: LucideIcons.x, label: 'Remove signature for this email', size: 16, onTap: onRemove),
                const Spacer(),
                if (hasQuote) Text('Quoted text below signature', style: AppText.docMeta.copyWith(color: AppColors.inkFaint)),
              ],
            ),
            if (s != null && autoOn)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '-- ${htmlToPlain(s.html)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
