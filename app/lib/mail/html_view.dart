import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _shell = '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;padding:0;background:#fff;color:#111;font-family:-apple-system,Roboto,Inter,sans-serif;font-size:15px;line-height:1.45;word-wrap:break-word}
body{padding:12px}img{max-width:100%;height:auto}table{max-width:100%!important}pre{white-space:pre-wrap}</style></head>
<body>__BODY__<script>
function h(){Height.postMessage(String(document.documentElement.scrollHeight))}
window.addEventListener('load',h);new ResizeObserver(h).observe(document.body);setTimeout(h,300);
</script></body></html>''';

String wrapEmailHtml(String body) => _shell.replaceFirst('__BODY__', body);

/// Renders an email body in a webview that grows to fit its content, so it scrolls with the thread.
class HtmlView extends StatefulWidget {
  const HtmlView({super.key, required this.html, this.fixedWidth});
  final String html;
  final double? fixedWidth;

  @override
  State<HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<HtmlView> {
  double _height = 120;
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
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
    ..loadHtmlString(wrapEmailHtml(widget.html));

  @override
  void didUpdateWidget(HtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _controller.loadHtmlString(wrapEmailHtml(widget.html));
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
