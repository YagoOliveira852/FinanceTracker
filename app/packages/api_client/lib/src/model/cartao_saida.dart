//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/fatura_resumo.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'cartao_saida.g.dart';

/// CartaoSaida
///
/// Properties:
/// * [contaPagamentoId] 
/// * [diaFechamento] 
/// * [diaVencimento] 
/// * [limite] 
/// * [faturaAtual] - A fatura de uma compra feita hoje.
@BuiltValue()
abstract class CartaoSaida implements Built<CartaoSaida, CartaoSaidaBuilder> {
  @BuiltValueField(wireName: r'conta_pagamento_id')
  String get contaPagamentoId;

  @BuiltValueField(wireName: r'dia_fechamento')
  int get diaFechamento;

  @BuiltValueField(wireName: r'dia_vencimento')
  int get diaVencimento;

  @BuiltValueField(wireName: r'limite')
  String? get limite;

  /// A fatura de uma compra feita hoje.
  @BuiltValueField(wireName: r'fatura_atual')
  FaturaResumo get faturaAtual;

  CartaoSaida._();

  factory CartaoSaida([void updates(CartaoSaidaBuilder b)]) = _$CartaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CartaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CartaoSaida> get serializer => _$CartaoSaidaSerializer();
}

class _$CartaoSaidaSerializer implements PrimitiveSerializer<CartaoSaida> {
  @override
  final Iterable<Type> types = const [CartaoSaida, _$CartaoSaida];

  @override
  final String wireName = r'CartaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CartaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conta_pagamento_id';
    yield serializers.serialize(
      object.contaPagamentoId,
      specifiedType: const FullType(String),
    );
    yield r'dia_fechamento';
    yield serializers.serialize(
      object.diaFechamento,
      specifiedType: const FullType(int),
    );
    yield r'dia_vencimento';
    yield serializers.serialize(
      object.diaVencimento,
      specifiedType: const FullType(int),
    );
    yield r'limite';
    yield object.limite == null ? null : serializers.serialize(
      object.limite,
      specifiedType: const FullType.nullable(String),
    );
    yield r'fatura_atual';
    yield serializers.serialize(
      object.faturaAtual,
      specifiedType: const FullType(FaturaResumo),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CartaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CartaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conta_pagamento_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaPagamentoId = valueDes;
          break;
        case r'dia_fechamento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.diaFechamento = valueDes;
          break;
        case r'dia_vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.diaVencimento = valueDes;
          break;
        case r'limite':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.limite = valueDes;
          break;
        case r'fatura_atual':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(FaturaResumo),
          ) as FaturaResumo;
          result.faturaAtual.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CartaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CartaoSaidaBuilder();
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


