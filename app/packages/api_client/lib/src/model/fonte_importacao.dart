//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fonte_importacao.g.dart';

class FonteImportacao extends EnumClass {

  @BuiltValueEnumConst(wireName: r'ofx')
  static const FonteImportacao ofx = _$ofx;
  @BuiltValueEnumConst(wireName: r'csv_mercadopago')
  static const FonteImportacao csvMercadopago = _$csvMercadopago;
  @BuiltValueEnumConst(wireName: r'pluggy')
  static const FonteImportacao pluggy = _$pluggy;

  static Serializer<FonteImportacao> get serializer => _$fonteImportacaoSerializer;

  const FonteImportacao._(String name): super(name);

  static BuiltSet<FonteImportacao> get values => _$values;
  static FonteImportacao valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class FonteImportacaoMixin = Object with _$FonteImportacaoMixin;

