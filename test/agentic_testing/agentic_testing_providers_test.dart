import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:apidash/agentic_testing/providers/agentic_testing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../providers/helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Agentic testing providers', () {
    late ProviderContainer container;

    setUp(() async {
      await testSetUpForHive();
      container = createContainer();
    });

    test('agenticTestingMcpAdapterProvider creates adapter instance', () {
      final adapter = container.read(agenticTestingMcpAdapterProvider);
      expect(adapter, isA<AgenticTestingMcpAdapter>());
    });

    test('agenticTestingMcpAdapterProvider is stable within container', () {
      final first = container.read(agenticTestingMcpAdapterProvider);
      final second = container.read(agenticTestingMcpAdapterProvider);
      expect(first, same(second));
    });
  });
}
