//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/gasto_mensal_saida.dart';
import 'package:api_client/src/model/previsao_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resumo_saida.g.dart';

/// ResumoSaida
///
/// Properties:
/// * [saldoDisponivel] - Correntes e carteiras ativas, com rascunhos e sem possíveis duplicatas.
/// * [rascunhos] - Rascunhos que o cálculo considera (sem as possíveis duplicatas).
/// * [previsao] - Nula sem renda prevista ativa ou sem configuração salva.
/// * [gastoMensal] - Gasto mensal de referência; nulo sem valor fixo nem mês fechado no histórico.
/// * [metaReservaMeses] - Nula sem configuração salva.
@BuiltValue()
abstract class ResumoSaida implements Built<ResumoSaida, ResumoSaidaBuilder> {
  /// Correntes e carteiras ativas, com rascunhos e sem possíveis duplicatas.
  @BuiltValueField(wireName: r'saldo_disponivel')
  String get saldoDisponivel;

  /// Rascunhos que o cálculo considera (sem as possíveis duplicatas).
  @BuiltValueField(wireName: r'rascunhos')
  int get rascunhos;

  /// Nula sem renda prevista ativa ou sem configuração salva.
  @BuiltValueField(wireName: r'previsao')
  PrevisaoSaida? get previsao;

  /// Gasto mensal de referência; nulo sem valor fixo nem mês fechado no histórico.
  @BuiltValueField(wireName: r'gasto_mensal')
  GastoMensalSaida? get gastoMensal;

  /// Nula sem configuração salva.
  @BuiltValueField(wireName: r'meta_reserva_meses')
  String? get metaReservaMeses;

  ResumoSaida._();

  factory ResumoSaida([void updates(ResumoSaidaBuilder b)]) = _$ResumoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResumoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResumoSaida> get serializer => _$ResumoSaidaSerializer();
}

class _$ResumoSaidaSerializer implements PrimitiveSerializer<ResumoSaida> {
  @override
  final Iterable<Type> types = const [ResumoSaida, _$ResumoSaida];

  @override
  final String wireName = r'ResumoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResumoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'saldo_disponivel';
    yield serializers.serialize(
      object.saldoDisponivel,
      specifiedType: const FullType(String),
    );
    yield r'rascunhos';
    yield serializers.serialize(
      object.rascunhos,
      specifiedType: const FullType(int),
    );
    yield r'previsao';
    yield object.previsao == null ? null : serializers.serialize(
      object.previsao,
      specifiedType: const FullType.nullable(PrevisaoSaida),
    );
    yield r'gasto_mensal';
    yield object.gastoMensal == null ? null : serializers.serialize(
      object.gastoMensal,
      specifiedType: const FullType.nullable(GastoMensalSaida),
    );
    yield r'meta_reserva_meses';
    yield object.metaReservaMeses == null ? null : serializers.serialize(
      object.metaReservaMeses,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResumoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ResumoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'saldo_disponivel':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.saldoDisponivel = valueDes;
          break;
        case r'rascunhos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.rascunhos = valueDes;
          break;
        case r'previsao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PrevisaoSaida),
          ) as PrevisaoSaida?;
          if (valueDes == null) continue;
          result.previsao.replace(valueDes);
          break;
        case r'gasto_mensal':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(GastoMensalSaida),
          ) as GastoMensalSaida?;
          if (valueDes == null) continue;
          result.gastoMensal.replace(valueDes);
          break;
        case r'meta_reserva_meses':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.metaReservaMeses = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResumoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResumoSaidaBuilder();
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


