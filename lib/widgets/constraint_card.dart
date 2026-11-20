import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The rule for the current round, e.g. "Word must start with C", on a pale
/// yellow card.
///
/// Lone capital letters (the letters the player must use or avoid) are drawn
/// in yellow boxes. This is purely visual: the round screen announces the
/// rule to screen readers itself and hides this widget from them, so nothing
/// is read twice.
class ConstraintCard extends StatelessWidget {
  const ConstraintCard({super.key, required this.text});

  /// The rule text, e.g. "Word must start with C".
  final String text;

  /// A single capital letter on its own. "Word" never matches because the
  /// "W" is followed by more letters.
  static final RegExp _letter = RegExp(r'\b[A-Z]\b');

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontSize: 30);

    return Container(
      width: double.infinity,
      // Keeps the card from jumping in height between one-line and
      // two-line rules.
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.yellowSoft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2648250F),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text.rich(
        TextSpan(children: _buildSpans(style)),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  /// Splits [text] into plain text and boxed letters, in their original order.
  List<InlineSpan> _buildSpans(TextStyle? style) {
    final spans = <InlineSpan>[];
    // Start of the text not yet added to [spans].
    var cursor = 0;

    for (final match in _letter.allMatches(text)) {
      // Plain text before this letter.
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _LetterBox(letter: match.group(0)!, style: style),
        ),
      );
      cursor = match.end;
    }

    // Any plain text after the last letter.
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

/// One highlighted letter. Fixed width so "I" and "M" get the same size box.
class _LetterBox extends StatelessWidget {
  const _LetterBox({required this.letter, required this.style});

  /// The single letter to display.
  final String letter;

  /// Text style matching the rest of the rule.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(letter, style: style),
    );
  }
}
