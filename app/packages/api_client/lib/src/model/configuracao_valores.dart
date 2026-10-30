//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'configuracao_valores.g.dart';

/// ConfiguracaoValores
///
/// Properties:
/// * [colchao] 
/// * [metaReservaMeses] 
/// * [gastoSemanalEstimado] 
/// * [gastoMensalReferencia] - Nulo = automático.
@BuiltValue()
abstract class ConfiguracaoValores implements Built<ConfiguracaoValores, ConfiguracaoValoresBuilder> {
  @BuiltValueField(wireName: r'colchao')
  String get colchao;

  @BuiltValueField(wireName: r'meta_reserva_meses')
  String get metaReservaMeses;

  @BuiltValueField(wireName: r'gasto_semanal_estimado')
  String get gastoSemanalEstimado;

  /// Nulo = automático.
  @BuiltValueField(wireName: r'gasto_mensal_referencia')
  String? get gastoMensalReferencia;

  ConfiguracaoValores._();

  factory ConfiguracaoValores([void updates(ConfiguracaoValoresBuilder b)]) = _$ConfiguracaoValores;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConfiguracaoValoresBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConfiguracaoValores> get serializer => _$ConfiguracaoValoresSerializer();
}

class _$ConfiguracaoValoresSerializer implements PrimitiveSerializer<ConfiguracaoValores> {
  @override
  final Iterable<Type> types = const [ConfiguracaoValores, _$ConfiguracaoValores];

  @override
  final String wireName = r'ConfiguracaoValores';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConfiguracaoValores object, {
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
    ConfiguracaoValores object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConfiguracaoValoresBuilder result,
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
  ConfiguracaoValores deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConfiguracaoValoresBuilder();
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


