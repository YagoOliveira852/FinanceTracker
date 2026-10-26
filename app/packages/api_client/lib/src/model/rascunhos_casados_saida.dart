//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/exemplo_rascunho.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'rascunhos_casados_saida.g.dart';

/// RascunhosCasadosSaida
///
/// Properties:
/// * [quantidade] - Rascunhos sem categoria para os quais ela é a sugestão.
/// * [exemplo] - O mais recente deles.
@BuiltValue()
abstract class RascunhosCasadosSaida implements Built<RascunhosCasadosSaida, RascunhosCasadosSaidaBuilder> {
  /// Rascunhos sem categoria para os quais ela é a sugestão.
  @BuiltValueField(wireName: r'quantidade')
  int get quantidade;

  /// O mais recente deles.
  @BuiltValueField(wireName: r'exemplo')
  ExemploRascunho? get exemplo;

  RascunhosCasadosSaida._();

  factory RascunhosCasadosSaida([void updates(RascunhosCasadosSaidaBuilder b)]) = _$RascunhosCasadosSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RascunhosCasadosSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RascunhosCasadosSaida> get serializer => _$RascunhosCasadosSaidaSerializer();
}

class _$RascunhosCasadosSaidaSerializer implements PrimitiveSerializer<RascunhosCasadosSaida> {
  @override
  final Iterable<Type> types = const [RascunhosCasadosSaida, _$RascunhosCasadosSaida];

  @override
  final String wireName = r'RascunhosCasadosSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RascunhosCasadosSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'quantidade';
    yield serializers.serialize(
      object.quantidade,
      specifiedType: const FullType(int),
    );
    yield r'exemplo';
    yield object.exemplo == null ? null : serializers.serialize(
      object.exemplo,
      specifiedType: const FullType.nullable(ExemploRascunho),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RascunhosCasadosSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RascunhosCasadosSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'quantidade':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.quantidade = valueDes;
          break;
        case r'exemplo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ExemploRascunho),
          ) as ExemploRascunho?;
          if (valueDes == null) continue;
          result.exemplo.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RascunhosCasadosSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RascunhosCasadosSaidaBuilder();
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


