//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/salario_recebido_saida.dart';
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/nivel_ritmo.dart';
import 'package:api_client/src/model/fatura_reservada_saida.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'previsao_saida.g.dart';

/// Projeção até o próximo salário; a sobra e o alerta são a mesma conta.
///
/// Properties:
/// * [proximoSalario] - Data efetiva do próximo salário ainda sem crédito (pode ser hoje ou já ter passado, enquanto a janela do atraso não acaba).
/// * [diasAteSalario] - Dias de gasto previsto: hoje entra, o do salário não.
/// * [faturas] - Faturas que vencem até o próximo salário, em ordem de vencimento.
/// * [gastosPrevistos] 
/// * [gastosPelaMedia] - A média real das últimas semanas passou do gasto semanal estimado.
/// * [sobra] - Saldo disponível − faturas − gastos previstos; pode ser negativa.
/// * [nivel] - verde: sobra ≥ colchão; amarelo: entre 0 e o colchão; vermelho: negativa.
/// * [colchao] 
/// * [salarioRecebido] - Salário detectado cuja janela ainda está aberta; nulo sem ele.
/// * [aporte] - Sobra − colchão, nunca negativo; só existe com o salário recebido.
@BuiltValue()
abstract class PrevisaoSaida implements Built<PrevisaoSaida, PrevisaoSaidaBuilder> {
  /// Data efetiva do próximo salário ainda sem crédito (pode ser hoje ou já ter passado, enquanto a janela do atraso não acaba).
  @BuiltValueField(wireName: r'proximo_salario')
  Date get proximoSalario;

  /// Dias de gasto previsto: hoje entra, o do salário não.
  @BuiltValueField(wireName: r'dias_ate_salario')
  int get diasAteSalario;

  /// Faturas que vencem até o próximo salário, em ordem de vencimento.
  @BuiltValueField(wireName: r'faturas')
  BuiltList<FaturaReservadaSaida> get faturas;

  @BuiltValueField(wireName: r'gastos_previstos')
  String get gastosPrevistos;

  /// A média real das últimas semanas passou do gasto semanal estimado.
  @BuiltValueField(wireName: r'gastos_pela_media')
  bool get gastosPelaMedia;

  /// Saldo disponível − faturas − gastos previstos; pode ser negativa.
  @BuiltValueField(wireName: r'sobra')
  String get sobra;

  /// verde: sobra ≥ colchão; amarelo: entre 0 e o colchão; vermelho: negativa.
  @BuiltValueField(wireName: r'nivel')
  NivelRitmo get nivel;
  // enum nivelEnum {  verde,  amarelo,  vermelho,  };

  @BuiltValueField(wireName: r'colchao')
  String get colchao;

  /// Salário detectado cuja janela ainda está aberta; nulo sem ele.
  @BuiltValueField(wireName: r'salario_recebido')
  SalarioRecebidoSaida? get salarioRecebido;

  /// Sobra − colchão, nunca negativo; só existe com o salário recebido.
  @BuiltValueField(wireName: r'aporte')
  String? get aporte;

  PrevisaoSaida._();

  factory PrevisaoSaida([void updates(PrevisaoSaidaBuilder b)]) = _$PrevisaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PrevisaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PrevisaoSaida> get serializer => _$PrevisaoSaidaSerializer();
}

class _$PrevisaoSaidaSerializer implements PrimitiveSerializer<PrevisaoSaida> {
  @override
  final Iterable<Type> types = const [PrevisaoSaida, _$PrevisaoSaida];

  @override
  final String wireName = r'PrevisaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PrevisaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'proximo_salario';
    yield serializers.serialize(
      object.proximoSalario,
      specifiedType: const FullType(Date),
    );
    yield r'dias_ate_salario';
    yield serializers.serialize(
      object.diasAteSalario,
      specifiedType: const FullType(int),
    );
    yield r'faturas';
    yield serializers.serialize(
      object.faturas,
      specifiedType: const FullType(BuiltList, [FullType(FaturaReservadaSaida)]),
    );
    yield r'gastos_previstos';
    yield serializers.serialize(
      object.gastosPrevistos,
      specifiedType: const FullType(String),
    );
    yield r'gastos_pela_media';
    yield serializers.serialize(
      object.gastosPelaMedia,
      specifiedType: const FullType(bool),
    );
    yield r'sobra';
    yield serializers.serialize(
      object.sobra,
      specifiedType: const FullType(String),
    );
    yield r'nivel';
    yield serializers.serialize(
      object.nivel,
      specifiedType: const FullType(NivelRitmo),
    );
    yield r'colchao';
    yield serializers.serialize(
      object.colchao,
      specifiedType: const FullType(String),
    );
    yield r'salario_recebido';
    yield object.salarioRecebido == null ? null : serializers.serialize(
      object.salarioRecebido,
      specifiedType: const FullType.nullable(SalarioRecebidoSaida),
    );
    yield r'aporte';
    yield object.aporte == null ? null : serializers.serialize(
      object.aporte,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PrevisaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PrevisaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'proximo_salario':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.proximoSalario = valueDes;
          break;
        case r'dias_ate_salario':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.diasAteSalario = valueDes;
          break;
        case r'faturas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(FaturaReservadaSaida)]),
          ) as BuiltList<FaturaReservadaSaida>;
          result.faturas.replace(valueDes);
          break;
        case r'gastos_previstos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.gastosPrevistos = valueDes;
          break;
        case r'gastos_pela_media':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.gastosPelaMedia = valueDes;
          break;
        case r'sobra':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.sobra = valueDes;
          break;
        case r'nivel':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(NivelRitmo),
          ) as NivelRitmo;
          result.nivel = valueDes;
          break;
        case r'colchao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.colchao = valueDes;
          break;
        case r'salario_recebido':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(SalarioRecebidoSaida),
          ) as SalarioRecebidoSaida?;
          if (valueDes == null) continue;
          result.salarioRecebido.replace(valueDes);
          break;
        case r'aporte':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.aporte = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PrevisaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PrevisaoSaidaBuilder();
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


