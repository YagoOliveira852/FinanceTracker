//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'origem_regra.g.dart';

class OrigemRegra extends EnumClass {

  @BuiltValueEnumConst(wireName: r'manual')
  static const OrigemRegra manual = _$manual;
  @BuiltValueEnumConst(wireName: r'aprendida')
  static const OrigemRegra aprendida = _$aprendida;

  static Serializer<OrigemRegra> get serializer => _$origemRegraSerializer;

  const OrigemRegra._(String name): super(name);

  static BuiltSet<OrigemRegra> get values => _$values;
  static OrigemRegra valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class OrigemRegraMixin = Object with _$OrigemRegraMixin;

