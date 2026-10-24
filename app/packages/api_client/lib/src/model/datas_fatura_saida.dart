//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'datas_fatura_saida.g.dart';

/// Competência e datas efetivas de uma fatura (ajustadas para dia útil).
///
/// Properties:
/// * [competencia] - Primeiro dia do mês do vencimento.
/// * [dataFechamento] 
/// * [dataVencimento] 
@BuiltValue()
abstract class DatasFaturaSaida implements Built<DatasFaturaSaida, DatasFaturaSaidaBuilder> {
  /// Primeiro dia do mês do vencimento.
  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  @BuiltValueField(wireName: r'data_fechamento')
  Date get dataFechamento;

  @BuiltValueField(wireName: r'data_vencimento')
  Date get dataVencimento;

  DatasFaturaSaida._();

  factory DatasFaturaSaida([void updates(DatasFaturaSaidaBuilder b)]) = _$DatasFaturaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DatasFaturaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DatasFaturaSaida> get serializer => _$DatasFaturaSaidaSerializer();
}

class _$DatasFaturaSaidaSerializer implements PrimitiveSerializer<DatasFaturaSaida> {
  @override
  final Iterable<Type> types = const [DatasFaturaSaida, _$DatasFaturaSaida];

  @override
  final String wireName = r'DatasFaturaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DatasFaturaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'competencia';
    yield serializers.serialize(
      object.competencia,
      specifiedType: const FullType(Date),
    );
    yield r'data_fechamento';
    yield serializers.serialize(
      object.dataFechamento,
      specifiedType: const FullType(Date),
    );
    yield r'data_vencimento';
    yield serializers.serialize(
      object.dataVencimento,
      specifiedType: const FullType(Date),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DatasFaturaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DatasFaturaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.competencia = valueDes;
          break;
        case r'data_fechamento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataFechamento = valueDes;
          break;
        case r'data_vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataVencimento = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DatasFaturaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DatasFaturaSaidaBuilder();
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


