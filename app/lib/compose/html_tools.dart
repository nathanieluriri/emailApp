import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _dangerous = 'script, iframe, object, embed, form, base, meta[http-equiv="refresh"]';

/// Makes pasted HTML safe and email-ready: strips scripts and event handlers, then copies
/// every `<style>` rule onto the elements it matches. `@media` rules stay in a style tag.
String autoFixHtml(String source) {
  final doc = html_parser.parse(source);
  for (final e in doc.querySelectorAll(_dangerous)) {
    e.remove();
  }
  for (final e in doc.querySelectorAll('*')) {
    e.attributes.removeWhere((k, _) => '$k'.toLowerCase().startsWith('on'));
    for (final attr in ['href', 'src']) {
      if ((e.attributes[attr] ?? '').trim().toLowerCase().startsWith('javascript:')) e.attributes[attr] = '#';
    }
  }

  final media = <String>[];
  final rules = <(String, String)>[];
  for (final style in doc.querySelectorAll('style')) {
    var css = style.text.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    css = _extractAtRules(css, media);
    for (final m in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css)) {
      rules.add((m.group(1)!.trim(), m.group(2)!.trim()));
    }
    style.remove();
  }

  final applied = <dom.Element, List<String>>{};
  for (final (selectors, declarations) in rules) {
    if (declarations.isEmpty) continue;
    for (final selector in selectors.split(',')) {
      try {
        for (final el in doc.querySelectorAll(selector.trim())) {
          applied.putIfAbsent(el, () => []).add(declarations.replaceAll(RegExp(r';+$'), ''));
        }
      } catch (_) {}
    }
  }
  applied.forEach((el, styles) => el.attributes['style'] = _joinStyle(styles.join(';'), el.attributes['style'] ?? ''));

  if (media.isNotEmpty) {
    final head = doc.head ?? (doc.documentElement!..insertBefore(dom.Element.tag('head'), doc.body));
    head.append(dom.Element.tag('style')..text = media.join('\n'));
  }
  return doc.outerHtml;
}

String _joinStyle(String inherited, String own) {
  final a = inherited.trim().replaceAll(RegExp(r';+$'), '');
  final b = own.trim();
  return b.isEmpty ? '$a;' : '$a;$b';
}

String _extractAtRules(String css, List<String> sink) {
  final out = StringBuffer();
  var i = 0;
  while (i < css.length) {
    final at = css.indexOf('@', i);
    if (at < 0) {
      out.write(css.substring(i));
      break;
    }
    out.write(css.substring(i, at));
    final open = css.indexOf('{', at);
    final semi = css.indexOf(';', at);
    if (open < 0 || (semi >= 0 && semi < open)) {
      i = semi < 0 ? css.length : semi + 1;
      continue;
    }
    var depth = 0;
    var j = open;
    for (; j < css.length; j++) {
      if (css[j] == '{') depth++;
      if (css[j] == '}' && --depth == 0) break;
    }
    final block = css.substring(at, j < css.length ? j + 1 : css.length);
    if (block.startsWith('@media')) sink.add(block);
    i = j + 1;
  }
  return out.toString();
}

String escapeHtml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String htmlToPlain(String html) => (html_parser.parse(html).body?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Quill's delta to the small set of HTML tags mail clients agree on.
String deltaToHtml(List<dynamic> ops) {
  final out = StringBuffer();
  var line = StringBuffer();
  String? openList;

  void closeList() {
    if (openList != null) out.write(openList == 'ordered' ? '</ol>' : '</ul>');
    openList = null;
  }

  void endLine(Map? attrs) {
    final content = line.toString();
    line = StringBuffer();
    final list = attrs?['list'] as String?;
    final header = attrs?['header'];
    final align = attrs?['align'] as String?;
    final alignStyle = align == null ? '' : 'text-align:$align;';
    if (list != openList) {
      closeList();
      if (list != null) out.write(list == 'ordered' ? '<ol style="margin:0 0 12px;">' : '<ul style="margin:0 0 12px;">');
      openList = list;
    }
    if (list != null) {
      out.write('<li>$content</li>');
    } else if (header != null) {
      out.write('<h$header style="margin:0 0 10px;$alignStyle">$content</h$header>');
    } else if (attrs?['blockquote'] == true) {
      out.write('<blockquote style="margin:0 0 12px;padding-left:12px;border-left:3px solid #CAC4D0;color:#49454F;">$content</blockquote>');
    } else {
      out.write('<p style="margin:0 0 12px;$alignStyle">${content.isEmpty ? '<br>' : content}</p>');
    }
  }

  String inline(String text, Map? a) {
    var s = escapeHtml(text);
    if (a == null) return s;
    if (a['bold'] == true) s = '<strong>$s</strong>';
    if (a['italic'] == true) s = '<em>$s</em>';
    if (a['underline'] == true) s = '<u>$s</u>';
    if (a['strike'] == true) s = '<s>$s</s>';
    if (a['color'] is String) s = '<span style="color:${a['color']};">$s</span>';
    if (a['link'] is String) s = '<a href="${escapeHtml(a['link'])}" style="color:#4F378B;">$s</a>';
    return s;
  }

  for (final op in ops) {
    final insert = op['insert'];
    if (insert is! String) continue;
    final attrs = op['attributes'] as Map?;
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) line.write(inline(parts[i], attrs));
      if (i < parts.length - 1) endLine(attrs);
    }
  }
  if (line.isNotEmpty) endLine(null);
  closeList();
  return '<div style="font-family:Inter,Roboto,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.5;color:#1C1B1F;">$out</div>';
}

/// Puts [extra] at the end of the visible body, inside `<body>` when the HTML is a full document.
String appendToBody(String html, String extra) {
  final close = html.toLowerCase().lastIndexOf('</body>');
  return close < 0 ? '$html$extra' : '${html.substring(0, close)}$extra${html.substring(close)}';
}
