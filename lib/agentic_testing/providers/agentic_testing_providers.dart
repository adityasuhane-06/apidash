import 'package:apidash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/contract_context.dart';
import '../models/workflow_context.dart';
import '../mcp/adapter.dart';
import '../services/healing_planner.dart';
import '../services/state_machine.dart';
import '../services/test_contract_normalizer.dart';
import '../services/test_executor.dart';
import '../services/test_generator.dart';
import '../services/workflow_checkpoint_storage.dart';

final agenticTestGeneratorProvider = Provider<AgenticTestGenerator>((ref) {
  return AgenticTestGenerator(
    readDefaultModel: () => ref.read(settingsProvider).defaultAIModel,
  );
});

final agenticTestExecutorProvider = Provider<AgenticTestExecutor>((ref) {
  return AgenticTestExecutor();
});

final agenticTestContractNormalizerProvider =
    Provider<AgenticTestContractNormalizer>((ref) {
      return const AgenticTestContractNormalizer();
    });

final agenticSelectedRequestContractContextProvider =
    Provider<AgenticContractContext?>((ref) {
      final selectedRequest = ref.watch(selectedRequestModelProvider);
      final requestModel = selectedRequest?.httpRequestModel;
      if (requestModel == null || requestModel.url.trim().isEmpty) {
        return null;
      }
      return ref
          .read(agenticTestContractNormalizerProvider)
          .normalizeFromRequest(
            requestModel: requestModel,
            responseModel: selectedRequest?.httpResponseModel,
          );
    });

final agenticTestHealingPlannerProvider = Provider<AgenticTestHealingPlanner>((
  ref,
) {
  return const AgenticTestHealingPlanner();
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
        healingPlanner: ref.read(agenticTestHealingPlannerProvider),
        checkpointStorage: ref.read(agenticWorkflowCheckpointStorageProvider),
      );
    });

final agenticTestingMcpAdapterProvider = Provider<AgenticTestingMcpAdapter>((
  ref,
) {
  return AgenticTestingMcpAdapterImpl(
    testGenerator: ref.read(agenticTestGeneratorProvider),
    testExecutor: ref.read(agenticTestExecutorProvider),
    healingPlanner: ref.read(agenticTestHealingPlannerProvider),
  );
});
