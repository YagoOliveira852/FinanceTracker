//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/status_transacao.dart';
import 'package:api_client/src/model/conta_na_revisao.dart';
import 'package:api_client/src/model/tipo_transacao.dart';
import 'package:api_client/src/model/categoria_resumo.dart';
import 'package:api_client/src/model/fonte_transacao.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transacao_revisao.g.dart';

/// TransacaoRevisao
///
/// Properties:
/// * [id] 
/// * [conta] 
/// * [tipo] 
/// * [valor] 
/// * [data] 
/// * [descricao] 
/// * [descricaoOriginal] - Como veio do banco.
/// * [fonte] 
/// * [status] 
/// * [categoria] - Só a confirmada tem.
/// * [faturaCompetencia] - Fatura em que a compra entra (cartão), ou a paga (pagamento de fatura).
/// * [removidaNaOrigemEm] - A confirmada que sumiu do Open Finance.
@BuiltValue()
abstract class TransacaoRevisao implements Built<TransacaoRevisao, TransacaoRevisaoBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'conta')
  ContaNaRevisao get conta;

  @BuiltValueField(wireName: r'tipo')
  TipoTransacao get tipo;
  // enum tipoEnum {  despesa,  receita,  transferencia_saida,  transferencia_entrada,  pagamento_fatura,  aporte,  resgate,  estorno,  ajuste_entrada,  ajuste_saida,  };

  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'data')
  Date get data;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  /// Como veio do banco.
  @BuiltValueField(wireName: r'descricao_original')
  String get descricaoOriginal;

  @BuiltValueField(wireName: r'fonte')
  FonteTransacao get fonte;
  // enum fonteEnum {  manual,  ofx,  csv_mercadopago,  pluggy,  };

  @BuiltValueField(wireName: r'status')
  StatusTransacao get status;
  // enum statusEnum {  rascunho,  confirmada,  ignorada,  };

  /// Só a confirmada tem.
  @BuiltValueField(wireName: r'categoria')
  CategoriaResumo? get categoria;

  /// Fatura em que a compra entra (cartão), ou a paga (pagamento de fatura).
  @BuiltValueField(wireName: r'fatura_competencia')
  Date? get faturaCompetencia;

  /// A confirmada que sumiu do Open Finance.
  @BuiltValueField(wireName: r'removida_na_origem_em')
  DateTime? get removidaNaOrigemEm;

  TransacaoRevisao._();

  factory TransacaoRevisao([void updates(TransacaoRevisaoBuilder b)]) = _$TransacaoRevisao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransacaoRevisaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransacaoRevisao> get serializer => _$TransacaoRevisaoSerializer();
}

class _$TransacaoRevisaoSerializer implements PrimitiveSerializer<TransacaoRevisao> {
  @override
  final Iterable<Type> types = const [TransacaoRevisao, _$TransacaoRevisao];

  @override
  final String wireName = r'TransacaoRevisao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransacaoRevisao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'conta';
    yield serializers.serialize(
      object.conta,
      specifiedType: const FullType(ContaNaRevisao),
    );
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(TipoTransacao),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(Date),
    );
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
    yield r'descricao_original';
    yield serializers.serialize(
      object.descricaoOriginal,
      specifiedType: const FullType(String),
    );
    yield r'fonte';
    yield serializers.serialize(
      object.fonte,
      specifiedType: const FullType(FonteTransacao),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(StatusTransacao),
    );
    yield r'categoria';
    yield object.categoria == null ? null : serializers.serialize(
      object.categoria,
      specifiedType: const FullType.nullable(CategoriaResumo),
    );
    yield r'fatura_competencia';
    yield object.faturaCompetencia == null ? null : serializers.serialize(
      object.faturaCompetencia,
      specifiedType: const FullType.nullable(Date),
    );
    yield r'removida_na_origem_em';
    yield object.removidaNaOrigemEm == null ? null : serializers.serialize(
      object.removidaNaOrigemEm,
      specifiedType: const FullType.nullable(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TransacaoRevisao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransacaoRevisaoBuilder result,
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
        case r'conta':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ContaNaRevisao),
          ) as ContaNaRevisao;
          result.conta.replace(valueDes);
          break;
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TipoTransacao),
          ) as TipoTransacao;
          result.tipo = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.data = valueDes;
          break;
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
          break;
        case r'descricao_original':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricaoOriginal = valueDes;
          break;
        case r'fonte':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(FonteTransacao),
          ) as FonteTransacao;
          result.fonte = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(StatusTransacao),
          ) as StatusTransacao;
          result.status = valueDes;
          break;
        case r'categoria':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(CategoriaResumo),
          ) as CategoriaResumo?;
          if (valueDes == null) continue;
          result.categoria.replace(valueDes);
          break;
        case r'fatura_competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(Date),
          ) as Date?;
          if (valueDes == null) continue;
          result.faturaCompetencia = valueDes;
          break;
        case r'removida_na_origem_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.removidaNaOrigemEm = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TransacaoRevisao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransacaoRevisaoBuilder();
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


