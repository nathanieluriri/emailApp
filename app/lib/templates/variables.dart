final _variable = RegExp(r'\{\{\s*(\w+)\s*\}\}');

List<String> findVariables(Iterable<String?> sources) => {
  for (final s in sources)
    if (s != null) ..._variable.allMatches(s).map((m) => m.group(1)!),
}.toList();

String fillVariables(String text, Map<String, String> values) => text.replaceAllMapped(_variable, (m) => values[m.group(1)] ?? m.group(0)!);
