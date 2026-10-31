//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_reservada_saida.g.dart';

/// FaturaReservadaSaida
///
/// Properties:
/// * [cartaoId] 
/// * [cartao] - Nome do cartão.
/// * [competencia] 
/// * [vencimento] 
/// * [valor] - O que falta pagar: o maior entre informado e calculado, menos o pago.
@BuiltValue()
abstract class FaturaReservadaSaida implements Built<FaturaReservadaSaida, FaturaReservadaSaidaBuilder> {
  @BuiltValueField(wireName: r'cartao_id')
  String get cartaoId;

  /// Nome do cartão.
  @BuiltValueField(wireName: r'cartao')
  String get cartao;

  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  @BuiltValueField(wireName: r'vencimento')
  Date get vencimento;

  /// O que falta pagar: o maior entre informado e calculado, menos o pago.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  FaturaReservadaSaida._();

  factory FaturaReservadaSaida([void updates(FaturaReservadaSaidaBuilder b)]) = _$FaturaReservadaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaReservadaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaReservadaSaida> get serializer => _$FaturaReservadaSaidaSerializer();
}

class _$FaturaReservadaSaidaSerializer implements PrimitiveSerializer<FaturaReservadaSaida> {
  @override
  final Iterable<Type> types = const [FaturaReservadaSaida, _$FaturaReservadaSaida];

  @override
  final String wireName = r'FaturaReservadaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaReservadaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'cartao_id';
    yield serializers.serialize(
      object.cartaoId,
      specifiedType: const FullType(String),
    );
    yield r'cartao';
    yield serializers.serialize(
      object.cartao,
      specifiedType: const FullType(String),
    );
    yield r'competencia';
    yield serializers.serialize(
      object.competencia,
      specifiedType: const FullType(Date),
    );
    yield r'vencimento';
    yield serializers.serialize(
      object.vencimento,
      specifiedType: const FullType(Date),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaReservadaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaReservadaSaidaBuilder result,
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
        case r'cartao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.cartao = valueDes;
          break;
        case r'competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.competencia = valueDes;
          break;
        case r'vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.vencimento = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaReservadaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaReservadaSaidaBuilder();
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


