//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/cartao_saida.dart';
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:api_client/src/model/instituicao_saida.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_saida.g.dart';

/// ContaSaida
///
/// Properties:
/// * [id] 
/// * [nome] 
/// * [tipo] 
/// * [instituicao] 
/// * [saldoInicial] 
/// * [dataSaldoInicial] 
/// * [saldoAtual] - `saldo_inicial` mais as transações confirmadas com data a partir de `data_saldo_inicial`.
/// * [ativa] 
/// * [cartao] - Dados do cartão; nulo se não for cartão.
@BuiltValue()
abstract class ContaSaida implements Built<ContaSaida, ContaSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'tipo')
  TipoConta get tipo;
  // enum tipoEnum {  corrente,  cartao_credito,  carteira,  };

  @BuiltValueField(wireName: r'instituicao')
  InstituicaoSaida? get instituicao;

  @BuiltValueField(wireName: r'saldo_inicial')
  String get saldoInicial;

  @BuiltValueField(wireName: r'data_saldo_inicial')
  Date get dataSaldoInicial;

  /// `saldo_inicial` mais as transações confirmadas com data a partir de `data_saldo_inicial`.
  @BuiltValueField(wireName: r'saldo_atual')
  String get saldoAtual;

  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  /// Dados do cartão; nulo se não for cartão.
  @BuiltValueField(wireName: r'cartao')
  CartaoSaida? get cartao;

  ContaSaida._();

  factory ContaSaida([void updates(ContaSaidaBuilder b)]) = _$ContaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaSaida> get serializer => _$ContaSaidaSerializer();
}

class _$ContaSaidaSerializer implements PrimitiveSerializer<ContaSaida> {
  @override
  final Iterable<Type> types = const [ContaSaida, _$ContaSaida];

  @override
  final String wireName = r'ContaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'nome';
    yield serializers.serialize(
      object.nome,
      specifiedType: const FullType(String),
    );
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(TipoConta),
    );
    yield r'instituicao';
    yield object.instituicao == null ? null : serializers.serialize(
      object.instituicao,
      specifiedType: const FullType.nullable(InstituicaoSaida),
    );
    yield r'saldo_inicial';
    yield serializers.serialize(
      object.saldoInicial,
      specifiedType: const FullType(String),
    );
    yield r'data_saldo_inicial';
    yield serializers.serialize(
      object.dataSaldoInicial,
      specifiedType: const FullType(Date),
    );
    yield r'saldo_atual';
    yield serializers.serialize(
      object.saldoAtual,
      specifiedType: const FullType(String),
    );
    yield r'ativa';
    yield serializers.serialize(
      object.ativa,
      specifiedType: const FullType(bool),
    );
    yield r'cartao';
    yield object.cartao == null ? null : serializers.serialize(
      object.cartao,
      specifiedType: const FullType.nullable(CartaoSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'nome':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nome = valueDes;
          break;
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TipoConta),
          ) as TipoConta;
          result.tipo = valueDes;
          break;
        case r'instituicao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(InstituicaoSaida),
          ) as InstituicaoSaida?;
          if (valueDes == null) continue;
          result.instituicao.replace(valueDes);
          break;
        case r'saldo_inicial':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.saldoInicial = valueDes;
          break;
        case r'data_saldo_inicial':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataSaldoInicial = valueDes;
          break;
        case r'saldo_atual':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.saldoAtual = valueDes;
          break;
        case r'ativa':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ativa = valueDes;
          break;
        case r'cartao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(CartaoSaida),
          ) as CartaoSaida?;
          if (valueDes == null) continue;
          result.cartao.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaSaidaBuilder();
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


