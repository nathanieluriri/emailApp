import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _quoteSelectors =
    '.gmail_quote, .gmail_quote_container, .bw-quote, blockquote[type="cite"], .moz-cite-prefix, #appendonsend, #divRplyFwdMsg';

/// Splits an email into what was written and the earlier message it quotes, the way Gmail folds "Show quoted text".
(String body, String? quoted) splitQuotedHtml(String html) {
  final doc = html_parser.parse(html);
  final start = doc.querySelector(_quoteSelectors);
  if (start == null) return (html, null);
  final quoted = StringBuffer();
  final parent = start.parent;
  final siblings = parent == null ? <dom.Node>[start] : parent.nodes.sublist(parent.nodes.indexOf(start));
  for (final n in siblings.toList()) {
    quoted.write(n is dom.Element ? n.outerHtml : n.text);
    n.remove();
  }
  final body = doc.body?.innerHtml ?? '';
  if (body.replaceAll(RegExp(r'<[^>]+>|&nbsp;|\s'), '').isEmpty) return (html, null);
  return (body, quoted.toString());
}

final _wrote = RegExp(r'^\s*(On .{4,200} wrote:|-{5,} ?Forwarded message ?-{5,}|From: .+)\s*$', multiLine: true);

(String body, String? quoted) splitQuotedText(String text) {
  final lines = text.split('\n');
  var cut = lines.indexWhere((l) => _wrote.hasMatch(l));
  if (cut < 0) cut = lines.indexWhere((l) => l.startsWith('>'));
  if (cut <= 0) return (text, null);
  return (lines.sublist(0, cut).join('\n').trimRight(), lines.sublist(cut).join('\n'));
}
