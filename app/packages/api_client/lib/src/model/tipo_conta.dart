//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'tipo_conta.g.dart';

class TipoConta extends EnumClass {

  @BuiltValueEnumConst(wireName: r'corrente')
  static const TipoConta corrente = _$corrente;
  @BuiltValueEnumConst(wireName: r'cartao_credito')
  static const TipoConta cartaoCredito = _$cartaoCredito;
  @BuiltValueEnumConst(wireName: r'carteira')
  static const TipoConta carteira = _$carteira;

  static Serializer<TipoConta> get serializer => _$tipoContaSerializer;

  const TipoConta._(String name): super(name);

  static BuiltSet<TipoConta> get values => _$values;
  static TipoConta valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class TipoContaMixin = Object with _$TipoContaMixin;

