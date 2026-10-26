//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'pagamento_entrada.g.dart';

/// PagamentoEntrada
///
/// Properties:
/// * [contaId] - A corrente ou carteira de onde sai o dinheiro.
/// * [valor] 
/// * [data] - O dia em que o dinheiro sai da conta.
@BuiltValue()
abstract class PagamentoEntrada implements Built<PagamentoEntrada, PagamentoEntradaBuilder> {
  /// A corrente ou carteira de onde sai o dinheiro.
  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// O dia em que o dinheiro sai da conta.
  @BuiltValueField(wireName: r'data')
  Date get data;

  PagamentoEntrada._();

  factory PagamentoEntrada([void updates(PagamentoEntradaBuilder b)]) = _$PagamentoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PagamentoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PagamentoEntrada> get serializer => _$PagamentoEntradaSerializer();
}

class _$PagamentoEntradaSerializer implements PrimitiveSerializer<PagamentoEntrada> {
  @override
  final Iterable<Type> types = const [PagamentoEntrada, _$PagamentoEntrada];

  @override
  final String wireName = r'PagamentoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PagamentoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
      specifiedType: const FullType(String),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    PagamentoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PagamentoEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaId = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PagamentoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PagamentoEntradaBuilder();
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


