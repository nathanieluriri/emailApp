import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../accounts/accounts_controller.dart';
import 'signature.dart';

class SignaturesController extends AsyncNotifier<List<Signature>> {
  @override
  Future<List<Signature>> build() => ref.watch(apiProvider).signatures();

  Future<Signature> save(Signature s) async {
    final create = s.id.isEmpty;
    final saved = await ref
        .read(apiProvider)
        .saveSignature(
          create ? Signature(id: const Uuid().v4(), name: s.name, html: s.html, senderAddress: s.senderAddress, isDefault: s.isDefault) : s,
          create: create,
        );
    ref.invalidateSelf();
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(apiProvider).deleteSignature(id);
    state = AsyncData((state.value ?? []).where((x) => x.id != id).toList());
  }
}

final signaturesProvider = AsyncNotifierProvider<SignaturesController, List<Signature>>(SignaturesController.new);

/// The default for this sender wins over a default for every sender.
Signature? defaultSignatureFor(List<Signature> all, String from) {
  final defaults = all.where((s) => s.isDefault && s.appliesTo(from)).toList()
    ..sort((a, b) => (a.senderAddress == null ? 1 : 0) - (b.senderAddress == null ? 1 : 0));
  return defaults.firstOrNull;
}

const signatureMarker = 'data-bw-signature';

String wrapSignature(Signature s) => '<div $signatureMarker="${s.id}" style="margin-top:16px;">${s.html}</div>';

/// Never append twice: a template that already carries this signature, or any signature block, is left alone.
bool containsSignature(String html, Signature s) => html.contains(signatureMarker) || (s.html.isNotEmpty && html.contains(s.html));
