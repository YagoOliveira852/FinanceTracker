//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'refresh_entrada.g.dart';

/// RefreshEntrada
///
/// Properties:
/// * [refreshToken] 
@BuiltValue()
abstract class RefreshEntrada implements Built<RefreshEntrada, RefreshEntradaBuilder> {
  @BuiltValueField(wireName: r'refresh_token')
  String get refreshToken;

  RefreshEntrada._();

  factory RefreshEntrada([void updates(RefreshEntradaBuilder b)]) = _$RefreshEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RefreshEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RefreshEntrada> get serializer => _$RefreshEntradaSerializer();
}

class _$RefreshEntradaSerializer implements PrimitiveSerializer<RefreshEntrada> {
  @override
  final Iterable<Type> types = const [RefreshEntrada, _$RefreshEntrada];

  @override
  final String wireName = r'RefreshEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RefreshEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'refresh_token';
    yield serializers.serialize(
      object.refreshToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RefreshEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RefreshEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'refresh_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.refreshToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RefreshEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RefreshEntradaBuilder();
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


