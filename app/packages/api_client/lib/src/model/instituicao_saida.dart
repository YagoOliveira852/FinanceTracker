//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'instituicao_saida.g.dart';

/// InstituicaoSaida
///
/// Properties:
/// * [id] 
/// * [nome] 
@BuiltValue()
abstract class InstituicaoSaida implements Built<InstituicaoSaida, InstituicaoSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  InstituicaoSaida._();

  factory InstituicaoSaida([void updates(InstituicaoSaidaBuilder b)]) = _$InstituicaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InstituicaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InstituicaoSaida> get serializer => _$InstituicaoSaidaSerializer();
}

class _$InstituicaoSaidaSerializer implements PrimitiveSerializer<InstituicaoSaida> {
  @override
  final Iterable<Type> types = const [InstituicaoSaida, _$InstituicaoSaida];

  @override
  final String wireName = r'InstituicaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InstituicaoSaida object, {
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
    InstituicaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required InstituicaoSaidaBuilder result,
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
  InstituicaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InstituicaoSaidaBuilder();
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


