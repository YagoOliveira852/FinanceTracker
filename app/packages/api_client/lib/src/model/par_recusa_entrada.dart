//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'par_recusa_entrada.g.dart';

/// ParRecusaEntrada
///
/// Properties:
/// * [saidaId] 
/// * [entradaId] 
@BuiltValue()
abstract class ParRecusaEntrada implements Built<ParRecusaEntrada, ParRecusaEntradaBuilder> {
  @BuiltValueField(wireName: r'saida_id')
  String get saidaId;

  @BuiltValueField(wireName: r'entrada_id')
  String get entradaId;

  ParRecusaEntrada._();

  factory ParRecusaEntrada([void updates(ParRecusaEntradaBuilder b)]) = _$ParRecusaEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ParRecusaEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ParRecusaEntrada> get serializer => _$ParRecusaEntradaSerializer();
}

class _$ParRecusaEntradaSerializer implements PrimitiveSerializer<ParRecusaEntrada> {
  @override
  final Iterable<Type> types = const [ParRecusaEntrada, _$ParRecusaEntrada];

  @override
  final String wireName = r'ParRecusaEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ParRecusaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'saida_id';
    yield serializers.serialize(
      object.saidaId,
      specifiedType: const FullType(String),
    );
    yield r'entrada_id';
    yield serializers.serialize(
      object.entradaId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ParRecusaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ParRecusaEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'saida_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.saidaId = valueDes;
          break;
        case r'entrada_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.entradaId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ParRecusaEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ParRecusaEntradaBuilder();
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


