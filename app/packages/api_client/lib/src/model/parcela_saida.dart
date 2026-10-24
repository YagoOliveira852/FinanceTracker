//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'parcela_saida.g.dart';

/// ParcelaSaida
///
/// Properties:
/// * [compraParceladaId] 
/// * [numero] 
/// * [total] 
@BuiltValue()
abstract class ParcelaSaida implements Built<ParcelaSaida, ParcelaSaidaBuilder> {
  @BuiltValueField(wireName: r'compra_parcelada_id')
  String get compraParceladaId;

  @BuiltValueField(wireName: r'numero')
  int get numero;

  @BuiltValueField(wireName: r'total')
  int get total;

  ParcelaSaida._();

  factory ParcelaSaida([void updates(ParcelaSaidaBuilder b)]) = _$ParcelaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ParcelaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ParcelaSaida> get serializer => _$ParcelaSaidaSerializer();
}

class _$ParcelaSaidaSerializer implements PrimitiveSerializer<ParcelaSaida> {
  @override
  final Iterable<Type> types = const [ParcelaSaida, _$ParcelaSaida];

  @override
  final String wireName = r'ParcelaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ParcelaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'compra_parcelada_id';
    yield serializers.serialize(
      object.compraParceladaId,
      specifiedType: const FullType(String),
    );
    yield r'numero';
    yield serializers.serialize(
      object.numero,
      specifiedType: const FullType(int),
    );
    yield r'total';
    yield serializers.serialize(
      object.total,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ParcelaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ParcelaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'compra_parcelada_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.compraParceladaId = valueDes;
          break;
        case r'numero':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.numero = valueDes;
          break;
        case r'total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.total = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ParcelaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ParcelaSaidaBuilder();
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


