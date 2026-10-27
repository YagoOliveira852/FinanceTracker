//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/transacao_revisao.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'par_saida.g.dart';

/// ParSaida
///
/// Properties:
/// * [saida] 
/// * [entrada] 
/// * [dias] - Diferença de dias entre as duas (até 2).
@BuiltValue()
abstract class ParSaida implements Built<ParSaida, ParSaidaBuilder> {
  @BuiltValueField(wireName: r'saida')
  TransacaoRevisao get saida;

  @BuiltValueField(wireName: r'entrada')
  TransacaoRevisao get entrada;

  /// Diferença de dias entre as duas (até 2).
  @BuiltValueField(wireName: r'dias')
  int get dias;

  ParSaida._();

  factory ParSaida([void updates(ParSaidaBuilder b)]) = _$ParSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ParSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ParSaida> get serializer => _$ParSaidaSerializer();
}

class _$ParSaidaSerializer implements PrimitiveSerializer<ParSaida> {
  @override
  final Iterable<Type> types = const [ParSaida, _$ParSaida];

  @override
  final String wireName = r'ParSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ParSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'saida';
    yield serializers.serialize(
      object.saida,
      specifiedType: const FullType(TransacaoRevisao),
    );
    yield r'entrada';
    yield serializers.serialize(
      object.entrada,
      specifiedType: const FullType(TransacaoRevisao),
    );
    yield r'dias';
    yield serializers.serialize(
      object.dias,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ParSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ParSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'saida':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoRevisao),
          ) as TransacaoRevisao;
          result.saida.replace(valueDes);
          break;
        case r'entrada':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoRevisao),
          ) as TransacaoRevisao;
          result.entrada.replace(valueDes);
          break;
        case r'dias':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.dias = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ParSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ParSaidaBuilder();
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


