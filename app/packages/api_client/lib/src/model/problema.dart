//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'problema.g.dart';

class Problema extends EnumClass {

  @BuiltValueEnumConst(wireName: r'vencido')
  static const Problema vencido = _$vencido;
  @BuiltValueEnumConst(wireName: r'erro')
  static const Problema erro = _$erro;
  @BuiltValueEnumConst(wireName: r'sem_dados')
  static const Problema semDados = _$semDados;
  @BuiltValueEnumConst(wireName: r'vencendo')
  static const Problema vencendo = _$vencendo;

  static Serializer<Problema> get serializer => _$problemaSerializer;

  const Problema._(String name): super(name);

  static BuiltSet<Problema> get values => _$values;
  static Problema valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class ProblemaMixin = Object with _$ProblemaMixin;

