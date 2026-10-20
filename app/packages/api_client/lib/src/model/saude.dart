//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'saude.g.dart';

/// Saude
///
/// Properties:
/// * [status] 
@BuiltValue()
abstract class Saude implements Built<Saude, SaudeBuilder> {
  @BuiltValueField(wireName: r'status')
  String get status;

  Saude._();

  factory Saude([void updates(SaudeBuilder b)]) = _$Saude;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SaudeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Saude> get serializer => _$SaudeSerializer();
}

class _$SaudeSerializer implements PrimitiveSerializer<Saude> {
  @override
  final Iterable<Type> types = const [Saude, _$Saude];

  @override
  final String wireName = r'Saude';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Saude object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Saude object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SaudeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Saude deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SaudeBuilder();
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


