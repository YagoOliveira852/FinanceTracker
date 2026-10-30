//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/feriado_saida.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'proxima_data_saida.g.dart';

/// Próxima data esperada de uma renda, a partir de hoje (inclusive).
///
/// Properties:
/// * [data] - A data efetiva, já em dia útil.
/// * [dataPrevista] - O dia da renda no mês; 29 a 31 em mês mais curto vira o último dia.
/// * [feriados] - Feriados da data prevista até a efetiva (exclusive); vazia se só o fim de semana pesou ou se a data não mudou.
@BuiltValue()
abstract class ProximaDataSaida implements Built<ProximaDataSaida, ProximaDataSaidaBuilder> {
  /// A data efetiva, já em dia útil.
  @BuiltValueField(wireName: r'data')
  Date get data;

  /// O dia da renda no mês; 29 a 31 em mês mais curto vira o último dia.
  @BuiltValueField(wireName: r'data_prevista')
  Date get dataPrevista;

  /// Feriados da data prevista até a efetiva (exclusive); vazia se só o fim de semana pesou ou se a data não mudou.
  @BuiltValueField(wireName: r'feriados')
  BuiltList<FeriadoSaida> get feriados;

  ProximaDataSaida._();

  factory ProximaDataSaida([void updates(ProximaDataSaidaBuilder b)]) = _$ProximaDataSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ProximaDataSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ProximaDataSaida> get serializer => _$ProximaDataSaidaSerializer();
}

class _$ProximaDataSaidaSerializer implements PrimitiveSerializer<ProximaDataSaida> {
  @override
  final Iterable<Type> types = const [ProximaDataSaida, _$ProximaDataSaida];

  @override
  final String wireName = r'ProximaDataSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ProximaDataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(Date),
    );
    yield r'data_prevista';
    yield serializers.serialize(
      object.dataPrevista,
      specifiedType: const FullType(Date),
    );
    yield r'feriados';
    yield serializers.serialize(
      object.feriados,
      specifiedType: const FullType(BuiltList, [FullType(FeriadoSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ProximaDataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ProximaDataSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.data = valueDes;
          break;
        case r'data_prevista':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataPrevista = valueDes;
          break;
        case r'feriados':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(FeriadoSaida)]),
          ) as BuiltList<FeriadoSaida>;
          result.feriados.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ProximaDataSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ProximaDataSaidaBuilder();
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


