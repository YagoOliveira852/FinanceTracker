//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'configuracao_entrada.g.dart';

/// Os quatro campos vão sempre (o formulário manda tudo): `gasto_mensal_referencia` nulo = automático.
///
/// Properties:
/// * [colchao] - Fica na conta depois do aporte; não negativo.
/// * [metaReservaMeses] - Meta da reserva em meses de gasto; > 0.
/// * [gastoSemanalEstimado] - Piso dos gastos previstos; não negativo.
/// * [gastoMensalReferencia] - Valor fixo (> 0) que divide a reserva; nulo = média automática.
@BuiltValue()
abstract class ConfiguracaoEntrada implements Built<ConfiguracaoEntrada, ConfiguracaoEntradaBuilder> {
  /// Fica na conta depois do aporte; não negativo.
  @BuiltValueField(wireName: r'colchao')
  String get colchao;

  /// Meta da reserva em meses de gasto; > 0.
  @BuiltValueField(wireName: r'meta_reserva_meses')
  String get metaReservaMeses;

  /// Piso dos gastos previstos; não negativo.
  @BuiltValueField(wireName: r'gasto_semanal_estimado')
  String get gastoSemanalEstimado;

  /// Valor fixo (> 0) que divide a reserva; nulo = média automática.
  @BuiltValueField(wireName: r'gasto_mensal_referencia')
  String? get gastoMensalReferencia;

  ConfiguracaoEntrada._();

  factory ConfiguracaoEntrada([void updates(ConfiguracaoEntradaBuilder b)]) = _$ConfiguracaoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConfiguracaoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConfiguracaoEntrada> get serializer => _$ConfiguracaoEntradaSerializer();
}

class _$ConfiguracaoEntradaSerializer implements PrimitiveSerializer<ConfiguracaoEntrada> {
  @override
  final Iterable<Type> types = const [ConfiguracaoEntrada, _$ConfiguracaoEntrada];

  @override
  final String wireName = r'ConfiguracaoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConfiguracaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'colchao';
    yield serializers.serialize(
      object.colchao,
      specifiedType: const FullType(String),
    );
    yield r'meta_reserva_meses';
    yield serializers.serialize(
      object.metaReservaMeses,
      specifiedType: const FullType(String),
    );
    yield r'gasto_semanal_estimado';
    yield serializers.serialize(
      object.gastoSemanalEstimado,
      specifiedType: const FullType(String),
    );
    yield r'gasto_mensal_referencia';
    yield object.gastoMensalReferencia == null ? null : serializers.serialize(
      object.gastoMensalReferencia,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ConfiguracaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConfiguracaoEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'colchao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.colchao = valueDes;
          break;
        case r'meta_reserva_meses':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.metaReservaMeses = valueDes;
          break;
        case r'gasto_semanal_estimado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.gastoSemanalEstimado = valueDes;
          break;
        case r'gasto_mensal_referencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.gastoMensalReferencia = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ConfiguracaoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConfiguracaoEntradaBuilder();
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


