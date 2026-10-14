import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _shell = '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;padding:0;background:#fff;color:#111;font-family:-apple-system,Roboto,Inter,sans-serif;font-size:16px;line-height:1.5;word-wrap:break-word}
body{padding:12px}img{max-width:100%;height:auto}table{max-width:100%!important}pre{white-space:pre-wrap}</style></head>
<body>__BODY__<script>
function h(){Height.postMessage(String(document.documentElement.scrollHeight))}
window.addEventListener('load',h);new ResizeObserver(h).observe(document.body);setTimeout(h,300);
</script></body></html>''';

final _designed = RegExp(r'bgcolor|background|<table', caseSensitive: false);

// Inline text colours chosen for a white page (such as compose's #1C1B1F) would vanish on the dark one.
const _lighten = '''for(const e of document.body.querySelectorAll('*')){const c=getComputedStyle(e).color.match(/[\\d.]+/g);
if(c&&(.2126*c[0]+.7152*c[1]+.0722*c[2])/255<.45)e.style.setProperty('color',e.closest('a')?'#D0BCFF':'#E6E1E5','important')}''';

/// Plain emails take the app's dark colours; designed ones keep the white page they were drawn on.
String wrapEmailHtml(String body, {bool dark = false}) {
  final page = _shell.replaceFirst('__BODY__', body);
  if (!dark || _designed.hasMatch(body)) return page;
  return page
      .replaceFirst(
        '</style>',
        'html,body{background:#1E1E22;color:#E6E1E5}a{color:#D0BCFF}blockquote{border-color:#4A4458!important}</style>',
      )
      .replaceFirst('<script>', '<script>$_lighten\n');
}

/// Renders an email body in a webview that grows to fit its content, so it scrolls with the thread.
class HtmlView extends StatefulWidget {
  const HtmlView({super.key, required this.html, this.fixedWidth, this.dark = false});
  final String html;
  final bool dark;
  final double? fixedWidth;

  @override
  State<HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<HtmlView> {
  double _height = 120;
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.transparent)
    ..addJavaScriptChannel(
      'Height',
      onMessageReceived: (m) {
        final h = double.tryParse(m.message);
        if (h != null && mounted && (h - _height).abs() > 1) setState(() => _height = h);
      },
    )
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) {
          if (r.url.startsWith('about:') || r.url.startsWith('data:')) return NavigationDecision.navigate;
          launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ),
    )
    ..loadHtmlString(wrapEmailHtml(widget.html, dark: widget.dark));

  @override
  void didUpdateWidget(HtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html || old.dark != widget.dark) _controller.loadHtmlString(wrapEmailHtml(widget.html, dark: widget.dark));
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    height: _height,
    width: widget.fixedWidth,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: WebViewWidget(controller: _controller),
    ),
  );
}
