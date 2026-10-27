//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'lote_saida.g.dart';

/// LoteSaida
///
/// Properties:
/// * [confirmados] - Os que ainda tinham sugestão e foram confirmados.
@BuiltValue()
abstract class LoteSaida implements Built<LoteSaida, LoteSaidaBuilder> {
  /// Os que ainda tinham sugestão e foram confirmados.
  @BuiltValueField(wireName: r'confirmados')
  int get confirmados;

  LoteSaida._();

  factory LoteSaida([void updates(LoteSaidaBuilder b)]) = _$LoteSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LoteSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LoteSaida> get serializer => _$LoteSaidaSerializer();
}

class _$LoteSaidaSerializer implements PrimitiveSerializer<LoteSaida> {
  @override
  final Iterable<Type> types = const [LoteSaida, _$LoteSaida];

  @override
  final String wireName = r'LoteSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LoteSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'confirmados';
    yield serializers.serialize(
      object.confirmados,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LoteSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LoteSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'confirmados':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.confirmados = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LoteSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LoteSaidaBuilder();
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


