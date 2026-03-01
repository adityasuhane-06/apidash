import 'dart:convert';
import '../models/assertion_model.dart';
import '../models/http_response_model.dart';

/// Service for executing assertions against HTTP responses
class AssertionService {
  /// Execute a single assertion against an HTTP response
  static AssertionResult executeAssertion(
    AssertionModel assertion,
    HttpResponseModel response,
  ) {
    try {
      // Extract the actual value based on assertion type and property path
      final actualValue = _extractValue(assertion, response);
      
      // Perform the comparison based on the operator
      final passed = _compareValues(
        actualValue,
        assertion.expectedValue,
        assertion.operator,
      );
      
      return AssertionResult(
        assertionId: assertion.id,
        passed: passed,
        actualValue: actualValue,
        expectedValue: assertion.expectedValue,
        errorMessage: passed ? null : _generateErrorMessage(assertion, actualValue),
        executedAt: DateTime.now(),
      );
    } catch (e) {
      return AssertionResult(
        assertionId: assertion.id,
        passed: false,
        actualValue: null,
        expectedValue: assertion.expectedValue,
        errorMessage: 'Error executing assertion: $e',
        executedAt: DateTime.now(),
      );
    }
  }
  
  /// Execute multiple assertions against an HTTP response
  static List<AssertionResult> executeAssertions(
    List<AssertionModel> assertions,
    HttpResponseModel response,
  ) {
    return assertions
        .where((assertion) => assertion.enabled)
        .map((assertion) => executeAssertion(assertion, response))
        .toList();
  }
  
  /// Extract value from response based on assertion type and property path
  static dynamic _extractValue(
    AssertionModel assertion,
    HttpResponseModel response,
  ) {
    switch (assertion.type) {
      case AssertionType.statusCode:
        return response.statusCode;
        
      case AssertionType.header:
        // Property path format: "headers['Content-Type']" or just "Content-Type"
        final headerName = assertion.propertyPath
            .replaceAll("headers['", "")
            .replaceAll("']", "")
            .replaceAll('headers["', "")
            .replaceAll('"]', "");
        return response.headers?[headerName];
        
      case AssertionType.body:
        // Property path format: "body.user.id" or "body"
        if (assertion.propertyPath == 'body') {
          return response.body;
        }
        return _extractJsonPath(response.body, assertion.propertyPath);
        
      case AssertionType.responseTime:
        return response.time;
        
      case AssertionType.cookie:
        // Note: HttpResponseModel doesn't have cookies yet, return null for now
        // Property path format: "cookies['session']" or just "session"
        return null;
    }
  }
  
  /// Extract value from JSON using dot notation path
  /// Example: "body.user.profile.email" or "body.items[0].name"
  static dynamic _extractJsonPath(String? jsonString, String path) {
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    
    try {
      dynamic data = jsonDecode(jsonString);
      
      // Remove "body." prefix if present
      String cleanPath = path.startsWith('body.') ? path.substring(5) : path;
      
      // Split path by dots and process each segment
      final segments = cleanPath.split('.');
      
      for (final segment in segments) {
        if (data == null) return null;
        
        // Handle array index: items[0]
        if (segment.contains('[') && segment.contains(']')) {
          final arrayName = segment.substring(0, segment.indexOf('['));
          final indexStr = segment.substring(
            segment.indexOf('[') + 1,
            segment.indexOf(']'),
          );
          
          if (arrayName.isNotEmpty) {
            data = data[arrayName];
          }
          
          if (data is List) {
            final index = int.tryParse(indexStr);
            if (index != null && index < data.length) {
              data = data[index];
            } else {
              return null;
            }
          }
        } else {
          // Regular property access
          if (data is Map) {
            data = data[segment];
          } else {
            return null;
          }
        }
      }
      
      return data;
    } catch (e) {
      return null;
    }
  }
  
  /// Compare actual value with expected value using the specified operator
  static bool _compareValues(
    dynamic actual,
    dynamic expected,
    AssertionOperator operator,
  ) {
    switch (operator) {
      case AssertionOperator.equals:
        return actual == expected;
        
      case AssertionOperator.notEquals:
        return actual != expected;
        
      case AssertionOperator.contains:
        if (actual is String && expected is String) {
          return actual.contains(expected);
        } else if (actual is List) {
          return actual.contains(expected);
        } else if (actual is Map && expected is String) {
          return actual.containsKey(expected);
        }
        return false;
        
      case AssertionOperator.notContains:
        return !_compareValues(actual, expected, AssertionOperator.contains);
        
      case AssertionOperator.greaterThan:
        if (actual is num && expected is num) {
          return actual > expected;
        }
        return false;
        
      case AssertionOperator.lessThan:
        if (actual is num && expected is num) {
          return actual < expected;
        }
        return false;
        
      case AssertionOperator.greaterThanOrEqual:
        if (actual is num && expected is num) {
          return actual >= expected;
        }
        return false;
        
      case AssertionOperator.lessThanOrEqual:
        if (actual is num && expected is num) {
          return actual <= expected;
        }
        return false;
        
      case AssertionOperator.exists:
        return actual != null;
        
      case AssertionOperator.notExists:
        return actual == null;
        
      case AssertionOperator.isEmpty:
        if (actual is String) return actual.isEmpty;
        if (actual is List) return actual.isEmpty;
        if (actual is Map) return actual.isEmpty;
        return actual == null;
        
      case AssertionOperator.isNotEmpty:
        return !_compareValues(actual, expected, AssertionOperator.isEmpty);
        
      case AssertionOperator.matches:
        if (actual is String && expected is String) {
          try {
            final regex = RegExp(expected);
            return regex.hasMatch(actual);
          } catch (e) {
            return false;
          }
        }
        return false;
        
      case AssertionOperator.typeOf:
        final actualType = _getTypeName(actual);
        return actualType == expected;
        
      case AssertionOperator.hasProperty:
        if (actual is Map && expected is String) {
          return actual.containsKey(expected);
        }
        return false;
    }
  }
  
  /// Get type name as string
  static String _getTypeName(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'string';
    if (value is int) return 'number';
    if (value is double) return 'number';
    if (value is bool) return 'boolean';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return value.runtimeType.toString();
  }
  
  /// Generate error message for failed assertion
  static String _generateErrorMessage(
    AssertionModel assertion,
    dynamic actualValue,
  ) {
    final operatorText = _operatorToText(assertion.operator);
    return 'Expected ${assertion.propertyPath} to $operatorText ${assertion.expectedValue}, '
        'but got $actualValue';
  }
  
  /// Convert operator enum to human-readable text
  static String _operatorToText(AssertionOperator operator) {
    switch (operator) {
      case AssertionOperator.equals:
        return 'equal';
      case AssertionOperator.notEquals:
        return 'not equal';
      case AssertionOperator.contains:
        return 'contain';
      case AssertionOperator.notContains:
        return 'not contain';
      case AssertionOperator.greaterThan:
        return 'be greater than';
      case AssertionOperator.lessThan:
        return 'be less than';
      case AssertionOperator.greaterThanOrEqual:
        return 'be greater than or equal to';
      case AssertionOperator.lessThanOrEqual:
        return 'be less than or equal to';
      case AssertionOperator.exists:
        return 'exist';
      case AssertionOperator.notExists:
        return 'not exist';
      case AssertionOperator.isEmpty:
        return 'be empty';
      case AssertionOperator.isNotEmpty:
        return 'not be empty';
      case AssertionOperator.matches:
        return 'match pattern';
      case AssertionOperator.typeOf:
        return 'be of type';
      case AssertionOperator.hasProperty:
        return 'have property';
    }
  }
}
