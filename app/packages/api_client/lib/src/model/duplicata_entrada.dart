//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/manter_duplicata.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'duplicata_entrada.g.dart';

/// DuplicataEntrada
///
/// Properties:
/// * [manter] - `rascunho`: fica o que chegou por último, confirmado no lugar da outra se ela estava confirmada; `outra`: fica a que já estava; `as_duas`: não é duplicata.
@BuiltValue()
abstract class DuplicataEntrada implements Built<DuplicataEntrada, DuplicataEntradaBuilder> {
  /// `rascunho`: fica o que chegou por último, confirmado no lugar da outra se ela estava confirmada; `outra`: fica a que já estava; `as_duas`: não é duplicata.
  @BuiltValueField(wireName: r'manter')
  ManterDuplicata get manter;
  // enum manterEnum {  rascunho,  outra,  as_duas,  };

  DuplicataEntrada._();

  factory DuplicataEntrada([void updates(DuplicataEntradaBuilder b)]) = _$DuplicataEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DuplicataEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DuplicataEntrada> get serializer => _$DuplicataEntradaSerializer();
}

class _$DuplicataEntradaSerializer implements PrimitiveSerializer<DuplicataEntrada> {
  @override
  final Iterable<Type> types = const [DuplicataEntrada, _$DuplicataEntrada];

  @override
  final String wireName = r'DuplicataEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DuplicataEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'manter';
    yield serializers.serialize(
      object.manter,
      specifiedType: const FullType(ManterDuplicata),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DuplicataEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DuplicataEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'manter':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ManterDuplicata),
          ) as ManterDuplicata;
          result.manter = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DuplicataEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DuplicataEntradaBuilder();
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


