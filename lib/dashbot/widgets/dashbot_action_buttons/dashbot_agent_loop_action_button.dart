import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../dashbot_action.dart';

class DashbotAgentLoopActionButton extends ConsumerWidget
    with DashbotActionMixin {
  const DashbotAgentLoopActionButton({super.key, required this.action});

  @override
  final ChatAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGenerating = ref.watch(
      chatViewmodelProvider.select((state) => state.isGenerating),
    );

    return FilledButton.icon(
      onPressed: isGenerating
          ? null
          : () async {
              await ref
                  .read(chatViewmodelProvider.notifier)
                  .applyAgentLoopAction(action);
            },
      icon: Icon(_iconFor(action.actionType), size: 16),
      label: Text(_labelFor(action.actionType)),
    );
  }

  IconData _iconFor(ChatActionType type) {
    switch (type) {
      case ChatActionType.proposePlan:
        return Icons.route_outlined;
      case ChatActionType.approvePlan:
        return Icons.check_circle_outline;
      case ChatActionType.rejectPlan:
        return Icons.cancel_outlined;
      case ChatActionType.skipStep:
        return Icons.fast_forward_outlined;
      case ChatActionType.executeStep:
        return Icons.play_arrow_outlined;
      case ChatActionType.confirmSatisfaction:
        return Icons.thumb_up_alt_outlined;
      case ChatActionType.requestChanges:
        return Icons.edit_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  String _labelFor(ChatActionType type) {
    switch (type) {
      case ChatActionType.proposePlan:
        return 'Use Proposed Plan';
      case ChatActionType.approvePlan:
        return 'Approve Plan';
      case ChatActionType.rejectPlan:
        return 'Reject Plan';
      case ChatActionType.skipStep:
        return 'Skip Step';
      case ChatActionType.executeStep:
        return 'Execute Next Step';
      case ChatActionType.confirmSatisfaction:
        return 'Yes, Solved';
      case ChatActionType.requestChanges:
        return 'Need Changes';
      default:
        return 'Continue';
    }
  }
}
