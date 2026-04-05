import 'package:apidash/agentic_testing/models/workflow_context.dart';
import 'package:apidash/agentic_testing/models/workflow_state.dart';
import 'package:apidash/agentic_testing/services/workflow_checkpoint_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AgenticWorkflowContext checkpointFor(String endpoint) {
    return AgenticWorkflowContext(
      workflowState: AgenticWorkflowState.awaitingApproval,
      endpoint: endpoint,
      requestMethod: 'GET',
    );
  }

  group('AgenticWorkflowCheckpointStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores checkpoints isolated per session key', () async {
      final storage = AgenticWorkflowCheckpointStorage();
      await storage.saveForSession(
        sessionKey: 'req-a',
        context: checkpointFor('https://api.apidash.dev/a'),
      );
      await storage.saveForSession(
        sessionKey: 'req-b',
        context: checkpointFor('https://api.apidash.dev/b'),
      );

      final a = await storage.loadForSession(sessionKey: 'req-a');
      final b = await storage.loadForSession(sessionKey: 'req-b');

      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.endpoint, 'https://api.apidash.dev/a');
      expect(b!.endpoint, 'https://api.apidash.dev/b');
    });

    test('loadForSession migrates legacy global checkpoint once', () async {
      final storage = AgenticWorkflowCheckpointStorage();
      await storage.save(checkpointFor('https://api.apidash.dev/legacy'));

      final migrated = await storage.loadForSession(sessionKey: 'req-legacy');
      expect(migrated, isNotNull);
      expect(migrated!.endpoint, 'https://api.apidash.dev/legacy');

      final legacyAfter = await storage.load();
      expect(legacyAfter, isNull);

      final migratedAgain = await storage.loadForSession(
        sessionKey: 'req-legacy',
      );
      expect(migratedAgain, isNotNull);
      expect(migratedAgain!.endpoint, 'https://api.apidash.dev/legacy');
    });

    test('clearForSession removes only requested session checkpoint', () async {
      final storage = AgenticWorkflowCheckpointStorage();
      await storage.saveForSession(
        sessionKey: 'req-a',
        context: checkpointFor('https://api.apidash.dev/a'),
      );
      await storage.saveForSession(
        sessionKey: 'req-b',
        context: checkpointFor('https://api.apidash.dev/b'),
      );

      await storage.clearForSession(sessionKey: 'req-a');

      final a = await storage.loadForSession(sessionKey: 'req-a');
      final b = await storage.loadForSession(sessionKey: 'req-b');
      expect(a, isNull);
      expect(b, isNotNull);
      expect(b!.endpoint, 'https://api.apidash.dev/b');
    });
  });
}
