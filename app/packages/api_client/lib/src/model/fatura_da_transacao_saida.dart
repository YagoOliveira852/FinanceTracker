//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_da_transacao_saida.g.dart';

/// FaturaDaTransacaoSaida
///
/// Properties:
/// * [cartaoId] 
/// * [competencia] - Primeiro dia do mês do vencimento.
@BuiltValue()
abstract class FaturaDaTransacaoSaida implements Built<FaturaDaTransacaoSaida, FaturaDaTransacaoSaidaBuilder> {
  @BuiltValueField(wireName: r'cartao_id')
  String get cartaoId;

  /// Primeiro dia do mês do vencimento.
  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  FaturaDaTransacaoSaida._();

  factory FaturaDaTransacaoSaida([void updates(FaturaDaTransacaoSaidaBuilder b)]) = _$FaturaDaTransacaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaDaTransacaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaDaTransacaoSaida> get serializer => _$FaturaDaTransacaoSaidaSerializer();
}

class _$FaturaDaTransacaoSaidaSerializer implements PrimitiveSerializer<FaturaDaTransacaoSaida> {
  @override
  final Iterable<Type> types = const [FaturaDaTransacaoSaida, _$FaturaDaTransacaoSaida];

  @override
  final String wireName = r'FaturaDaTransacaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaDaTransacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'cartao_id';
    yield serializers.serialize(
      object.cartaoId,
      specifiedType: const FullType(String),
    );
    yield r'competencia';
    yield serializers.serialize(
      object.competencia,
      specifiedType: const FullType(Date),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaDaTransacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaDaTransacaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'cartao_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.cartaoId = valueDes;
          break;
        case r'competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.competencia = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaDaTransacaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaDaTransacaoSaidaBuilder();
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


