//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/feriado_saida.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'ajuste_data_saida.g.dart';

/// A data prevista (o dia do cartão) não era dia útil.
///
/// Properties:
/// * [dataPrevista] 
/// * [feriados] - Feriados pulados até a data efetiva; vazia se só o fim de semana pesou.
@BuiltValue()
abstract class AjusteDataSaida implements Built<AjusteDataSaida, AjusteDataSaidaBuilder> {
  @BuiltValueField(wireName: r'data_prevista')
  Date get dataPrevista;

  /// Feriados pulados até a data efetiva; vazia se só o fim de semana pesou.
  @BuiltValueField(wireName: r'feriados')
  BuiltList<FeriadoSaida> get feriados;

  AjusteDataSaida._();

  factory AjusteDataSaida([void updates(AjusteDataSaidaBuilder b)]) = _$AjusteDataSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AjusteDataSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AjusteDataSaida> get serializer => _$AjusteDataSaidaSerializer();
}

class _$AjusteDataSaidaSerializer implements PrimitiveSerializer<AjusteDataSaida> {
  @override
  final Iterable<Type> types = const [AjusteDataSaida, _$AjusteDataSaida];

  @override
  final String wireName = r'AjusteDataSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AjusteDataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    AjusteDataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AjusteDataSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
  AjusteDataSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AjusteDataSaidaBuilder();
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


