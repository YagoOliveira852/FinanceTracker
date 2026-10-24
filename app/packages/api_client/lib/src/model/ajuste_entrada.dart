//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'ajuste_entrada.g.dart';

/// AjusteEntrada
///
/// Properties:
/// * [valorReal] - O total que o banco cobra; não negativo.
/// * [descricao] - A causa da diferença; sem ela, \"Ajuste da fatura\".
@BuiltValue()
abstract class AjusteEntrada implements Built<AjusteEntrada, AjusteEntradaBuilder> {
  /// O total que o banco cobra; não negativo.
  @BuiltValueField(wireName: r'valor_real')
  String get valorReal;

  /// A causa da diferença; sem ela, \"Ajuste da fatura\".
  @BuiltValueField(wireName: r'descricao')
  String? get descricao;

  AjusteEntrada._();

  factory AjusteEntrada([void updates(AjusteEntradaBuilder b)]) = _$AjusteEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AjusteEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AjusteEntrada> get serializer => _$AjusteEntradaSerializer();
}

class _$AjusteEntradaSerializer implements PrimitiveSerializer<AjusteEntrada> {
  @override
  final Iterable<Type> types = const [AjusteEntrada, _$AjusteEntrada];

  @override
  final String wireName = r'AjusteEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AjusteEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'valor_real';
    yield serializers.serialize(
      object.valorReal,
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
    AjusteEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AjusteEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'valor_real':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valorReal = valueDes;
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
  AjusteEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AjusteEntradaBuilder();
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


