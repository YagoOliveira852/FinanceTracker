//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'lote_entrada.g.dart';

/// LoteEntrada
///
/// Properties:
/// * [ids] - Os rascunhos com sugestão que o app mostrou.
@BuiltValue()
abstract class LoteEntrada implements Built<LoteEntrada, LoteEntradaBuilder> {
  /// Os rascunhos com sugestão que o app mostrou.
  @BuiltValueField(wireName: r'ids')
  BuiltList<String> get ids;

  LoteEntrada._();

  factory LoteEntrada([void updates(LoteEntradaBuilder b)]) = _$LoteEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LoteEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LoteEntrada> get serializer => _$LoteEntradaSerializer();
}

class _$LoteEntradaSerializer implements PrimitiveSerializer<LoteEntrada> {
  @override
  final Iterable<Type> types = const [LoteEntrada, _$LoteEntrada];

  @override
  final String wireName = r'LoteEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LoteEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'ids';
    yield serializers.serialize(
      object.ids,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LoteEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LoteEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'ids':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.ids.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LoteEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LoteEntradaBuilder();
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


