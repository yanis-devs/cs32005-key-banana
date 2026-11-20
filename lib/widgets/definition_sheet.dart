import 'package:flutter/material.dart';

import '../services/definition_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that fetches and shows a word's definition.
///
/// Shows a loading state while the lookup runs, then the definition, a
/// "not found" message, or an error with a "Try again" button.
class DefinitionSheet extends StatefulWidget {
  const DefinitionSheet({super.key, required this.word});

  /// The word to look up.
  final String word;

  @override
  State<DefinitionSheet> createState() => _DefinitionSheetState();
}

class _DefinitionSheetState extends State<DefinitionSheet> {
  /// The lookup in progress or finished. Replaced by [_retry] to try again.
  late Future<DefinitionResult> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchDefinition(widget.word);
  }

  /// Runs the lookup again, e.g. after the connection came back.
  void _retry() => setState(() => _future = fetchDefinition(widget.word));

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(widget.word, style: textTheme.headlineMedium),
              ),
              const SizedBox(height: 12),
              FutureBuilder<DefinitionResult>(
                future: _future,
                builder: (context, snapshot) {
                  // No data yet means the lookup is still running.
                  final result = snapshot.data;
                  if (result == null) return _loading();
                  return _content(context, result);
                },
              ),
              const SizedBox(height: 20),
              // Credit for the data source.
              Text(
                'Definitions from dictionaryapi.dev',
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Spinner and "Looking up…" text, announced to screen readers as a live
  /// region.
  Widget _loading() {
    return Semantics(
      liveRegion: true,
      label: 'Looking up the definition',
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 12),
          Text('Looking up…'),
        ],
      ),
    );
  }

  /// The body of the sheet for a finished lookup: the definition, a "not
  /// found" message, or an error with a retry button.
  Widget _content(BuildContext context, DefinitionResult result) {
    final textTheme = Theme.of(context).textTheme;
    switch (result.status) {
      case DefinitionStatus.found:
        final partOfSpeech = result.partOfSpeech ?? '';
        final example = result.example;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The word-type pill is skipped when the API gave none.
            if (partOfSpeech.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellowSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Text(
                  partOfSpeech,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(),
            Text(result.definition ?? '', style: textTheme.bodyLarge),
            if (example != null) ...[
              const SizedBox(height: 12),
              Text(
                '"$example"',
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ],
        );
      case DefinitionStatus.notFound:
        return const Text('No definition found for this word.');
      case DefinitionStatus.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Couldn't load the definition. "
              'Check your connection and try again.',
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _retry, child: const Text('Try again')),
          ],
        );
    }
  }
}
