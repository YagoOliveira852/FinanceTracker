//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'gasto_mensal_saida.g.dart';

/// GastoMensalSaida
///
/// Properties:
/// * [valor] 
/// * [automatico] - Média dos meses fechados (verdadeiro) ou valor fixo.
@BuiltValue()
abstract class GastoMensalSaida implements Built<GastoMensalSaida, GastoMensalSaidaBuilder> {
  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// Média dos meses fechados (verdadeiro) ou valor fixo.
  @BuiltValueField(wireName: r'automatico')
  bool get automatico;

  GastoMensalSaida._();

  factory GastoMensalSaida([void updates(GastoMensalSaidaBuilder b)]) = _$GastoMensalSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GastoMensalSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GastoMensalSaida> get serializer => _$GastoMensalSaidaSerializer();
}

class _$GastoMensalSaidaSerializer implements PrimitiveSerializer<GastoMensalSaida> {
  @override
  final Iterable<Type> types = const [GastoMensalSaida, _$GastoMensalSaida];

  @override
  final String wireName = r'GastoMensalSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GastoMensalSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'automatico';
    yield serializers.serialize(
      object.automatico,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GastoMensalSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GastoMensalSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'automatico':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.automatico = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GastoMensalSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GastoMensalSaidaBuilder();
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


