//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'manter_duplicata.g.dart';

/// Qual fica numa possível duplicata.
class ManterDuplicata extends EnumClass {

  @BuiltValueEnumConst(wireName: r'rascunho')
  static const ManterDuplicata rascunho = _$rascunho;
  @BuiltValueEnumConst(wireName: r'outra')
  static const ManterDuplicata outra = _$outra;
  @BuiltValueEnumConst(wireName: r'as_duas')
  static const ManterDuplicata asDuas = _$asDuas;

  static Serializer<ManterDuplicata> get serializer => _$manterDuplicataSerializer;

  const ManterDuplicata._(String name): super(name);

  static BuiltSet<ManterDuplicata> get values => _$values;
  static ManterDuplicata valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class ManterDuplicataMixin = Object with _$ManterDuplicataMixin;

