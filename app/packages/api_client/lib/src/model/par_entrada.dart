//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'par_entrada.g.dart';

/// ParEntrada
///
/// Properties:
/// * [saidaId] 
/// * [entradaId] 
/// * [descricao] - Vale para os dois lados; vazia mantém.
@BuiltValue()
abstract class ParEntrada implements Built<ParEntrada, ParEntradaBuilder> {
  @BuiltValueField(wireName: r'saida_id')
  String get saidaId;

  @BuiltValueField(wireName: r'entrada_id')
  String get entradaId;

  /// Vale para os dois lados; vazia mantém.
  @BuiltValueField(wireName: r'descricao')
  String? get descricao;

  ParEntrada._();

  factory ParEntrada([void updates(ParEntradaBuilder b)]) = _$ParEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ParEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ParEntrada> get serializer => _$ParEntradaSerializer();
}

class _$ParEntradaSerializer implements PrimitiveSerializer<ParEntrada> {
  @override
  final Iterable<Type> types = const [ParEntrada, _$ParEntrada];

  @override
  final String wireName = r'ParEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ParEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'saida_id';
    yield serializers.serialize(
      object.saidaId,
      specifiedType: const FullType(String),
    );
    yield r'entrada_id';
    yield serializers.serialize(
      object.entradaId,
      specifiedType: const FullType(String),
    );
    if (object.descricao != null) {
      yield r'descricao';
      yield serializers.serialize(
        object.descricao,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ParEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ParEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'saida_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.saidaId = valueDes;
          break;
        case r'entrada_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.entradaId = valueDes;
          break;
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
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
  ParEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ParEntradaBuilder();
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


