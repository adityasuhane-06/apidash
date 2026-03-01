// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assertion_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssertionModel {

/// Unique identifier for the assertion
 String get id;/// Human-readable name/description
 String get name;/// Type of assertion (status code, header, body, etc.)
 AssertionType get type;/// Property path to validate (e.g., "body.user.id", "headers['Content-Type']", "statusCode")
 String get propertyPath;/// Comparison operator
 AssertionOperator get operator;/// Expected value to compare against
 dynamic get expectedValue;/// Whether this assertion is enabled
 bool get enabled;/// Optional description/notes
 String? get description;
/// Create a copy of AssertionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssertionModelCopyWith<AssertionModel> get copyWith => _$AssertionModelCopyWithImpl<AssertionModel>(this as AssertionModel, _$identity);

  /// Serializes this AssertionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssertionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.propertyPath, propertyPath) || other.propertyPath == propertyPath)&&(identical(other.operator, operator) || other.operator == operator)&&const DeepCollectionEquality().equals(other.expectedValue, expectedValue)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,propertyPath,operator,const DeepCollectionEquality().hash(expectedValue),enabled,description);

@override
String toString() {
  return 'AssertionModel(id: $id, name: $name, type: $type, propertyPath: $propertyPath, operator: $operator, expectedValue: $expectedValue, enabled: $enabled, description: $description)';
}


}

