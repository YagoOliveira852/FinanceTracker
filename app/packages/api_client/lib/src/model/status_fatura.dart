//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'status_fatura.g.dart';

class StatusFatura extends EnumClass {

  @BuiltValueEnumConst(wireName: r'aberta')
  static const StatusFatura aberta = _$aberta;
  @BuiltValueEnumConst(wireName: r'fechada')
  static const StatusFatura fechada = _$fechada;

  static Serializer<StatusFatura> get serializer => _$statusFaturaSerializer;

  const StatusFatura._(String name): super(name);

  static BuiltSet<StatusFatura> get values => _$values;
  static StatusFatura valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class StatusFaturaMixin = Object with _$StatusFaturaMixin;

