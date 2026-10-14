import 'package:bridgewood_mail/compose/body_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing keeps the editor focused and formatting reaches the HTML', (tester) async {
    final body = BodyEditorController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: ListenableBuilder(
            listenable: body,
            builder: (_, _) => RichEditor(controller: body.quill),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    final focus = tester.widget<QuillEditor>(find.byType(QuillEditor)).focusNode;
    expect(focus.hasFocus, isTrue);

    for (final word in ['Hello ', 'there']) {
      body.quill.document.insert(body.quill.document.length - 1, word);
      await tester.pump();
    }
    expect(tester.widget<QuillEditor>(find.byType(QuillEditor)).focusNode, same(focus));
    expect(focus.hasFocus, isTrue);

    body.quill.formatText(0, 5, Attribute.bold);
    await tester.pump();
    expect(body.render(), contains('<strong>Hello</strong> there'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
