//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'login_entrada.g.dart';

/// LoginEntrada
///
/// Properties:
/// * [email] 
/// * [senha] 
@BuiltValue()
abstract class LoginEntrada implements Built<LoginEntrada, LoginEntradaBuilder> {
  @BuiltValueField(wireName: r'email')
  String get email;

  @BuiltValueField(wireName: r'senha')
  String get senha;

  LoginEntrada._();

  factory LoginEntrada([void updates(LoginEntradaBuilder b)]) = _$LoginEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LoginEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LoginEntrada> get serializer => _$LoginEntradaSerializer();
}

class _$LoginEntradaSerializer implements PrimitiveSerializer<LoginEntrada> {
  @override
  final Iterable<Type> types = const [LoginEntrada, _$LoginEntrada];

  @override
  final String wireName = r'LoginEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LoginEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'email';
    yield serializers.serialize(
      object.email,
      specifiedType: const FullType(String),
    );
    yield r'senha';
    yield serializers.serialize(
      object.senha,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LoginEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LoginEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.email = valueDes;
          break;
        case r'senha':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.senha = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LoginEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LoginEntradaBuilder();
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


