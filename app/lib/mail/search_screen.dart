import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/motion.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import 'mail_providers.dart';
import 'mail_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_query));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Hero(
                tag: 'search',
                child: Material(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(26),
                  child: Row(
                    children: [
                      IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
                      Expanded(
                        child: TextField(
                          controller: _field,
                          autofocus: true,
                          onChanged: _changed,
                          onSubmitted: (v) => setState(() => _query = v.trim()),
                          textInputAction: TextInputAction.search,
                          style: AppText.search.copyWith(color: AppColors.ink),
                          decoration: const InputDecoration(hintText: 'Search in emails', fillColor: Colors.transparent),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconPress(
                          icon: LucideIcons.x,
                          label: 'Clear',
                          onTap: () {
                            _field.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.search,
                      title: 'Search your mail',
                      body: 'Sender, subject or any word in the message.',
                    )
                  : switch (results) {
                      AsyncValue(value: final list?) when list.isEmpty => const EmptyState(
                        icon: LucideIcons.searchX,
                        title: 'No matches',
                        body: 'Try a shorter word or another spelling.',
                      ),
                      AsyncValue(value: final list?) => ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => EntryMotion(
                          key: ValueKey(list[i].id),
                          index: i,
                          child: MailRow(
                            message: list[i],
                            onTap: () => context.push('/thread/${list[i].threadId}?hero=${list[i].id}'),
                            onStar: () => ref.read(inboxProvider('inbox').notifier).toggleStar(list[i]).catchError((_) {}),
                          ),
                        ),
                      ),
                      AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(searchProvider(_query))),
                      _ => const Loader(),
                    },
            ),
          ],
        ),
      ),
    );
  }
}
