//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/status_fatura.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_candidata_saida.g.dart';

/// FaturaCandidataSaida
///
/// Properties:
/// * [cartaoId] 
/// * [cartaoNome] 
/// * [competencia] - Primeiro dia do mês do vencimento.
/// * [status] - Como está hoje, sem este pagamento.
/// * [dataVencimento] 
/// * [valor] 
/// * [valorPago] - Já pago, sem este pagamento.
/// * [ficaPaga] - Com este pagamento, a fatura fica paga.
/// * [sugerida] - A pré-selecionada (no máximo uma).
@BuiltValue()
abstract class FaturaCandidataSaida implements Built<FaturaCandidataSaida, FaturaCandidataSaidaBuilder> {
  @BuiltValueField(wireName: r'cartao_id')
  String get cartaoId;

  @BuiltValueField(wireName: r'cartao_nome')
  String get cartaoNome;

  /// Primeiro dia do mês do vencimento.
  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  /// Como está hoje, sem este pagamento.
  @BuiltValueField(wireName: r'status')
  StatusFatura get status;
  // enum statusEnum {  aberta,  fechada,  paga,  };

  @BuiltValueField(wireName: r'data_vencimento')
  Date get dataVencimento;

  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// Já pago, sem este pagamento.
  @BuiltValueField(wireName: r'valor_pago')
  String get valorPago;

  /// Com este pagamento, a fatura fica paga.
  @BuiltValueField(wireName: r'fica_paga')
  bool get ficaPaga;

  /// A pré-selecionada (no máximo uma).
  @BuiltValueField(wireName: r'sugerida')
  bool get sugerida;

  FaturaCandidataSaida._();

  factory FaturaCandidataSaida([void updates(FaturaCandidataSaidaBuilder b)]) = _$FaturaCandidataSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaCandidataSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaCandidataSaida> get serializer => _$FaturaCandidataSaidaSerializer();
}

class _$FaturaCandidataSaidaSerializer implements PrimitiveSerializer<FaturaCandidataSaida> {
  @override
  final Iterable<Type> types = const [FaturaCandidataSaida, _$FaturaCandidataSaida];

  @override
  final String wireName = r'FaturaCandidataSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaCandidataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'cartao_id';
    yield serializers.serialize(
      object.cartaoId,
      specifiedType: const FullType(String),
    );
    yield r'cartao_nome';
    yield serializers.serialize(
      object.cartaoNome,
      specifiedType: const FullType(String),
    );
    yield r'competencia';
    yield serializers.serialize(
      object.competencia,
      specifiedType: const FullType(Date),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(StatusFatura),
    );
    yield r'data_vencimento';
    yield serializers.serialize(
      object.dataVencimento,
      specifiedType: const FullType(Date),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'valor_pago';
    yield serializers.serialize(
      object.valorPago,
      specifiedType: const FullType(String),
    );
    yield r'fica_paga';
    yield serializers.serialize(
      object.ficaPaga,
      specifiedType: const FullType(bool),
    );
    yield r'sugerida';
    yield serializers.serialize(
      object.sugerida,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaCandidataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaCandidataSaidaBuilder result,
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
        case r'cartao_nome':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.cartaoNome = valueDes;
          break;
        case r'competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.competencia = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(StatusFatura),
          ) as StatusFatura;
          result.status = valueDes;
          break;
        case r'data_vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataVencimento = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'valor_pago':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valorPago = valueDes;
          break;
        case r'fica_paga':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ficaPaga = valueDes;
          break;
        case r'sugerida':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.sugerida = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaCandidataSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaCandidataSaidaBuilder();
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


