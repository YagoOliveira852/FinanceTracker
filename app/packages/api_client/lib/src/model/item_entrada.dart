//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'item_entrada.g.dart';

/// ItemEntrada
///
/// Properties:
/// * [itemId] - ID do item MeuPluggy.
@BuiltValue()
abstract class ItemEntrada implements Built<ItemEntrada, ItemEntradaBuilder> {
  /// ID do item MeuPluggy.
  @BuiltValueField(wireName: r'item_id')
  String get itemId;

  ItemEntrada._();

  factory ItemEntrada([void updates(ItemEntradaBuilder b)]) = _$ItemEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ItemEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ItemEntrada> get serializer => _$ItemEntradaSerializer();
}

class _$ItemEntradaSerializer implements PrimitiveSerializer<ItemEntrada> {
  @override
  final Iterable<Type> types = const [ItemEntrada, _$ItemEntrada];

  @override
  final String wireName = r'ItemEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ItemEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'item_id';
    yield serializers.serialize(
      object.itemId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ItemEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ItemEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'item_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.itemId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ItemEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ItemEntradaBuilder();
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


