//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'exemplo_rascunho.g.dart';

/// ExemploRascunho
///
/// Properties:
/// * [descricao] 
/// * [data] 
@BuiltValue()
abstract class ExemploRascunho implements Built<ExemploRascunho, ExemploRascunhoBuilder> {
  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  @BuiltValueField(wireName: r'data')
  Date get data;

  ExemploRascunho._();

  factory ExemploRascunho([void updates(ExemploRascunhoBuilder b)]) = _$ExemploRascunho;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExemploRascunhoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExemploRascunho> get serializer => _$ExemploRascunhoSerializer();
}

class _$ExemploRascunhoSerializer implements PrimitiveSerializer<ExemploRascunho> {
  @override
  final Iterable<Type> types = const [ExemploRascunho, _$ExemploRascunho];

  @override
  final String wireName = r'ExemploRascunho';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExemploRascunho object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
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
    ExemploRascunho object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExemploRascunhoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
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
  ExemploRascunho deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExemploRascunhoBuilder();
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