/// @nodoc
abstract mixin class $AssertionModelCopyWith<$Res>  {
  factory $AssertionModelCopyWith(AssertionModel value, $Res Function(AssertionModel) _then) = _$AssertionModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, AssertionType type, String propertyPath, AssertionOperator operator, dynamic expectedValue, bool enabled, String? description
});




}
/// @nodoc
class _$AssertionModelCopyWithImpl<$Res>
    implements $AssertionModelCopyWith<$Res> {
  _$AssertionModelCopyWithImpl(this._self, this._then);

  final AssertionModel _self;
  final $Res Function(AssertionModel) _then;

/// Create a copy of AssertionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? propertyPath = null,Object? operator = null,Object? expectedValue = freezed,Object? enabled = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AssertionType,propertyPath: null == propertyPath ? _self.propertyPath : propertyPath // ignore: cast_nullable_to_non_nullable
as String,operator: null == operator ? _self.operator : operator // ignore: cast_nullable_to_non_nullable
as AssertionOperator,expectedValue: freezed == expectedValue ? _self.expectedValue : expectedValue // ignore: cast_nullable_to_non_nullable
as dynamic,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AssertionModel].
extension AssertionModelPatterns on AssertionModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssertionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssertionModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssertionModel value)  $default,){
final _that = this;
switch (_that) {
case _AssertionModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssertionModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssertionModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  AssertionType type,  String propertyPath,  AssertionOperator operator,  dynamic expectedValue,  bool enabled,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssertionModel() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.propertyPath,_that.operator,_that.expectedValue,_that.enabled,_that.description);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  AssertionType type,  String propertyPath,  AssertionOperator operator,  dynamic expectedValue,  bool enabled,  String? description)  $default,) {final _that = this;
switch (_that) {
case _AssertionModel():
return $default(_that.id,_that.name,_that.type,_that.propertyPath,_that.operator,_that.expectedValue,_that.enabled,_that.description);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  AssertionType type,  String propertyPath,  AssertionOperator operator,  dynamic expectedValue,  bool enabled,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _AssertionModel() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.propertyPath,_that.operator,_that.expectedValue,_that.enabled,_that.description);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _AssertionModel extends AssertionModel {
  const _AssertionModel({required this.id, required this.name, required this.type, required this.propertyPath, required this.operator, required this.expectedValue, this.enabled = true, this.description}): super._();
  factory _AssertionModel.fromJson(Map<String, dynamic> json) => _$AssertionModelFromJson(json);

/// Unique identifier for the assertion
@override final  String id;
/// Human-readable name/description
@override final  String name;
/// Type of assertion (status code, header, body, etc.)
@override final  AssertionType type;
/// Property path to validate (e.g., "body.user.id", "headers['Content-Type']", "statusCode")
@override final  String propertyPath;
/// Comparison operator
@override final  AssertionOperator operator;
/// Expected value to compare against
@override final  dynamic expectedValue;
/// Whether this assertion is enabled
@override@JsonKey() final  bool enabled;
/// Optional description/notes
@override final  String? description;

/// Create a copy of AssertionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssertionModelCopyWith<_AssertionModel> get copyWith => __$AssertionModelCopyWithImpl<_AssertionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssertionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssertionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.propertyPath, propertyPath) || other.propertyPath == propertyPath)&&(identical(other.operator, operator) || other.operator == operator)&&const DeepCollectionEquality().equals(other.expectedValue, expectedValue)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,propertyPath,operator,const DeepCollectionEquality().hash(expectedValue),enabled,description);

@override
String toString() {
  return 'AssertionModel(id: $id, name: $name, type: $type, propertyPath: $propertyPath, operator: $operator, expectedValue: $expectedValue, enabled: $enabled, description: $description)';
}


}

/// @nodoc
abstract mixin class _$AssertionModelCopyWith<$Res> implements $AssertionModelCopyWith<$Res> {
  factory _$AssertionModelCopyWith(_AssertionModel value, $Res Function(_AssertionModel) _then) = __$AssertionModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, AssertionType type, String propertyPath, AssertionOperator operator, dynamic expectedValue, bool enabled, String? description
});




}
/// @nodoc
class __$AssertionModelCopyWithImpl<$Res>
    implements _$AssertionModelCopyWith<$Res> {
  __$AssertionModelCopyWithImpl(this._self, this._then);

  final _AssertionModel _self;
  final $Res Function(_AssertionModel) _then;

/// Create a copy of AssertionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? propertyPath = null,Object? operator = null,Object? expectedValue = freezed,Object? enabled = null,Object? description = freezed,}) {
  return _then(_AssertionModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AssertionType,propertyPath: null == propertyPath ? _self.propertyPath : propertyPath // ignore: cast_nullable_to_non_nullable
as String,operator: null == operator ? _self.operator : operator // ignore: cast_nullable_to_non_nullable
as AssertionOperator,expectedValue: freezed == expectedValue ? _self.expectedValue : expectedValue // ignore: cast_nullable_to_non_nullable
as dynamic,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AssertionResult {

/// ID of the assertion that was executed
 String get assertionId;/// Whether the assertion passed
 bool get passed;/// Actual value that was found
 dynamic get actualValue;/// Expected value from the assertion
 dynamic get expectedValue;/// Error message if assertion failed
 String? get errorMessage;/// Timestamp when assertion was executed
 DateTime get executedAt;
/// Create a copy of AssertionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssertionResultCopyWith<AssertionResult> get copyWith => _$AssertionResultCopyWithImpl<AssertionResult>(this as AssertionResult, _$identity);

  /// Serializes this AssertionResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssertionResult&&(identical(other.assertionId, assertionId) || other.assertionId == assertionId)&&(identical(other.passed, passed) || other.passed == passed)&&const DeepCollectionEquality().equals(other.actualValue, actualValue)&&const DeepCollectionEquality().equals(other.expectedValue, expectedValue)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.executedAt, executedAt) || other.executedAt == executedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,assertionId,passed,const DeepCollectionEquality().hash(actualValue),const DeepCollectionEquality().hash(expectedValue),errorMessage,executedAt);

@override
String toString() {
  return 'AssertionResult(assertionId: $assertionId, passed: $passed, actualValue: $actualValue, expectedValue: $expectedValue, errorMessage: $errorMessage, executedAt: $executedAt)';
}


}

/// @nodoc
abstract mixin class $AssertionResultCopyWith<$Res>  {
  factory $AssertionResultCopyWith(AssertionResult value, $Res Function(AssertionResult) _then) = _$AssertionResultCopyWithImpl;
@useResult
$Res call({
 String assertionId, bool passed, dynamic actualValue, dynamic expectedValue, String? errorMessage, DateTime executedAt
});




}
/// @nodoc
class _$AssertionResultCopyWithImpl<$Res>
    implements $AssertionResultCopyWith<$Res> {
  _$AssertionResultCopyWithImpl(this._self, this._then);

  final AssertionResult _self;
  final $Res Function(AssertionResult) _then;

/// Create a copy of AssertionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assertionId = null,Object? passed = null,Object? actualValue = freezed,Object? expectedValue = freezed,Object? errorMessage = freezed,Object? executedAt = null,}) {
  return _then(_self.copyWith(
assertionId: null == assertionId ? _self.assertionId : assertionId // ignore: cast_nullable_to_non_nullable
as String,passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as bool,actualValue: freezed == actualValue ? _self.actualValue : actualValue // ignore: cast_nullable_to_non_nullable
as dynamic,expectedValue: freezed == expectedValue ? _self.expectedValue : expectedValue // ignore: cast_nullable_to_non_nullable
as dynamic,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,executedAt: null == executedAt ? _self.executedAt : executedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AssertionResult].
extension AssertionResultPatterns on AssertionResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssertionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssertionResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssertionResult value)  $default,){
final _that = this;
switch (_that) {
case _AssertionResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssertionResult value)?  $default,){
final _that = this;
switch (_that) {
case _AssertionResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String assertionId,  bool passed,  dynamic actualValue,  dynamic expectedValue,  String? errorMessage,  DateTime executedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssertionResult() when $default != null:
return $default(_that.assertionId,_that.passed,_that.actualValue,_that.expectedValue,_that.errorMessage,_that.executedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String assertionId,  bool passed,  dynamic actualValue,  dynamic expectedValue,  String? errorMessage,  DateTime executedAt)  $default,) {final _that = this;
switch (_that) {
case _AssertionResult():
return $default(_that.assertionId,_that.passed,_that.actualValue,_that.expectedValue,_that.errorMessage,_that.executedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String assertionId,  bool passed,  dynamic actualValue,  dynamic expectedValue,  String? errorMessage,  DateTime executedAt)?  $default,) {final _that = this;
switch (_that) {
case _AssertionResult() when $default != null:
return $default(_that.assertionId,_that.passed,_that.actualValue,_that.expectedValue,_that.errorMessage,_that.executedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _AssertionResult extends AssertionResult {
  const _AssertionResult({required this.assertionId, required this.passed, required this.actualValue, required this.expectedValue, this.errorMessage, required this.executedAt}): super._();
  factory _AssertionResult.fromJson(Map<String, dynamic> json) => _$AssertionResultFromJson(json);

/// ID of the assertion that was executed
@override final  String assertionId;
/// Whether the assertion passed
@override final  bool passed;
/// Actual value that was found
@override final  dynamic actualValue;
/// Expected value from the assertion
@override final  dynamic expectedValue;
/// Error message if assertion failed
@override final  String? errorMessage;
/// Timestamp when assertion was executed
@override final  DateTime executedAt;

/// Create a copy of AssertionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssertionResultCopyWith<_AssertionResult> get copyWith => __$AssertionResultCopyWithImpl<_AssertionResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssertionResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssertionResult&&(identical(other.assertionId, assertionId) || other.assertionId == assertionId)&&(identical(other.passed, passed) || other.passed == passed)&&const DeepCollectionEquality().equals(other.actualValue, actualValue)&&const DeepCollectionEquality().equals(other.expectedValue, expectedValue)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.executedAt, executedAt) || other.executedAt == executedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,assertionId,passed,const DeepCollectionEquality().hash(actualValue),const DeepCollectionEquality().hash(expectedValue),errorMessage,executedAt);

@override
String toString() {
  return 'AssertionResult(assertionId: $assertionId, passed: $passed, actualValue: $actualValue, expectedValue: $expectedValue, errorMessage: $errorMessage, executedAt: $executedAt)';
}


}

/// @nodoc
abstract mixin class _$AssertionResultCopyWith<$Res> implements $AssertionResultCopyWith<$Res> {
  factory _$AssertionResultCopyWith(_AssertionResult value, $Res Function(_AssertionResult) _then) = __$AssertionResultCopyWithImpl;
@override @useResult
$Res call({
 String assertionId, bool passed, dynamic actualValue, dynamic expectedValue, String? errorMessage, DateTime executedAt
});




}
/// @nodoc
class __$AssertionResultCopyWithImpl<$Res>
    implements _$AssertionResultCopyWith<$Res> {
  __$AssertionResultCopyWithImpl(this._self, this._then);

  final _AssertionResult _self;
  final $Res Function(_AssertionResult) _then;

/// Create a copy of AssertionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assertionId = null,Object? passed = null,Object? actualValue = freezed,Object? expectedValue = freezed,Object? errorMessage = freezed,Object? executedAt = null,}) {
  return _then(_AssertionResult(
assertionId: null == assertionId ? _self.assertionId : assertionId // ignore: cast_nullable_to_non_nullable
as String,passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as bool,actualValue: freezed == actualValue ? _self.actualValue : actualValue // ignore: cast_nullable_to_non_nullable
as dynamic,expectedValue: freezed == expectedValue ? _self.expectedValue : expectedValue // ignore: cast_nullable_to_non_nullable
as dynamic,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,executedAt: null == executedAt ? _self.executedAt : executedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
