import 'blocks.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _lines(String s) => _esc(s).replaceAll('\n', '<br>');

const _font = "font-family:Inter,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;";

String _textStyle(Block b, {String weight = '400'}) =>
    '$_font font-size:${b.numOf('fontSize')}px;line-height:1.5;color:${b.str('color')};font-weight:$weight;margin:0;';

String _cell(Block b, String inner) =>
    '<tr><td align="${b.str('align').isEmpty ? 'left' : b.str('align')}" style="padding:${b.numOf('padding')}px 24px;">$inner</td></tr>';

String blockHtml(Block b) => switch (b.type) {
  BlockType.heading => _cell(b, '<h1 style="${_textStyle(b, weight: '700')}line-height:1.25;">${_lines(b.str('text'))}</h1>'),
  BlockType.text => _cell(b, '<p style="${_textStyle(b)}">${_lines(b.str('text'))}</p>'),
  BlockType.footer => _cell(b, '<p style="${_textStyle(b)}">${_lines(b.str('text'))}</p>'),
  BlockType.button => _cell(
    b,
    '<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="display:inline-table;"><tr>'
    '<td bgcolor="${b.str('color')}" style="border-radius:${b.numOf('radius')}px;background:${b.str('color')};">'
    '<a href="${_esc(b.str('url'))}" target="_blank" style="display:inline-block;padding:12px 26px;$_font font-size:${b.numOf('fontSize')}px;'
    'font-weight:600;color:${b.str('textColor')};text-decoration:none;border-radius:${b.numOf('radius')}px;">${_esc(b.str('text'))}</a>'
    '</td></tr></table>',
  ),
  BlockType.image =>
    b.str('src').isEmpty
        ? ''
        : _cell(b, () {
            final img =
                '<img src="${_esc(b.str('src'))}" alt="${_esc(b.str('alt'))}" width="552" '
                'style="display:block;width:100%;max-width:552px;height:auto;border:0;border-radius:${b.numOf('radius')}px;">';
            return b.str('link').isEmpty ? img : '<a href="${_esc(b.str('link'))}" target="_blank">$img</a>';
          }()),
  BlockType.divider => _cell(b, '<div style="height:1px;line-height:1px;font-size:1px;background:${b.str('color')};">&nbsp;</div>'),
  BlockType.spacer => '<tr><td style="height:${b.numOf('height')}px;line-height:${b.numOf('height')}px;font-size:1px;">&nbsp;</td></tr>',
  BlockType.columns => _cell(
    b,
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
    '<td class="col" width="50%" valign="top" style="padding-right:8px;"><p style="${_textStyle(b)}">${_lines(b.str('left'))}</p></td>'
    '<td class="col" width="50%" valign="top" style="padding-left:8px;"><p style="${_textStyle(b)}">${_lines(b.str('right'))}</p></td>'
    '</tr></table>',
  ),
  BlockType.social => () {
    const names = {'website': 'Website', 'linkedin': 'LinkedIn', 'x': 'X', 'instagram': 'Instagram', 'facebook': 'Facebook'};
    final links = [
      for (final e in names.entries)
        if (b.str(e.key).isNotEmpty)
          '<a href="${_esc(b.str(e.key))}" target="_blank" style="$_font font-size:13px;font-weight:600;color:${b.str('color')};'
              'text-decoration:none;padding:0 8px;">${e.value}</a>',
    ];
    return links.isEmpty ? '' : _cell(b, links.join('<span style="color:#CAC4D0;">&middot;</span>'));
  }(),
};

/// Table-based, inline-styled HTML that holds up in Gmail and Outlook: 600px wide, single column on phones.
String exportBlocks(List<Block> blocks, {String background = '#F3EFF7', String card = '#FFFFFF'}) =>
    '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="x-apple-disable-message-reformatting">
<style>@media only screen and (max-width:620px){.wrap{width:100%!important}.col{display:block!important;width:100%!important;padding:0 0 12px 0!important}}</style></head>
<body style="margin:0;padding:0;background:$background;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:$background;"><tr><td align="center" style="padding:24px 12px;">
<!--[if mso]><table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
<table role="presentation" class="wrap" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:600px;background:$card;border-radius:12px;">
<tr><td style="height:12px;font-size:1px;line-height:1px;">&nbsp;</td></tr>
${blocks.map(blockHtml).join('\n')}
<tr><td style="height:12px;font-size:1px;line-height:1px;">&nbsp;</td></tr>
</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr></table></body></html>''';

/// The blocks alone, for signatures that sit inside another email.
String exportFragment(List<Block> blocks) =>
    '<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;">${blocks.map(blockHtml).join()}</table>';
