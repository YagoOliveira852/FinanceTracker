//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/status_fatura.dart';
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/ajuste_data_saida.dart';
import 'package:api_client/src/model/date.dart';
import 'package:api_client/src/model/transacao_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_detalhe_saida.g.dart';

/// FaturaDetalheSaida
///
/// Properties:
/// * [competencia] - Primeiro dia do mês do vencimento.
/// * [dataFechamento] 
/// * [dataVencimento] 
/// * [status] - Aberta antes do fechamento; depois dele, paga se os pagamentos cobrem o valor, senão fechada.
/// * [valor] - O maior entre o informado e o calculado.
/// * [valorCalculado] - Compras menos estornos da fatura, com rascunhos e sem as ignoradas.
/// * [valorInformado] - O total que o banco mostra.
/// * [valorPago] - Soma dos pagamentos ligados à fatura, com rascunhos e sem os ignorados.
/// * [fechamentoCalculado] - Pela regra do cartão, ignorando edições.
/// * [vencimentoCalculado] - Pela regra do cartão, ignorando edições.
/// * [ajusteFechamento] - Por que o fechamento calculado não é o dia do cartão; nulo se é.
/// * [ajusteVencimento] - Por que o vencimento calculado não é o dia do cartão; nulo se é.
/// * [transacoes] - As do cartão, sem as ignoradas, das mais recentes.
/// * [pagamentos] - Pagamentos da fatura, sem os ignorados, do mais antigo.
@BuiltValue()
abstract class FaturaDetalheSaida implements Built<FaturaDetalheSaida, FaturaDetalheSaidaBuilder> {
  /// Primeiro dia do mês do vencimento.
  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  @BuiltValueField(wireName: r'data_fechamento')
  Date get dataFechamento;

  @BuiltValueField(wireName: r'data_vencimento')
  Date get dataVencimento;

  /// Aberta antes do fechamento; depois dele, paga se os pagamentos cobrem o valor, senão fechada.
  @BuiltValueField(wireName: r'status')
  StatusFatura get status;
  // enum statusEnum {  aberta,  fechada,  paga,  };

  /// O maior entre o informado e o calculado.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// Compras menos estornos da fatura, com rascunhos e sem as ignoradas.
  @BuiltValueField(wireName: r'valor_calculado')
  String get valorCalculado;

  /// O total que o banco mostra.
  @BuiltValueField(wireName: r'valor_informado')
  String? get valorInformado;

  /// Soma dos pagamentos ligados à fatura, com rascunhos e sem os ignorados.
  @BuiltValueField(wireName: r'valor_pago')
  String get valorPago;

  /// Pela regra do cartão, ignorando edições.
  @BuiltValueField(wireName: r'fechamento_calculado')
  Date get fechamentoCalculado;

  /// Pela regra do cartão, ignorando edições.
  @BuiltValueField(wireName: r'vencimento_calculado')
  Date get vencimentoCalculado;

  /// Por que o fechamento calculado não é o dia do cartão; nulo se é.
  @BuiltValueField(wireName: r'ajuste_fechamento')
  AjusteDataSaida? get ajusteFechamento;

  /// Por que o vencimento calculado não é o dia do cartão; nulo se é.
  @BuiltValueField(wireName: r'ajuste_vencimento')
  AjusteDataSaida? get ajusteVencimento;

  /// As do cartão, sem as ignoradas, das mais recentes.
  @BuiltValueField(wireName: r'transacoes')
  BuiltList<TransacaoSaida> get transacoes;

  /// Pagamentos da fatura, sem os ignorados, do mais antigo.
  @BuiltValueField(wireName: r'pagamentos')
  BuiltList<TransacaoSaida> get pagamentos;

  FaturaDetalheSaida._();

  factory FaturaDetalheSaida([void updates(FaturaDetalheSaidaBuilder b)]) = _$FaturaDetalheSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaDetalheSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaDetalheSaida> get serializer => _$FaturaDetalheSaidaSerializer();
}

class _$FaturaDetalheSaidaSerializer implements PrimitiveSerializer<FaturaDetalheSaida> {
  @override
  final Iterable<Type> types = const [FaturaDetalheSaida, _$FaturaDetalheSaida];

  @override
  final String wireName = r'FaturaDetalheSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaDetalheSaida object, {
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
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(StatusFatura),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'valor_calculado';
    yield serializers.serialize(
      object.valorCalculado,
      specifiedType: const FullType(String),
    );
    yield r'valor_informado';
    yield object.valorInformado == null ? null : serializers.serialize(
      object.valorInformado,
      specifiedType: const FullType.nullable(String),
    );
    yield r'valor_pago';
    yield serializers.serialize(
      object.valorPago,
      specifiedType: const FullType(String),
    );
    yield r'fechamento_calculado';
    yield serializers.serialize(
      object.fechamentoCalculado,
      specifiedType: const FullType(Date),
    );
    yield r'vencimento_calculado';
    yield serializers.serialize(
      object.vencimentoCalculado,
      specifiedType: const FullType(Date),
    );
    yield r'ajuste_fechamento';
    yield object.ajusteFechamento == null ? null : serializers.serialize(
      object.ajusteFechamento,
      specifiedType: const FullType.nullable(AjusteDataSaida),
    );
    yield r'ajuste_vencimento';
    yield object.ajusteVencimento == null ? null : serializers.serialize(
      object.ajusteVencimento,
      specifiedType: const FullType.nullable(AjusteDataSaida),
    );
    yield r'transacoes';
    yield serializers.serialize(
      object.transacoes,
      specifiedType: const FullType(BuiltList, [FullType(TransacaoSaida)]),
    );
    yield r'pagamentos';
    yield serializers.serialize(
      object.pagamentos,
      specifiedType: const FullType(BuiltList, [FullType(TransacaoSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaDetalheSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaDetalheSaidaBuilder result,
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
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(StatusFatura),
          ) as StatusFatura;
          result.status = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'valor_calculado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valorCalculado = valueDes;
          break;
        case r'valor_informado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.valorInformado = valueDes;
          break;
        case r'valor_pago':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valorPago = valueDes;
          break;
        case r'fechamento_calculado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.fechamentoCalculado = valueDes;
          break;
        case r'vencimento_calculado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.vencimentoCalculado = valueDes;
          break;
        case r'ajuste_fechamento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(AjusteDataSaida),
          ) as AjusteDataSaida?;
          if (valueDes == null) continue;
          result.ajusteFechamento.replace(valueDes);
          break;
        case r'ajuste_vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(AjusteDataSaida),
          ) as AjusteDataSaida?;
          if (valueDes == null) continue;
          result.ajusteVencimento.replace(valueDes);
          break;
        case r'transacoes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TransacaoSaida)]),
          ) as BuiltList<TransacaoSaida>;
          result.transacoes.replace(valueDes);
          break;
        case r'pagamentos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TransacaoSaida)]),
          ) as BuiltList<TransacaoSaida>;
          result.pagamentos.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaDetalheSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaDetalheSaidaBuilder();
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


