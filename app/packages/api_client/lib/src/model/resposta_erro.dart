//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/erro_campo.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resposta_erro.g.dart';

/// RespostaErro
///
/// Properties:
/// * [detail] 
/// * [campos] 
@BuiltValue()
abstract class RespostaErro implements Built<RespostaErro, RespostaErroBuilder> {
  @BuiltValueField(wireName: r'detail')
  String get detail;

  @BuiltValueField(wireName: r'campos')
  BuiltList<ErroCampo>? get campos;

  RespostaErro._();

  factory RespostaErro([void updates(RespostaErroBuilder b)]) = _$RespostaErro;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RespostaErroBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RespostaErro> get serializer => _$RespostaErroSerializer();
}

class _$RespostaErroSerializer implements PrimitiveSerializer<RespostaErro> {
  @override
  final Iterable<Type> types = const [RespostaErro, _$RespostaErro];

  @override
  final String wireName = r'RespostaErro';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RespostaErro object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'detail';
    yield serializers.serialize(
      object.detail,
      specifiedType: const FullType(String),
    );
    if (object.campos != null) {
      yield r'campos';
      yield serializers.serialize(
        object.campos,
        specifiedType: const FullType.nullable(BuiltList, [FullType(ErroCampo)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    RespostaErro object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RespostaErroBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'detail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.detail = valueDes;
          break;
        case r'campos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(ErroCampo)]),
          ) as BuiltList<ErroCampo>?;
          if (valueDes == null) continue;
          result.campos.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RespostaErro deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RespostaErroBuilder();
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


