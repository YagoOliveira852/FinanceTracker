//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fonte_transacao.g.dart';

class FonteTransacao extends EnumClass {

  @BuiltValueEnumConst(wireName: r'manual')
  static const FonteTransacao manual = _$manual;
  @BuiltValueEnumConst(wireName: r'ofx')
  static const FonteTransacao ofx = _$ofx;
  @BuiltValueEnumConst(wireName: r'csv_mercadopago')
  static const FonteTransacao csvMercadopago = _$csvMercadopago;
  @BuiltValueEnumConst(wireName: r'pluggy')
  static const FonteTransacao pluggy = _$pluggy;

  static Serializer<FonteTransacao> get serializer => _$fonteTransacaoSerializer;

  const FonteTransacao._(String name): super(name);

  static BuiltSet<FonteTransacao> get values => _$values;
  static FonteTransacao valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class FonteTransacaoMixin = Object with _$FonteTransacaoMixin;

