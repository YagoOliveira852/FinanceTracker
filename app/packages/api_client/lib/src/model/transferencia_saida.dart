//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/transacao_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transferencia_saida.g.dart';

/// TransferenciaSaida
///
/// Properties:
/// * [saida] - O lado da conta de origem.
/// * [entrada] - O lado da conta de destino.
@BuiltValue()
abstract class TransferenciaSaida implements Built<TransferenciaSaida, TransferenciaSaidaBuilder> {
  /// O lado da conta de origem.
  @BuiltValueField(wireName: r'saida')
  TransacaoSaida get saida;

  /// O lado da conta de destino.
  @BuiltValueField(wireName: r'entrada')
  TransacaoSaida get entrada;

  TransferenciaSaida._();

  factory TransferenciaSaida([void updates(TransferenciaSaidaBuilder b)]) = _$TransferenciaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransferenciaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransferenciaSaida> get serializer => _$TransferenciaSaidaSerializer();
}

class _$TransferenciaSaidaSerializer implements PrimitiveSerializer<TransferenciaSaida> {
  @override
  final Iterable<Type> types = const [TransferenciaSaida, _$TransferenciaSaida];

  @override
  final String wireName = r'TransferenciaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransferenciaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'saida';
    yield serializers.serialize(
      object.saida,
      specifiedType: const FullType(TransacaoSaida),
    );
    yield r'entrada';
    yield serializers.serialize(
      object.entrada,
      specifiedType: const FullType(TransacaoSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TransferenciaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransferenciaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'saida':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoSaida),
          ) as TransacaoSaida;
          result.saida.replace(valueDes);
          break;
        case r'entrada':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoSaida),
          ) as TransacaoSaida;
          result.entrada.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TransferenciaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransferenciaSaidaBuilder();
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


