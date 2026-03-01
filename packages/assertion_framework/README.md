# Assertion Framework

A standalone assertion framework for API testing, designed for use with AI agents in the GSoC 2026 Idea #4: Agentic API Testing project.

## Features

- **Status Code Assertions**: Validate HTTP response status codes
- **Response Time Assertions**: Check API performance with time-based assertions
- **JSON Body Assertions**: Deep JSON path navigation with support for nested objects and arrays
- **Header Assertions**: Validate response headers
- **Text Body Assertions**: Check raw response body content
- **Rich Operators**: equals, notEquals, contains, notContains, greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual, exists, notExists
- **Batch Execution**: Run multiple assertions against a single response
- **Error Handling**: Comprehensive error messages for debugging

## Usage

```dart
import 'package:assertion_framework/assertion_framework.dart';

// Create a response
final response = HttpResponse(
  statusCode: 200,
  body: '{"user": {"id": 123, "name": "John"}}',
  responseTime: Duration(milliseconds: 300),
  headers: {'content-type': 'application/json'},
);

// Create assertions
final assertions = [
  Assertion(
    id: '1',
    name: 'Status is 200',
    type: AssertionType.statusCode,
    path: 'statusCode',
    operator: AssertionOperator.equals,
    expectedValue: 200,
  ),
  Assertion(
    id: '2',
    name: 'User ID is 123',
    type: AssertionType.bodyJson,
    path: 'user.id',
    operator: AssertionOperator.equals,
    expectedValue: 123,
  ),
  Assertion(
    id: '3',
    name: 'Response under 500ms',
    type: AssertionType.responseTime,
    path: 'responseTime',
    operator: AssertionOperator.lessThan,
    expectedValue: 500,
  ),
];

// Execute assertions
final results = AssertionEngine.executeAll(assertions, response);

// Check results
for (final result in results) {
  print('${result.passed ? "✓" : "✗"} ${result.assertionId}');
  if (!result.passed) {
    print('  Error: ${result.errorMessage}');
  }
}
```

## JSON Path Support

The framework supports complex JSON path navigation:

- Simple properties: `user.name`
- Nested objects: `user.address.city`
- Array indexing: `items[0].price`
- Combined: `users[0].orders[1].total`

## Why Standalone?

This package is independent of the main API Dash codebase to:
- Avoid dependency on broken `better_networking` package
- Provide clean, reusable foundation for AI agents
- Enable easy testing and iteration
- Support future integration with MCP tools

## Testing

Run tests:
```bash
cd packages/assertion_framework
flutter test
```

## Integration with API Dash

This framework will be integrated into API Dash's agentic testing system, where AI agents will:
1. Generate assertions based on API specifications
2. Execute assertions against responses
3. Analyze results and suggest improvements
4. Learn from patterns to improve future assertions

## License

Part of the API Dash project.
