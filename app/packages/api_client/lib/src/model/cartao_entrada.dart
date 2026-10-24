//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'cartao_entrada.g.dart';

/// CartaoEntrada
///
/// Properties:
/// * [nome] 
/// * [instituicao] - Nome da instituição. Se nenhuma tiver esse nome (sem diferenciar maiúsculas), uma nova é criada.
/// * [contaPagamentoId] - Conta corrente ativa que paga a fatura.
/// * [diaFechamento] - 31 vira o último dia do mês.
/// * [diaVencimento] - Diferente do fechamento; 31 vira o último dia do mês.
/// * [limite] 
@BuiltValue()
abstract class CartaoEntrada implements Built<CartaoEntrada, CartaoEntradaBuilder> {
  @BuiltValueField(wireName: r'nome')
  String get nome;

  /// Nome da instituição. Se nenhuma tiver esse nome (sem diferenciar maiúsculas), uma nova é criada.
  @BuiltValueField(wireName: r'instituicao')
  String get instituicao;

  /// Conta corrente ativa que paga a fatura.
  @BuiltValueField(wireName: r'conta_pagamento_id')
  String get contaPagamentoId;

  /// 31 vira o último dia do mês.
  @BuiltValueField(wireName: r'dia_fechamento')
  int get diaFechamento;

  /// Diferente do fechamento; 31 vira o último dia do mês.
  @BuiltValueField(wireName: r'dia_vencimento')
  int get diaVencimento;

  @BuiltValueField(wireName: r'limite')
  String? get limite;

  CartaoEntrada._();

  factory CartaoEntrada([void updates(CartaoEntradaBuilder b)]) = _$CartaoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CartaoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CartaoEntrada> get serializer => _$CartaoEntradaSerializer();
}

class _$CartaoEntradaSerializer implements PrimitiveSerializer<CartaoEntrada> {
  @override
  final Iterable<Type> types = const [CartaoEntrada, _$CartaoEntrada];

  @override
  final String wireName = r'CartaoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CartaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'nome';
    yield serializers.serialize(
      object.nome,
      specifiedType: const FullType(String),
    );
    yield r'instituicao';
    yield serializers.serialize(
      object.instituicao,
      specifiedType: const FullType(String),
    );
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
    if (object.limite != null) {
      yield r'limite';
      yield serializers.serialize(
        object.limite,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CartaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CartaoEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'nome':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nome = valueDes;
          break;
        case r'instituicao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.instituicao = valueDes;
          break;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CartaoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CartaoEntradaBuilder();
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


