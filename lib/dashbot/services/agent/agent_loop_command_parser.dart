import '../../models/models.dart';

abstract class AgentLoopCommandParser {
  AgentLoopTextIntent parse(String input);
}

class AgentLoopCommandParserImpl implements AgentLoopCommandParser {
  static const int _maxLooseNumericRef = 50;

  static final RegExp _decisionKeyword = RegExp(
    r'\b(approve|approved|reject|rejected|skip|skipped)\b',
  );
  static final RegExp _tRef = RegExp(r'\bt\s*(\d+)\b');
  static final RegExp _testRef = RegExp(r'\btest\s*(\d+)\b');
  static final RegExp _caseRef = RegExp(r'\bcase\s*(\d+)\b');
  static final RegExp _numericRef = RegExp(r'\b(\d{1,3})\b');

  static const Map<String, int> _wordNumbers = <String, int>{
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
  };

  @override
  AgentLoopTextIntent parse(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.none,
        rawInput: input,
      );
    }

    if (_looksLikePlanApprove(normalized)) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.approvePlan,
        rawInput: input,
        confidence: 0.98,
      );
    }
    if (_looksLikePlanReject(normalized)) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.rejectPlan,
        rawInput: input,
        confidence: 0.98,
      );
    }

    if (_looksLikeFailureQuestion(normalized)) {
      final refs = _extractReferences(normalized);
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.explainFailure,
        rawInput: input,
        references: refs,
        confidence: refs.isEmpty ? 0.8 : 0.95,
      );
    }
    if (_looksLikeHealingQuestion(normalized)) {
      final refs = _extractReferences(normalized);
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.explainHealing,
        rawInput: input,
        references: refs,
        confidence: refs.isEmpty ? 0.8 : 0.95,
      );
    }
    if (_looksLikeDetailsQuestion(normalized)) {
      final refs = _extractReferences(normalized);
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.explainTestDetails,
        rawInput: input,
        references: refs,
        confidence: 0.85,
      );
    }

    final decisions = _parseDecisionCommands(normalized);
    if (decisions.isNotEmpty) {
      final mentionsHealing = _mentionsHealing(normalized);
      return AgentLoopTextIntent(
        type: mentionsHealing
            ? AgentLoopTextIntentType.healingDecision
            : AgentLoopTextIntentType.reviewDecision,
        rawInput: input,
        decisions: decisions,
        references:
            decisions.expand((command) => command.references).toSet().toList()
              ..sort(),
        confidence: 0.9,
      );
    }

    if (_looksLikeSkipStep(normalized)) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.skipStep,
        rawInput: input,
        confidence: 0.92,
      );
    }
    if (_looksLikeExecute(normalized)) {
      final refs = _extractReferences(normalized);
      final only =
          normalized.contains(' only ') ||
          normalized.startsWith('only ') ||
          normalized.contains(' just ');
      if (only && refs.isNotEmpty) {
        return AgentLoopTextIntent(
          type: AgentLoopTextIntentType.executeOnlySelection,
          rawInput: input,
          references: refs,
          confidence: 0.92,
          requiresRiskConfirmation: true,
        );
      }
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.executeStep,
        rawInput: input,
        confidence: 0.9,
        requiresRiskConfirmation: true,
      );
    }

    if (_looksLikeRequestChanges(normalized)) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.requestChanges,
        rawInput: input,
        confidence: 0.85,
      );
    }
    if (_looksLikeSatisfactionYes(normalized)) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.confirmSatisfaction,
        rawInput: input,
        confidence: 0.85,
      );
    }
    if (_looksLikeProposePlan(normalized)) {
      return AgentLoopTextIntent(
        type: AgentLoopTextIntentType.proposePlan,
        rawInput: input,
        confidence: 0.8,
      );
    }

    return AgentLoopTextIntent(
      type: AgentLoopTextIntentType.none,
      rawInput: input,
    );
  }

  List<AgentLoopDecisionCommand> _parseDecisionCommands(String text) {
    final matches = _decisionKeyword.allMatches(text).toList();
    if (matches.isEmpty) {
      return const <AgentLoopDecisionCommand>[];
    }

    final commands = <AgentLoopDecisionCommand>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final nextStart = i + 1 < matches.length
          ? matches[i + 1].start
          : text.length;
      final segment = text.substring(match.start, nextStart).trim();
      final operation = _operationFromToken(match.group(1) ?? '');
      if (operation == null) {
        continue;
      }
      final refs = _extractReferences(segment);
      final applyToAll = _containsAll(segment);
      final only = _containsOnly(segment);

      if (refs.isEmpty && !applyToAll) {
        continue;
      }
      commands.add(
        AgentLoopDecisionCommand(
          operation: operation,
          references: refs,
          applyToAll: applyToAll,
          only: only,
        ),
      );
    }
    return commands;
  }

  AgentLoopDecisionOperation? _operationFromToken(String token) {
    final normalized = token.toLowerCase().trim();
    if (normalized.startsWith('approve')) {
      return AgentLoopDecisionOperation.approve;
    }
    if (normalized.startsWith('reject')) {
      return AgentLoopDecisionOperation.reject;
    }
    if (normalized.startsWith('skip')) {
      return AgentLoopDecisionOperation.skip;
    }
    return null;
  }

  List<int> _extractReferences(String text) {
    final refs = <int>{};

    void addMatches(RegExp regex) {
      for (final match in regex.allMatches(text)) {
        final raw = match.group(1);
        if (raw == null) {
          continue;
        }
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) {
          refs.add(parsed);
        }
      }
    }

    addMatches(_tRef);
    addMatches(_testRef);
    addMatches(_caseRef);

    if (_canUseLooseNumericReferences(text)) {
      for (final match in _numericRef.allMatches(text)) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0 && parsed <= _maxLooseNumericRef) {
          refs.add(parsed);
        }
      }
    }

    for (final entry in _wordNumbers.entries) {
      if (text.contains(RegExp('\\b${entry.key}\\b'))) {
        refs.add(entry.value);
      }
    }

    final out = refs.toList()..sort();
    return out;
  }

  bool _canUseLooseNumericReferences(String text) {
    final hasCommandSignal =
        _decisionKeyword.hasMatch(text) ||
        text.contains('execute') ||
        text.contains('run') ||
        text.contains('failed') ||
        text.contains('failure') ||
        text.contains('heal') ||
        text.contains('healing') ||
        text.contains('detail');
    if (!hasCommandSignal) {
      return false;
    }

    final hasLikelyNonReferenceNumbers =
        text.contains('status') ||
        text.contains('code') ||
        text.contains('http') ||
        text.contains('ms') ||
        text.contains('latency');
    return !hasLikelyNonReferenceNumbers;
  }

  bool _containsAll(String text) {
    final compact = text.trim();
    return compact.contains(' all ') ||
        compact.startsWith('all ') ||
        compact.endsWith(' all') ||
        text.contains(' every ') ||
        text.contains(' each ');
  }

  bool _containsOnly(String text) {
    final compact = text.trim();
    return compact.contains(' only ') ||
        compact.startsWith('only ') ||
        compact.endsWith(' only') ||
        text.contains(' just ');
  }

  bool _mentionsHealing(String text) {
    return text.contains('heal') ||
        text.contains('healing') ||
        text.contains('fix');
  }

  bool _looksLikePlanApprove(String text) {
    return (text.contains('approve') || text.contains('accept')) &&
        text.contains('plan');
  }

  bool _looksLikePlanReject(String text) {
    return (text.contains('reject') || text.contains('decline')) &&
        text.contains('plan');
  }

  bool _looksLikeFailureQuestion(String text) {
    final asksWhy = text.contains('why') || text.contains('reason');
    final aboutFailure = text.contains('fail') || text.contains('failed');
    return asksWhy && aboutFailure;
  }

  bool _looksLikeHealingQuestion(String text) {
    final asksHow =
        text.contains('how') ||
        text.contains('what') ||
        text.contains('suggest') ||
        text.contains('fix');
    final aboutHealing =
        text.contains('heal') ||
        text.contains('healing') ||
        text.contains('fix');
    return asksHow && aboutHealing;
  }

  bool _looksLikeDetailsQuestion(String text) {
    return text.contains('detail') ||
        text.contains('all test case') ||
        text.contains('full report');
  }

  bool _looksLikeSkipStep(String text) {
    return text.contains('skip step') || text.contains('skip this step');
  }

  bool _looksLikeExecute(String text) {
    return text.contains('execute') ||
        text.contains('run next') ||
        text.contains('run step') ||
        text.contains('rerun') ||
        text.contains('re run') ||
        text.contains('re-run');
  }

  bool _looksLikeSatisfactionYes(String text) {
    final compact = text.trim();
    if (compact == 'no' ||
        compact.startsWith('no ') ||
        compact.contains('not solved') ||
        compact.contains('not satisfied') ||
        compact.contains("isn't solved") ||
        compact.contains("isnt solved")) {
      return false;
    }
    return compact == 'yes' ||
        compact == 'yes solved' ||
        compact.contains('solved') ||
        compact.contains('satisfied') ||
        compact.contains('looks good');
  }

  bool _looksLikeRequestChanges(String text) {
    final compact = text.trim();
    final explicitChange =
        compact.contains('need change') ||
        compact.contains('need changes') ||
        compact.contains('not solved') ||
        compact.startsWith('no ') ||
        compact == 'no';
    if (explicitChange) {
      return true;
    }

    final asksToModifyTests =
        (compact.contains('add ') ||
            compact.contains('create ') ||
            compact.contains('generate ') ||
            compact.contains('regenerate ') ||
            compact.contains('update ') ||
            compact.contains('modify ')) &&
        (compact.contains(' test') ||
            compact.contains('assertion') ||
            compact.contains(' case'));
    return asksToModifyTests;
  }

  bool _looksLikeProposePlan(String text) {
    return text.contains('make plan') ||
        text.contains('create plan') ||
        text.contains('propose plan');
  }

  String _normalize(String input) {
    final lowered = input.toLowerCase().trim();
    if (lowered.isEmpty) {
      return '';
    }
    return ' ${lowered.replaceAll(RegExp(r'\s+'), ' ')} ';
  }
}
