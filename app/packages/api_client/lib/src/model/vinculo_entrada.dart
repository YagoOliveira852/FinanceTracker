//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'vinculo_entrada.g.dart';

/// VinculoEntrada
///
/// Properties:
/// * [pluggyAccountId] 
/// * [contaId] - Conta do app a alimentar; nulo = criar nova.
@BuiltValue()
abstract class VinculoEntrada implements Built<VinculoEntrada, VinculoEntradaBuilder> {
  @BuiltValueField(wireName: r'pluggy_account_id')
  String get pluggyAccountId;

  /// Conta do app a alimentar; nulo = criar nova.
  @BuiltValueField(wireName: r'conta_id')
  String? get contaId;

  VinculoEntrada._();

  factory VinculoEntrada([void updates(VinculoEntradaBuilder b)]) = _$VinculoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(VinculoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<VinculoEntrada> get serializer => _$VinculoEntradaSerializer();
}

class _$VinculoEntradaSerializer implements PrimitiveSerializer<VinculoEntrada> {
  @override
  final Iterable<Type> types = const [VinculoEntrada, _$VinculoEntrada];

  @override
  final String wireName = r'VinculoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    VinculoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'pluggy_account_id';
    yield serializers.serialize(
      object.pluggyAccountId,
      specifiedType: const FullType(String),
    );
    yield r'conta_id';
    yield object.contaId == null ? null : serializers.serialize(
      object.contaId,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    VinculoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required VinculoEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'pluggy_account_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.pluggyAccountId = valueDes;
          break;
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.contaId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  VinculoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = VinculoEntradaBuilder();
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


