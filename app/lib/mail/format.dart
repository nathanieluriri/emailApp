import 'package:intl/intl.dart';

String shortDate(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return DateFormat.Hm().format(d);
  if (d.year == now.year) return DateFormat('d MMM').format(d);
  return DateFormat('d/M/yy').format(d);
}

String longDate(DateTime d) => DateFormat('EEE, d MMM y, HH:mm').format(d);

String fileSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} KB'
    : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
