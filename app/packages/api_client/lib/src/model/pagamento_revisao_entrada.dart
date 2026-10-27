//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'pagamento_revisao_entrada.g.dart';

/// PagamentoRevisaoEntrada
///
/// Properties:
/// * [cartaoId] 
/// * [competencia] - Mês da fatura, `AAAA-MM`.
@BuiltValue()
abstract class PagamentoRevisaoEntrada implements Built<PagamentoRevisaoEntrada, PagamentoRevisaoEntradaBuilder> {
  @BuiltValueField(wireName: r'cartao_id')
  String get cartaoId;

  /// Mês da fatura, `AAAA-MM`.
  @BuiltValueField(wireName: r'competencia')
  String get competencia;

  PagamentoRevisaoEntrada._();

  factory PagamentoRevisaoEntrada([void updates(PagamentoRevisaoEntradaBuilder b)]) = _$PagamentoRevisaoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PagamentoRevisaoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PagamentoRevisaoEntrada> get serializer => _$PagamentoRevisaoEntradaSerializer();
}

class _$PagamentoRevisaoEntradaSerializer implements PrimitiveSerializer<PagamentoRevisaoEntrada> {
  @override
  final Iterable<Type> types = const [PagamentoRevisaoEntrada, _$PagamentoRevisaoEntrada];

  @override
  final String wireName = r'PagamentoRevisaoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PagamentoRevisaoEntrada object, {
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
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PagamentoRevisaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PagamentoRevisaoEntradaBuilder result,
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
            specifiedType: const FullType(String),
          ) as String;
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
  PagamentoRevisaoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PagamentoRevisaoEntradaBuilder();
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


