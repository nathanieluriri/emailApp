import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/quire/theme/colors.dart';
import '../core/widgets.dart';

enum PreviewDevice { phone, tablet, desktop }

const _widths = {PreviewDevice.phone: 375, PreviewDevice.tablet: 768, PreviewDevice.desktop: 1024};

/// Lays the email out at a real device width and zooms it to fit the pane.
class PreviewPane extends StatefulWidget {
  const PreviewPane({super.key, required this.html, this.device = PreviewDevice.phone});
  final String html;
  final PreviewDevice device;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  final _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setBackgroundColor(Colors.white);
  double? _paneWidth;
  String? _loaded;

  void _load(double paneWidth) {
    final width = _widths[widget.device]!;
    final zoom = (paneWidth / width).clamp(0.2, 1.0);
    final page =
        '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>html{zoom:$zoom}body{margin:0;width:${width}px;background:#fff}</style></head><body>${widget.html}</body></html>';
    if (page == _loaded) return;
    _loaded = page;
    _controller.loadHtmlString(page);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (_paneWidth != box.maxWidth || _loaded == null || !_loaded!.contains(widget.html)) {
        _paneWidth = box.maxWidth;
        _load(box.maxWidth);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(controller: _controller),
      );
    },
  );
}

void showPreview(BuildContext context, String html) => showQuireSheet(context, (_) => _PreviewSheet(html: html));

class _PreviewSheet extends StatefulWidget {
  const _PreviewSheet({required this.html});
  final String html;

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  var _device = PreviewDevice.phone;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.85,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.eye, color: AppColors.inkSoft, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: GooSegmented<PreviewDevice>(
                  values: PreviewDevice.values,
                  labels: const ['Phone', 'Tablet', 'Desktop'],
                  selected: _device,
                  onChanged: (d) => setState(() => _device = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PreviewPane(key: ValueKey(_device), html: widget.html, device: _device),
          ),
        ],
      ),
    ),
  );
}
