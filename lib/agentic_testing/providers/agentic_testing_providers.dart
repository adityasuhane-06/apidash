import 'package:apidash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/workflow_context.dart';
import '../services/state_machine.dart';
import '../services/test_executor.dart';
import '../services/test_generator.dart';
import '../services/workflow_checkpoint_storage.dart';

final agenticTestGeneratorProvider = Provider<AgenticTestGenerator>((ref) {
  return AgenticTestGenerator(
    readDefaultModel: () => ref.read(settingsProvider).defaultAIModel,
  );
});

final agenticTestExecutorProvider = Provider<AgenticTestExecutor>((ref) {
  return const AgenticTestExecutor();
});

final agenticWorkflowCheckpointStorageProvider =
    Provider<AgenticWorkflowCheckpointStorage>((ref) {
      return AgenticWorkflowCheckpointStorage();
    });

final agenticTestingStateMachineProvider =
    StateNotifierProvider<AgenticTestingStateMachine, AgenticWorkflowContext>((
      ref,
    ) {
      return AgenticTestingStateMachine(
        testGenerator: ref.read(agenticTestGeneratorProvider),
        testExecutor: ref.read(agenticTestExecutorProvider),
        checkpointStorage: ref.read(agenticWorkflowCheckpointStorageProvider),
      );
    });
