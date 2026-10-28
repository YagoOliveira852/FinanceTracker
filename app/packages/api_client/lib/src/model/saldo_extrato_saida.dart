//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'saldo_extrato_saida.g.dart';

/// SaldoExtratoSaida
///
/// Properties:
/// * [valor] - Saldo final do extrato (`LEDGERBAL`).
/// * [data] 
@BuiltValue()
abstract class SaldoExtratoSaida implements Built<SaldoExtratoSaida, SaldoExtratoSaidaBuilder> {
  /// Saldo final do extrato (`LEDGERBAL`).
  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'data')
  Date get data;

  SaldoExtratoSaida._();

  factory SaldoExtratoSaida([void updates(SaldoExtratoSaidaBuilder b)]) = _$SaldoExtratoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SaldoExtratoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SaldoExtratoSaida> get serializer => _$SaldoExtratoSaidaSerializer();
}

class _$SaldoExtratoSaidaSerializer implements PrimitiveSerializer<SaldoExtratoSaida> {
  @override
  final Iterable<Type> types = const [SaldoExtratoSaida, _$SaldoExtratoSaida];

  @override
  final String wireName = r'SaldoExtratoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SaldoExtratoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(Date),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SaldoExtratoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SaldoExtratoSaidaBuilder result,
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
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.data = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SaldoExtratoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SaldoExtratoSaidaBuilder();
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


