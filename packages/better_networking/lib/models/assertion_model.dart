import 'package:freezed_annotation/freezed_annotation.dart';

part 'assertion_model.freezed.dart';
part 'assertion_model.g.dart';

/// Types of assertions that can be performed on API responses
enum AssertionType {
  statusCode,
  header,
  body,
  responseTime,
  cookie,
}

/// Operators for comparing actual vs expected values
enum AssertionOperator {
  equals,
  notEquals,
  contains,
  notContains,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  exists,
  notExists,
  isEmpty,
  isNotEmpty,
  matches, // regex
  typeOf, // check data type
  hasProperty,
}

/// Model representing a single assertion on an API response
@freezed
abstract class AssertionModel with _$AssertionModel {
  const AssertionModel._();

  @JsonSerializable(explicitToJson: true)
  const factory AssertionModel({
    /// Unique identifier for the assertion
    required String id,
    
    /// Human-readable name/description
    required String name,
    
    /// Type of assertion (status code, header, body, etc.)
    required AssertionType type,
    
    /// Property path to validate (e.g., "body.user.id", "headers['Content-Type']", "statusCode")
    required String propertyPath,
    
    /// Comparison operator
    required AssertionOperator operator,
    
    /// Expected value to compare against
    required dynamic expectedValue,
    
    /// Whether this assertion is enabled
    @Default(true) bool enabled,
    
    /// Optional description/notes
    String? description,
  }) = _AssertionModel;

  factory AssertionModel.fromJson(Map<String, Object?> json) =>
      _$AssertionModelFromJson(json);
}

/// Result of executing an assertion
@freezed
abstract class AssertionResult with _$AssertionResult {
  const AssertionResult._();

  @JsonSerializable(explicitToJson: true)
  const factory AssertionResult({
    /// ID of the assertion that was executed
    required String assertionId,
    
    /// Whether the assertion passed
    required bool passed,
    
    /// Actual value that was found
    required dynamic actualValue,
    
    /// Expected value from the assertion
    required dynamic expectedValue,
    
    /// Error message if assertion failed
    String? errorMessage,
    
    /// Timestamp when assertion was executed
    required DateTime executedAt,
  }) = _AssertionResult;

  factory AssertionResult.fromJson(Map<String, Object?> json) =>
      _$AssertionResultFromJson(json);
}
