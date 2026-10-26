//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/transferencia_par_saida.dart';
import 'package:api_client/src/model/status_transacao.dart';
import 'package:api_client/src/model/tipo_transacao.dart';
import 'package:api_client/src/model/parcela_saida.dart';
import 'package:api_client/src/model/fonte_transacao.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transacao_saida.g.dart';

/// TransacaoSaida
///
/// Properties:
/// * [id] 
/// * [contaId] 
/// * [tipo] 
/// * [valor] 
/// * [data] 
/// * [descricao] 
/// * [descricaoOriginal] 
/// * [status] 
/// * [fonte] 
/// * [faturaId] - Fatura da transação, se a conta é cartão.
/// * [parcela] - Número da parcela, se é compra parcelada.
/// * [transferencia] - O par e as duas contas, se é transferência ligada.
@BuiltValue()
abstract class TransacaoSaida implements Built<TransacaoSaida, TransacaoSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  @BuiltValueField(wireName: r'tipo')
  TipoTransacao get tipo;
  // enum tipoEnum {  despesa,  receita,  transferencia_saida,  transferencia_entrada,  pagamento_fatura,  aporte,  resgate,  estorno,  ajuste_entrada,  ajuste_saida,  };

  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'data')
  Date get data;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  @BuiltValueField(wireName: r'descricao_original')
  String get descricaoOriginal;

  @BuiltValueField(wireName: r'status')
  StatusTransacao get status;
  // enum statusEnum {  rascunho,  confirmada,  ignorada,  };

  @BuiltValueField(wireName: r'fonte')
  FonteTransacao get fonte;
  // enum fonteEnum {  manual,  ofx,  csv_mercadopago,  pluggy,  };

  /// Fatura da transação, se a conta é cartão.
  @BuiltValueField(wireName: r'fatura_id')
  String? get faturaId;

  /// Número da parcela, se é compra parcelada.
  @BuiltValueField(wireName: r'parcela')
  ParcelaSaida? get parcela;

  /// O par e as duas contas, se é transferência ligada.
  @BuiltValueField(wireName: r'transferencia')
  TransferenciaParSaida? get transferencia;

  TransacaoSaida._();

  factory TransacaoSaida([void updates(TransacaoSaidaBuilder b)]) = _$TransacaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransacaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransacaoSaida> get serializer => _$TransacaoSaidaSerializer();
}

class _$TransacaoSaidaSerializer implements PrimitiveSerializer<TransacaoSaida> {
  @override
  final Iterable<Type> types = const [TransacaoSaida, _$TransacaoSaida];

  @override
  final String wireName = r'TransacaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
      specifiedType: const FullType(String),
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
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(StatusTransacao),
    );
    yield r'fonte';
    yield serializers.serialize(
      object.fonte,
      specifiedType: const FullType(FonteTransacao),
    );
    yield r'fatura_id';
    yield object.faturaId == null ? null : serializers.serialize(
      object.faturaId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'parcela';
    yield object.parcela == null ? null : serializers.serialize(
      object.parcela,
      specifiedType: const FullType.nullable(ParcelaSaida),
    );
    yield r'transferencia';
    yield object.transferencia == null ? null : serializers.serialize(
      object.transferencia,
      specifiedType: const FullType.nullable(TransferenciaParSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TransacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransacaoSaidaBuilder result,
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
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaId = valueDes;
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
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(StatusTransacao),
          ) as StatusTransacao;
          result.status = valueDes;
          break;
        case r'fonte':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(FonteTransacao),
          ) as FonteTransacao;
          result.fonte = valueDes;
          break;
        case r'fatura_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.faturaId = valueDes;
          break;
        case r'parcela':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ParcelaSaida),
          ) as ParcelaSaida?;
          if (valueDes == null) continue;
          result.parcela.replace(valueDes);
          break;
        case r'transferencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(TransferenciaParSaida),
          ) as TransferenciaParSaida?;
          if (valueDes == null) continue;
          result.transferencia.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TransacaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransacaoSaidaBuilder();
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


