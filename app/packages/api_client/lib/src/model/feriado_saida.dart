//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'feriado_saida.g.dart';

/// FeriadoSaida
///
/// Properties:
/// * [data] 
/// * [descricao] 
@BuiltValue()
abstract class FeriadoSaida implements Built<FeriadoSaida, FeriadoSaidaBuilder> {
  @BuiltValueField(wireName: r'data')
  Date get data;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  FeriadoSaida._();

  factory FeriadoSaida([void updates(FeriadoSaidaBuilder b)]) = _$FeriadoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FeriadoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FeriadoSaida> get serializer => _$FeriadoSaidaSerializer();
}

class _$FeriadoSaidaSerializer implements PrimitiveSerializer<FeriadoSaida> {
  @override
  final Iterable<Type> types = const [FeriadoSaida, _$FeriadoSaida];

  @override
  final String wireName = r'FeriadoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FeriadoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(Date),
    );
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FeriadoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FeriadoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.data = valueDes;
          break;
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FeriadoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FeriadoSaidaBuilder();
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


