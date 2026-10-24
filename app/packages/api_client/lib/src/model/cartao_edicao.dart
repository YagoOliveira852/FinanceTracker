//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'cartao_edicao.g.dart';

/// Os mesmos campos do cadastro, mais `ativa` (desativar ou reativar).
///
/// Properties:
/// * [nome] 
/// * [instituicao] - Nome da instituição. Se nenhuma tiver esse nome (sem diferenciar maiúsculas), uma nova é criada.
/// * [contaPagamentoId] - Conta corrente ativa que paga a fatura.
/// * [diaFechamento] - 31 vira o último dia do mês.
/// * [diaVencimento] - Diferente do fechamento; 31 vira o último dia do mês.
/// * [limite] 
/// * [ativa] 
@BuiltValue()
abstract class CartaoEdicao implements Built<CartaoEdicao, CartaoEdicaoBuilder> {
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

  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  CartaoEdicao._();

  factory CartaoEdicao([void updates(CartaoEdicaoBuilder b)]) = _$CartaoEdicao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CartaoEdicaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CartaoEdicao> get serializer => _$CartaoEdicaoSerializer();
}

class _$CartaoEdicaoSerializer implements PrimitiveSerializer<CartaoEdicao> {
  @override
  final Iterable<Type> types = const [CartaoEdicao, _$CartaoEdicao];

  @override
  final String wireName = r'CartaoEdicao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CartaoEdicao object, {
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
    yield r'ativa';
    yield serializers.serialize(
      object.ativa,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CartaoEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CartaoEdicaoBuilder result,
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
        case r'ativa':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ativa = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CartaoEdicao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CartaoEdicaoBuilder();
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


