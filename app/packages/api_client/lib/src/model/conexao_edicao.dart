//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conexao_edicao.g.dart';

/// ConexaoEdicao
///
/// Properties:
/// * [ativa] 
@BuiltValue()
abstract class ConexaoEdicao implements Built<ConexaoEdicao, ConexaoEdicaoBuilder> {
  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  ConexaoEdicao._();

  factory ConexaoEdicao([void updates(ConexaoEdicaoBuilder b)]) = _$ConexaoEdicao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConexaoEdicaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConexaoEdicao> get serializer => _$ConexaoEdicaoSerializer();
}

class _$ConexaoEdicaoSerializer implements PrimitiveSerializer<ConexaoEdicao> {
  @override
  final Iterable<Type> types = const [ConexaoEdicao, _$ConexaoEdicao];

  @override
  final String wireName = r'ConexaoEdicao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConexaoEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'ativa';
    yield serializers.serialize(
      object.ativa,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ConexaoEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConexaoEdicaoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'ativa':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ativa = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ConexaoEdicao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConexaoEdicaoBuilder();
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


