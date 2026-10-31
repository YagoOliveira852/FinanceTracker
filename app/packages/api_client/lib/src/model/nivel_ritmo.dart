//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'nivel_ritmo.g.dart';

class NivelRitmo extends EnumClass {

  @BuiltValueEnumConst(wireName: r'verde')
  static const NivelRitmo verde = _$verde;
  @BuiltValueEnumConst(wireName: r'amarelo')
  static const NivelRitmo amarelo = _$amarelo;
  @BuiltValueEnumConst(wireName: r'vermelho')
  static const NivelRitmo vermelho = _$vermelho;

  static Serializer<NivelRitmo> get serializer => _$nivelRitmoSerializer;

  const NivelRitmo._(String name): super(name);

  static BuiltSet<NivelRitmo> get values => _$values;
  static NivelRitmo valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class NivelRitmoMixin = Object with _$NivelRitmoMixin;

