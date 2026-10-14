import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../accounts/accounts_controller.dart';
import 'template.dart';

class TemplatesController extends AsyncNotifier<List<MailTemplate>> {
  @override
  Future<List<MailTemplate>> build() => ref.watch(apiProvider).templates();

  Future<MailTemplate> save(MailTemplate t) async {
    final create = t.id.startsWith('starter-') || t.id.isEmpty || !(state.value ?? []).any((x) => x.id == t.id);
    final toSave = create
        ? MailTemplate(
            id: const Uuid().v4(),
            name: t.name,
            subject: t.subject,
            html: t.html,
            blocksJson: t.blocksJson,
            variables: t.variables,
          )
        : t;
    final saved = await ref.read(apiProvider).saveTemplate(toSave, create: create);
    state = AsyncData([saved, ...(state.value ?? []).where((x) => x.id != saved.id)]);
    return saved;
  }

  Future<void> duplicate(MailTemplate t) => save(
    MailTemplate(id: '', name: '${t.name} copy', subject: t.subject, html: t.html, blocksJson: t.blocksJson, variables: t.variables),
  );

  Future<void> delete(String id) async {
    await ref.read(apiProvider).deleteTemplate(id);
    state = AsyncData((state.value ?? []).where((x) => x.id != id).toList());
  }
}

final templatesProvider = AsyncNotifierProvider<TemplatesController, List<MailTemplate>>(TemplatesController.new);
