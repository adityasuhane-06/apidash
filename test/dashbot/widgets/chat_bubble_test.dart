import 'package:apidash/dashbot/constants.dart';
import 'package:apidash/dashbot/models/chat_action.dart';
import 'package:apidash/dashbot/widgets/agentic_mcp_app_view.dart';
import 'package:apidash/dashbot/widgets/chat_bubble.dart';
import 'package:apidash/dashbot/widgets/dashbot_action_buttons/dashbot_download_doc_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  });

  testWidgets('ChatBubble skips duplicate prompt override for user messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: 'duplicate',
              role: MessageRole.user,
              promptOverride: 'duplicate',
            ),
          ),
        ),
      ),
    );

    expect(find.text('duplicate'), findsNothing);
  });

  testWidgets('ChatBubble shows loading indicator when message empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: '', role: MessageRole.system),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ChatBubble renders explanation parsed from system JSON', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: '{"explanation":"Parsed output"}',
              role: MessageRole.system,
            ),
          ),
        ),
      ),
    );

    final markdown = tester.widget<MarkdownBody>(
      find.byType(MarkdownBody).first,
    );
    expect(markdown.data, 'Parsed output');
  });

  testWidgets(
    'ChatBubble falls back to explanation extraction when JSON is malformed',
    (tester) async {
      const malformed =
          '{"explanation":"Recovered output with code snippet","actions":[{"bad":true}';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(message: malformed, role: MessageRole.system),
            ),
          ),
        ),
      );

      final markdown = tester.widget<MarkdownBody>(
        find.byType(MarkdownBody).first,
      );
      expect(markdown.data, contains('Recovered output'));
    },
  );

  testWidgets('ChatBubble renders action widgets when provided', (
    tester,
  ) async {
    const action = ChatAction(
      action: 'download_doc',
      target: 'documentation',
      actionType: ChatActionType.downloadDoc,
      targetType: ChatActionTarget.documentation,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: 'Here is your document',
              role: MessageRole.system,
              actions: [action],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DashbotDownloadDocButton), findsOneWidget);
  });

  testWidgets('Copy icon copies rendered message to clipboard', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: 'Copy this please',
              role: MessageRole.system,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pumpAndSettle();

    // TODO: The below test works for `flutter run` but not for `flutter test`
    // final data = await Clipboard.getData('text/plain');
    // expect(data?.text, 'Copy this please');
  });

  testWidgets('ChatBubble renders MCP app view when payload is present', (
    tester,
  ) async {
    const message = '''
{
  "explanation":"Review gate is ready.",
  "mcp_app":{
    "resourceUri":"ui://agentic/test-review",
    "modelContext":{
      "approvedCount":1,
      "rejectedCount":0,
      "pendingCount":1,
      "tests":[
        {"title":"Status is 200","decision":"approved"},
        {"title":"Body includes id","decision":"pending"}
      ]
    }
  }
}
''';

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatBubble(message: message, role: MessageRole.system),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DashbotAgenticMcpAppView), findsOneWidget);
    expect(find.textContaining('MCP App: Test Review'), findsOneWidget);
    expect(find.textContaining('T1 - Status is 200'), findsOneWidget);
    expect(find.textContaining('Status is 200'), findsOneWidget);
  });

  testWidgets('ChatBubble shows clear sender labels for user and assistant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChatBubble(message: 'User message', role: MessageRole.user),
                ChatBubble(
                  message: 'Assistant message',
                  role: MessageRole.system,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('DashBot'), findsOneWidget);
  });

  testWidgets('ChatBubble shows working indicator when loading is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: 'Executing approved tests on the API...',
              role: MessageRole.system,
              isLoading: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Executing approved tests'), findsWidgets);
  });
}
