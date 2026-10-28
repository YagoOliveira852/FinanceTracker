//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/erro_campo.dart';
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/linha_repetida_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'erro_importacao.g.dart';

/// O formato único de erro; no FITID repetido, também as linhas repetidas.
///
/// Properties:
/// * [detail] 
/// * [campos] 
/// * [linhasRepetidas] 
@BuiltValue()
abstract class ErroImportacao implements Built<ErroImportacao, ErroImportacaoBuilder> {
  @BuiltValueField(wireName: r'detail')
  String get detail;

  @BuiltValueField(wireName: r'campos')
  BuiltList<ErroCampo>? get campos;

  @BuiltValueField(wireName: r'linhas_repetidas')
  BuiltList<LinhaRepetidaSaida>? get linhasRepetidas;

  ErroImportacao._();

  factory ErroImportacao([void updates(ErroImportacaoBuilder b)]) = _$ErroImportacao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ErroImportacaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ErroImportacao> get serializer => _$ErroImportacaoSerializer();
}

class _$ErroImportacaoSerializer implements PrimitiveSerializer<ErroImportacao> {
  @override
  final Iterable<Type> types = const [ErroImportacao, _$ErroImportacao];

  @override
  final String wireName = r'ErroImportacao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ErroImportacao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'detail';
    yield serializers.serialize(
      object.detail,
      specifiedType: const FullType(String),
    );
    if (object.campos != null) {
      yield r'campos';
      yield serializers.serialize(
        object.campos,
        specifiedType: const FullType.nullable(BuiltList, [FullType(ErroCampo)]),
      );
    }
    if (object.linhasRepetidas != null) {
      yield r'linhas_repetidas';
      yield serializers.serialize(
        object.linhasRepetidas,
        specifiedType: const FullType.nullable(BuiltList, [FullType(LinhaRepetidaSaida)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ErroImportacao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ErroImportacaoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'detail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.detail = valueDes;
          break;
        case r'campos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(ErroCampo)]),
          ) as BuiltList<ErroCampo>?;
          if (valueDes == null) continue;
          result.campos.replace(valueDes);
          break;
        case r'linhas_repetidas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(LinhaRepetidaSaida)]),
          ) as BuiltList<LinhaRepetidaSaida>?;
          if (valueDes == null) continue;
          result.linhasRepetidas.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ErroImportacao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ErroImportacaoBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


