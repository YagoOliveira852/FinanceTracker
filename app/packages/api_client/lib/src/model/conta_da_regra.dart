//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_da_regra.g.dart';

/// ContaDaRegra
///
/// Properties:
/// * [id] 
/// * [nome] 
@BuiltValue()
abstract class ContaDaRegra implements Built<ContaDaRegra, ContaDaRegraBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  ContaDaRegra._();

  factory ContaDaRegra([void updates(ContaDaRegraBuilder b)]) = _$ContaDaRegra;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaDaRegraBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaDaRegra> get serializer => _$ContaDaRegraSerializer();
}

class _$ContaDaRegraSerializer implements PrimitiveSerializer<ContaDaRegra> {
  @override
  final Iterable<Type> types = const [ContaDaRegra, _$ContaDaRegra];

  @override
  final String wireName = r'ContaDaRegra';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaDaRegra object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    ContaDaRegra object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaDaRegraBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContaDaRegra deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaDaRegraBuilder();
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


