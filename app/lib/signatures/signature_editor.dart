import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../builder/upload.dart';
import '../compose/body_editor.dart';
import '../compose/preview.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/quire_spinner.dart';
import '../core/widgets.dart';
import '../mail/models.dart';
import 'generator.dart';
import 'signature.dart';
import 'signatures_repository.dart';

class SignatureEditor extends ConsumerStatefulWidget {
  const SignatureEditor({super.key, required this.signature});
  final Signature signature;

  @override
  ConsumerState<SignatureEditor> createState() => _SignatureEditorState();
}

class _SignatureEditorState extends ConsumerState<SignatureEditor> {
  late final _name = TextEditingController(text: widget.signature.name);
  late final _body = BodyEditorController(
    mode: widget.signature.html.isEmpty ? BodyMode.rich : BodyMode.html,
    html: widget.signature.html,
    fragment: true,
  );
  late String? _sender = widget.signature.senderAddress;
  late bool _default = widget.signature.isDefault;
  bool _generator = false;
  bool _saving = false;
  List<Sender> _senders = [];
  final _fields = SignatureFields();

  @override
  void initState() {
    super.initState();
    _generator = widget.signature.html.isEmpty;
    ref
        .read(apiProvider)
        .senders()
        .then((s) {
          if (mounted) setState(() => _senders = s.senders);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  void _generate() {
    _body.loadHtml(generateSignature(_fields));
    Feel.commit.ring();
    setState(() => _generator = false);
  }

  Future<void> _save() async {
    final html = _generator ? generateSignature(_fields) : _body.render();
    if (_name.text.trim().isEmpty) return showToast(context, 'Name the signature');
    setState(() => _saving = true);
    try {
      await ref
          .read(signaturesProvider.notifier)
          .save(Signature(id: widget.signature.id, name: _name.text.trim(), html: html, senderAddress: _sender, isDefault: _default));
      Feel.commit.ring();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, '$e');
      }
    }
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: value,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconPress(icon: LucideIcons.x, label: 'Close', onTap: () => context.pop()),
      title: const Text('Signature'),
      actions: [
        IconPress(
          icon: LucideIcons.eye,
          label: 'Preview',
          onTap: () => showPreview(context, _generator ? generateSignature(_fields) : _body.render()),
        ),
        _saving
            ? const Padding(padding: EdgeInsets.all(12), child: QuireSpinner(size: 22))
            : IconPress(icon: LucideIcons.check, label: 'Save', color: AppColors.accentBright, onTap: _save),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _sender,
                  decoration: const InputDecoration(labelText: 'Used for'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All senders')),
                    for (final s in _senders) DropdownMenuItem(value: s.address, child: Text(s.address)),
                    if (_sender != null && !_senders.any((s) => s.address == _sender))
                      DropdownMenuItem(value: _sender, child: Text(_sender!)),
                  ],
                  onChanged: (v) => setState(() => _sender = v),
                ),
              ),
              const SizedBox(width: 12),
              Text('Default', style: AppText.label.copyWith(color: AppColors.inkSoft)),
              Switch(
                value: _default,
                onChanged: (v) {
                  Feel.tap.ring();
                  setState(() => _default = v);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: GooSegmented<bool>(
            values: const [true, false],
            labels: const ['Quick generator', 'Editor'],
            selected: _generator,
            onChanged: (v) => setState(() => _generator = v),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _generator
                ? ListView(
                    key: const ValueKey('generator'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _field('Full name', _fields.name, (v) => _fields.name = v),
                      _field('Job title', _fields.title, (v) => _fields.title = v),
                      _field('Phone', _fields.phone, (v) => _fields.phone = v, type: TextInputType.phone),
                      _field('Website', _fields.website, (v) => _fields.website = v, type: TextInputType.url),
                      _field('LinkedIn', _fields.linkedin, (v) => _fields.linkedin = v, type: TextInputType.url),
                      _field('X', _fields.x, (v) => _fields.x = v, type: TextInputType.url),
                      _field('Instagram', _fields.instagram, (v) => _fields.instagram = v, type: TextInputType.url),
                      Row(
                        children: [
                          PillButton(
                            label: _fields.logoUrl.isEmpty ? 'Upload logo' : 'Logo added',
                            icon: _fields.logoUrl.isEmpty ? LucideIcons.upload : LucideIcons.circleCheck,
                            filled: false,
                            onTap: () async {
                              final url = await pickAndUploadImage(context, ref);
                              if (url != null) setState(() => _fields.logoUrl = url);
                            },
                          ),
                          const Spacer(),
                          PillButton(label: 'Generate', icon: LucideIcons.wandSparkles, onTap: _generate),
                        ],
                      ),
                    ],
                  )
                : BodyEditor(key: const ValueKey('editor'), controller: _body, uploadImage: () => pickAndUploadImage(context, ref)),
          ),
        ),
      ],
    ),
  );
}
