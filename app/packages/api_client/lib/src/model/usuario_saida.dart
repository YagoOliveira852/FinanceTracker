//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'usuario_saida.g.dart';

/// UsuarioSaida
///
/// Properties:
/// * [id] 
/// * [email] 
@BuiltValue()
abstract class UsuarioSaida implements Built<UsuarioSaida, UsuarioSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'email')
  String get email;

  UsuarioSaida._();

  factory UsuarioSaida([void updates(UsuarioSaidaBuilder b)]) = _$UsuarioSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UsuarioSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UsuarioSaida> get serializer => _$UsuarioSaidaSerializer();
}

class _$UsuarioSaidaSerializer implements PrimitiveSerializer<UsuarioSaida> {
  @override
  final Iterable<Type> types = const [UsuarioSaida, _$UsuarioSaida];

  @override
  final String wireName = r'UsuarioSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UsuarioSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'email';
    yield serializers.serialize(
      object.email,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UsuarioSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UsuarioSaidaBuilder result,
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
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.email = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UsuarioSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UsuarioSaidaBuilder();
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


