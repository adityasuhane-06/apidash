import 'package:apidash/dashbot/constants.dart';
import 'package:apidash/dashbot/models/chat_action.dart';
import 'package:apidash/dashbot/models/chat_state.dart';
import 'package:apidash/dashbot/providers/chat_viewmodel.dart';
import 'package:apidash/dashbot/widgets/dashbot_action_buttons/dashbot_agent_loop_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_consts.dart';
import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const action = ChatAction(
    action: 'execute_step',
    target: 'agentic_workflow',
    actionType: ChatActionType.executeStep,
    targetType: ChatActionTarget.agenticWorkflow,
  );

  group('DashbotAgentLoopActionButton', () {
    testWidgets('renders label and dispatches workflow action', (tester) async {
      late TestChatViewmodel notifier;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatViewmodelProvider.overrideWith((ref) {
              notifier = TestChatViewmodel(ref);
              return notifier;
            }),
          ],
          child: MaterialApp(
            theme: kThemeDataLight,
            home: const Scaffold(
              body: DashbotAgentLoopActionButton(action: action),
            ),
          ),
        ),
      );

      expect(find.text('Execute Next Step'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);

      await tester.tap(find.text('Execute Next Step'));
      await tester.pump();

      expect(notifier.applyAgentLoopActionCalls, hasLength(1));
      expect(notifier.applyAgentLoopActionCalls.single, same(action));
    });

    testWidgets('disables button while chat is generating', (tester) async {
      late TestChatViewmodel notifier;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatViewmodelProvider.overrideWith((ref) {
              notifier = TestChatViewmodel(ref);
              notifier.setState(const ChatState(isGenerating: true));
              return notifier;
            }),
          ],
          child: MaterialApp(
            theme: kThemeDataLight,
            home: const Scaffold(
              body: DashbotAgentLoopActionButton(action: action),
            ),
          ),
        ),
      );

      final button = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Execute Next Step'));
      await tester.pump();
      expect(notifier.applyAgentLoopActionCalls, isEmpty);
    });
  });
}
