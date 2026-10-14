import '../compose/html_tools.dart';

class SignatureFields {
  String name = '';
  String title = '';
  String phone = '';
  String website = '';
  String logoUrl = '';
  String linkedin = '';
  String x = '';
  String instagram = '';
}

/// A brand-styled signature: logo beside the name, purple rule, then contact lines and social links.
String generateSignature(SignatureFields f) {
  const font = "font-family:Inter,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;";
  String link(String url, String label) =>
      '<a href="${escapeHtml(url)}" style="color:#4F378B;text-decoration:none;font-weight:600;">${escapeHtml(label)}</a>';
  final socials = [
    if (f.linkedin.isNotEmpty) link(f.linkedin, 'LinkedIn'),
    if (f.x.isNotEmpty) link(f.x, 'X'),
    if (f.instagram.isNotEmpty) link(f.instagram, 'Instagram'),
  ];
  final website = f.website.isEmpty
      ? ''
      : link(f.website.startsWith('http') ? f.website : 'https://${f.website}', f.website.replaceFirst(RegExp(r'^https?://'), ''));
  return '<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="$font">'
      '<tr>'
      '${f.logoUrl.isEmpty ? '' : '<td valign="top" style="padding-right:14px;"><img src="${escapeHtml(f.logoUrl)}" width="56" height="56" alt="" style="display:block;border-radius:12px;"></td>'}'
      '<td valign="top" style="border-left:3px solid #4F378B;padding-left:12px;">'
      '<div style="font-size:15px;font-weight:700;color:#1C1B1F;">${escapeHtml(f.name)}</div>'
      '${f.title.isEmpty ? '' : '<div style="font-size:13px;color:#49454F;margin-top:2px;">${escapeHtml(f.title)}</div>'}'
      '<div style="font-size:13px;color:#49454F;margin-top:6px;">'
      '${f.phone.isEmpty ? '' : '<a href="tel:${escapeHtml(f.phone.replaceAll(' ', ''))}" style="color:#49454F;text-decoration:none;">${escapeHtml(f.phone)}</a>'}'
      '${f.phone.isNotEmpty && website.isNotEmpty ? ' &middot; ' : ''}$website</div>'
      '${socials.isEmpty ? '' : '<div style="font-size:12px;margin-top:6px;">${socials.join(' &middot; ')}</div>'}'
      '</td></tr></table>';
}
