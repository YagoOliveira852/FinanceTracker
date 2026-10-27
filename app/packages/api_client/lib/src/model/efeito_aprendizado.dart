//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'efeito_aprendizado.g.dart';

/// O que a confirmação de uma categoria fez com as regras.
class EfeitoAprendizado extends EnumClass {

  @BuiltValueEnumConst(wireName: r'criada')
  static const EfeitoAprendizado criada = _$criada;
  @BuiltValueEnumConst(wireName: r'reforcada')
  static const EfeitoAprendizado reforcada = _$reforcada;
  @BuiltValueEnumConst(wireName: r'corrigida')
  static const EfeitoAprendizado corrigida = _$corrigida;
  @BuiltValueEnumConst(wireName: r'especializada')
  static const EfeitoAprendizado especializada = _$especializada;
  @BuiltValueEnumConst(wireName: r'manual_mantida')
  static const EfeitoAprendizado manualMantida = _$manualMantida;
  @BuiltValueEnumConst(wireName: r'nenhuma')
  static const EfeitoAprendizado nenhuma = _$nenhuma;

  static Serializer<EfeitoAprendizado> get serializer => _$efeitoAprendizadoSerializer;

  const EfeitoAprendizado._(String name): super(name);

  static BuiltSet<EfeitoAprendizado> get values => _$values;
  static EfeitoAprendizado valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class EfeitoAprendizadoMixin = Object with _$EfeitoAprendizadoMixin;

