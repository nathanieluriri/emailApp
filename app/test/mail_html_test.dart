import 'package:bridgewood_mail/builder/blocks.dart';
import 'package:bridgewood_mail/builder/html_export.dart';
import 'package:bridgewood_mail/compose/html_tools.dart';
import 'package:bridgewood_mail/mail/quote.dart';
import 'package:bridgewood_mail/signatures/signature.dart';
import 'package:bridgewood_mail/signatures/signatures_repository.dart';
import 'package:bridgewood_mail/templates/variables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto-fix strips scripts and handlers and inlines CSS, keeping media queries', () {
    final out = autoFixHtml(
      '<html><head><style>p{color:red} .x{font-weight:bold} @media (max-width:600px){p{color:blue}}</style>'
      '<script>alert(1)</script></head><body><p class="x" onclick="evil()" style="margin:0">Hi</p><a href="javascript:x()">l</a></body></html>',
    );
    expect(out, isNot(contains('<script')));
    expect(out, isNot(contains('onclick')));
    expect(out, contains('style="color:red;font-weight:bold;margin:0"'));
    expect(out, contains('@media (max-width:600px)'));
    expect(out, contains('href="#"'));
  });

  test('quill delta becomes mail-safe HTML', () {
    final html = deltaToHtml([
      {'insert': 'Title'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      {
        'insert': 'Bold',
        'attributes': {'bold': true},
      },
      {'insert': ' and <plain>\n'},
      {'insert': 'one'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      },
    ]);
    expect(html, contains('<h1 style="margin:0 0 10px;">Title</h1>'));
    expect(html, contains('<strong>Bold</strong> and &lt;plain&gt;'));
    expect(html, contains('<ul style="margin:0 0 12px;"><li>one</li></ul>'));
  });

  test('builder export is a 600px table with inline styles and a bulletproof button', () {
    final html = exportBlocks([
      Block(type: BlockType.heading),
      Block(type: BlockType.button, props: {'url': 'https://x.ng'}),
    ]);
    expect(html, contains('width="600"'));
    expect(html, contains('<!--[if mso]>'));
    expect(html, contains('bgcolor="#4F378B"'));
    expect(html, contains('href="https://x.ng"'));
    expect(decodeBlocks(encodeBlocks([Block(type: BlockType.text)])).single.type, BlockType.text);
  });

  test('variables are found once and filled', () {
    expect(findVariables(['Hi {{first_name}}', '{{ amount }} for {{first_name}}']), ['first_name', 'amount']);
    expect(fillVariables('Hi {{first_name}}, {{x}}', {'first_name': 'Ada'}), 'Hi Ada, {{x}}');
  });

  test('a signature is never added twice', () {
    const sig = Signature(id: 's1', name: 'Me', html: '<b>Ada</b>');
    expect(containsSignature('<p>hi</p>', sig), isFalse);
    expect(containsSignature(appendToBody('<p>hi</p>', wrapSignature(sig)), sig), isTrue);
    expect(containsSignature('<p>hi</p><b>Ada</b>', sig), isTrue);
    expect(appendToBody('<html><body><p>a</p></body></html>', 'X'), '<html><body><p>a</p>X</body></html>');
  });

  test('the default signature for a sender beats the one for everyone', () {
    const all = Signature(id: 'a', name: 'All', isDefault: true);
    const admin = Signature(id: 'b', name: 'Admin', senderAddress: 'admin@x.ng', isDefault: true);
    expect(defaultSignatureFor([all, admin], 'admin@x.ng')?.id, 'b');
    expect(defaultSignatureFor([all, admin], 'info@x.ng')?.id, 'a');
  });

  test('quoted replies fold away from what was written', () {
    final (body, quoted) = splitQuotedHtml(
      '<div>Cool message</div><div class="gmail_quote">On Wed someone wrote:<blockquote>old</blockquote></div>',
    );
    expect(body, contains('Cool message'));
    expect(body, isNot(contains('old')));
    expect(quoted, contains('old'));
    expect(splitQuotedHtml('<p>no quote here</p>').$2, isNull);
    final (text, older) = splitQuotedText('Thanks!\n\nOn Wed, 14 Oct 2026, Ada <ada@x.ng> wrote:\n> earlier');
    expect(text, 'Thanks!');
    expect(older, contains('earlier'));
  });
}
