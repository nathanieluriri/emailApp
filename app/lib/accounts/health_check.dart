import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api/api_client.dart';
import '../core/config.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';

class HealthItem {
  const HealthItem(this.label, this.ok, [this.fix]);
  final String label;
  final bool ok;
  final String? fix;
}

class HealthReport {
  const HealthReport(this.items, {this.error});
  final List<HealthItem> items;
  final String? error;

  bool get ok => error == null && items.every((i) => i.ok);
  List<HealthItem> get missing => items.where((i) => !i.ok).toList();
}

const _checkFixes = {
  'db': 'D1 database is not bound as DB or schema.sql was not applied',
  'r2': 'R2 bucket is not bound as FILES',
  'email': 'send_email binding EMAIL is missing',
  'onesignal': 'Secrets ONESIGNAL_APP_ID and ONESIGNAL_REST_KEY are not set on the worker',
};

Future<HealthReport> checkWorker(String url) async {
  try {
    final h = await ApiClient(url, null).health();
    final routes = ((h['routes'] as List?) ?? []).map((e) => '$e').toSet();
    final checks = Map<String, dynamic>.from(h['checks'] ?? {});
    return HealthReport([
      HealthItem('Service is ${AppConfig.serviceName}', h['service'] == AppConfig.serviceName, 'This worker reports "${h['service']}"'),
      for (final c in AppConfig.requiredChecks) HealthItem('Check: $c', checks[c] == true, _checkFixes[c]),
      for (final r in AppConfig.requiredRoutes) HealthItem(r, routes.contains(r), 'Route $r is not served'),
    ]);
  } catch (e) {
    return HealthReport(const [], error: 'Could not reach $url/health: ${ApiException.from(e)}');
  }
}

/// Each line ticks in on its own beat, so a long list reads as a check being run.
class HealthChecklist extends StatelessWidget {
  const HealthChecklist({super.key, required this.report});
  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    if (report.error != null) {
      return Text(report.error!, style: AppText.bodyTight.copyWith(color: AppColors.damage));
    }
    final ordered = [...report.missing, ...report.items.where((i) => i.ok)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in ordered.indexed)
          TweenAnimationBuilder<double>(
            key: ValueKey(item.label),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 220 + 35 * i.clamp(0, 30)),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(12 * (1 - t), 0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.ok ? LucideIcons.circleCheck : LucideIcons.circleX,
                    size: 18,
                    color: item.ok ? AppColors.accentBright : AppColors.damage,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: AppText.code.copyWith(color: AppColors.ink, fontSize: 12.5)),
                        if (!item.ok && item.fix != null) Text(item.fix!, style: AppText.docMeta.copyWith(color: AppColors.damage)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
