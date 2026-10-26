//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transferencia_par_saida.g.dart';

/// TransferenciaParSaida
///
/// Properties:
/// * [parId] - O outro lado da transferência.
/// * [contaOrigemId] 
/// * [contaDestinoId] 
@BuiltValue()
abstract class TransferenciaParSaida implements Built<TransferenciaParSaida, TransferenciaParSaidaBuilder> {
  /// O outro lado da transferência.
  @BuiltValueField(wireName: r'par_id')
  String get parId;

  @BuiltValueField(wireName: r'conta_origem_id')
  String get contaOrigemId;

  @BuiltValueField(wireName: r'conta_destino_id')
  String get contaDestinoId;

  TransferenciaParSaida._();

  factory TransferenciaParSaida([void updates(TransferenciaParSaidaBuilder b)]) = _$TransferenciaParSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransferenciaParSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransferenciaParSaida> get serializer => _$TransferenciaParSaidaSerializer();
}

class _$TransferenciaParSaidaSerializer implements PrimitiveSerializer<TransferenciaParSaida> {
  @override
  final Iterable<Type> types = const [TransferenciaParSaida, _$TransferenciaParSaida];

  @override
  final String wireName = r'TransferenciaParSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransferenciaParSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'par_id';
    yield serializers.serialize(
      object.parId,
      specifiedType: const FullType(String),
    );
    yield r'conta_origem_id';
    yield serializers.serialize(
      object.contaOrigemId,
      specifiedType: const FullType(String),
    );
    yield r'conta_destino_id';
    yield serializers.serialize(
      object.contaDestinoId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TransferenciaParSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransferenciaParSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'par_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.parId = valueDes;
          break;
        case r'conta_origem_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaOrigemId = valueDes;
          break;
        case r'conta_destino_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaDestinoId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TransferenciaParSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransferenciaParSaidaBuilder();
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


