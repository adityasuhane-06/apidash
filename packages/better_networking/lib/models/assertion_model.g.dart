// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assertion_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AssertionModel _$AssertionModelFromJson(Map<String, dynamic> json) =>
    _AssertionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$AssertionTypeEnumMap, json['type']),
      propertyPath: json['propertyPath'] as String,
      operator: $enumDecode(_$AssertionOperatorEnumMap, json['operator']),
      expectedValue: json['expectedValue'],
      enabled: json['enabled'] as bool? ?? true,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$AssertionModelToJson(_AssertionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$AssertionTypeEnumMap[instance.type]!,
      'propertyPath': instance.propertyPath,
      'operator': _$AssertionOperatorEnumMap[instance.operator]!,
      'expectedValue': instance.expectedValue,
      'enabled': instance.enabled,
      'description': instance.description,
    };

const _$AssertionTypeEnumMap = {
  AssertionType.statusCode: 'statusCode',
  AssertionType.header: 'header',
  AssertionType.body: 'body',
  AssertionType.responseTime: 'responseTime',
  AssertionType.cookie: 'cookie',
};

const _$AssertionOperatorEnumMap = {
  AssertionOperator.equals: 'equals',
  AssertionOperator.notEquals: 'notEquals',
  AssertionOperator.contains: 'contains',
  AssertionOperator.notContains: 'notContains',
  AssertionOperator.greaterThan: 'greaterThan',
  AssertionOperator.lessThan: 'lessThan',
  AssertionOperator.greaterThanOrEqual: 'greaterThanOrEqual',
  AssertionOperator.lessThanOrEqual: 'lessThanOrEqual',
  AssertionOperator.exists: 'exists',
  AssertionOperator.notExists: 'notExists',
  AssertionOperator.isEmpty: 'isEmpty',
  AssertionOperator.isNotEmpty: 'isNotEmpty',
  AssertionOperator.matches: 'matches',
  AssertionOperator.typeOf: 'typeOf',
  AssertionOperator.hasProperty: 'hasProperty',
};

_AssertionResult _$AssertionResultFromJson(Map<String, dynamic> json) =>
    _AssertionResult(
      assertionId: json['assertionId'] as String,
      passed: json['passed'] as bool,
      actualValue: json['actualValue'],
      expectedValue: json['expectedValue'],
      errorMessage: json['errorMessage'] as String?,
      executedAt: DateTime.parse(json['executedAt'] as String),
    );

Map<String, dynamic> _$AssertionResultToJson(_AssertionResult instance) =>
    <String, dynamic>{
      'assertionId': instance.assertionId,
      'passed': instance.passed,
      'actualValue': instance.actualValue,
      'expectedValue': instance.expectedValue,
      'errorMessage': instance.errorMessage,
      'executedAt': instance.executedAt.toIso8601String(),
    };
