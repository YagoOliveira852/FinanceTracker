//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'gasto_mensal_automatico_saida.g.dart';

/// GastoMensalAutomaticoSaida
///
/// Properties:
/// * [valor] - Média do gasto (despesa − estorno) dos meses.
/// * [meses] - Meses fechados da média (1º dia), do mais antigo ao mais recente; até 3.
@BuiltValue()
abstract class GastoMensalAutomaticoSaida implements Built<GastoMensalAutomaticoSaida, GastoMensalAutomaticoSaidaBuilder> {
  /// Média do gasto (despesa − estorno) dos meses.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// Meses fechados da média (1º dia), do mais antigo ao mais recente; até 3.
  @BuiltValueField(wireName: r'meses')
  BuiltList<Date> get meses;

  GastoMensalAutomaticoSaida._();

  factory GastoMensalAutomaticoSaida([void updates(GastoMensalAutomaticoSaidaBuilder b)]) = _$GastoMensalAutomaticoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GastoMensalAutomaticoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GastoMensalAutomaticoSaida> get serializer => _$GastoMensalAutomaticoSaidaSerializer();
}

class _$GastoMensalAutomaticoSaidaSerializer implements PrimitiveSerializer<GastoMensalAutomaticoSaida> {
  @override
  final Iterable<Type> types = const [GastoMensalAutomaticoSaida, _$GastoMensalAutomaticoSaida];

  @override
  final String wireName = r'GastoMensalAutomaticoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GastoMensalAutomaticoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'meses';
    yield serializers.serialize(
      object.meses,
      specifiedType: const FullType(BuiltList, [FullType(Date)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GastoMensalAutomaticoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GastoMensalAutomaticoSaidaBuilder result,
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
        case r'meses':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(Date)]),
          ) as BuiltList<Date>;
          result.meses.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GastoMensalAutomaticoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GastoMensalAutomaticoSaidaBuilder();
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


