//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/configuracao_valores.dart';
import 'package:api_client/src/model/gasto_mensal_automatico_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'configuracao_saida.g.dart';

/// ConfiguracaoSaida
///
/// Properties:
/// * [configuracao] - Nula até o primeiro salvamento: sem ela, o aporte não é calculado.
/// * [gastoMensalAutomatico] - Média dos 3 últimos meses fechados inteiros no histórico, mesmo com valor fixo salvo; nula sem nenhum.
/// * [mediaSemanalReal] - Gasto médio por semana nas últimas 8 semanas; nula com menos de 4.
/// * [mesesDeReserva] - Quantos meses a reserva cobre hoje, pelo gasto mensal que vale (o fixo ou o automático); nulo sem ele.
@BuiltValue()
abstract class ConfiguracaoSaida implements Built<ConfiguracaoSaida, ConfiguracaoSaidaBuilder> {
  /// Nula até o primeiro salvamento: sem ela, o aporte não é calculado.
  @BuiltValueField(wireName: r'configuracao')
  ConfiguracaoValores? get configuracao;

  /// Média dos 3 últimos meses fechados inteiros no histórico, mesmo com valor fixo salvo; nula sem nenhum.
  @BuiltValueField(wireName: r'gasto_mensal_automatico')
  GastoMensalAutomaticoSaida? get gastoMensalAutomatico;

  /// Gasto médio por semana nas últimas 8 semanas; nula com menos de 4.
  @BuiltValueField(wireName: r'media_semanal_real')
  String? get mediaSemanalReal;

  /// Quantos meses a reserva cobre hoje, pelo gasto mensal que vale (o fixo ou o automático); nulo sem ele.
  @BuiltValueField(wireName: r'meses_de_reserva')
  String? get mesesDeReserva;

  ConfiguracaoSaida._();

  factory ConfiguracaoSaida([void updates(ConfiguracaoSaidaBuilder b)]) = _$ConfiguracaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConfiguracaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConfiguracaoSaida> get serializer => _$ConfiguracaoSaidaSerializer();
}

class _$ConfiguracaoSaidaSerializer implements PrimitiveSerializer<ConfiguracaoSaida> {
  @override
  final Iterable<Type> types = const [ConfiguracaoSaida, _$ConfiguracaoSaida];

  @override
  final String wireName = r'ConfiguracaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConfiguracaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'configuracao';
    yield object.configuracao == null ? null : serializers.serialize(
      object.configuracao,
      specifiedType: const FullType.nullable(ConfiguracaoValores),
    );
    yield r'gasto_mensal_automatico';
    yield object.gastoMensalAutomatico == null ? null : serializers.serialize(
      object.gastoMensalAutomatico,
      specifiedType: const FullType.nullable(GastoMensalAutomaticoSaida),
    );
    yield r'media_semanal_real';
    yield object.mediaSemanalReal == null ? null : serializers.serialize(
      object.mediaSemanalReal,
      specifiedType: const FullType.nullable(String),
    );
    yield r'meses_de_reserva';
    yield object.mesesDeReserva == null ? null : serializers.serialize(
      object.mesesDeReserva,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ConfiguracaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConfiguracaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'configuracao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ConfiguracaoValores),
          ) as ConfiguracaoValores?;
          if (valueDes == null) continue;
          result.configuracao.replace(valueDes);
          break;
        case r'gasto_mensal_automatico':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(GastoMensalAutomaticoSaida),
          ) as GastoMensalAutomaticoSaida?;
          if (valueDes == null) continue;
          result.gastoMensalAutomatico.replace(valueDes);
          break;
        case r'media_semanal_real':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.mediaSemanalReal = valueDes;
          break;
        case r'meses_de_reserva':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.mesesDeReserva = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ConfiguracaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConfiguracaoSaidaBuilder();
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


