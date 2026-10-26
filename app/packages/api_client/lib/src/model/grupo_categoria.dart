//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'grupo_categoria.g.dart';

class GrupoCategoria extends EnumClass {

  @BuiltValueEnumConst(wireName: r'essencial')
  static const GrupoCategoria essencial = _$essencial;
  @BuiltValueEnumConst(wireName: r'variavel')
  static const GrupoCategoria variavel = _$variavel;
  @BuiltValueEnumConst(wireName: r'renda')
  static const GrupoCategoria renda = _$renda;
  @BuiltValueEnumConst(wireName: r'investimento')
  static const GrupoCategoria investimento = _$investimento;

  static Serializer<GrupoCategoria> get serializer => _$grupoCategoriaSerializer;

  const GrupoCategoria._(String name): super(name);

  static BuiltSet<GrupoCategoria> get values => _$values;
  static GrupoCategoria valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class GrupoCategoriaMixin = Object with _$GrupoCategoriaMixin;

