//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/status_fatura.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_resumo.g.dart';

/// Uma fatura: gravada ou, enquanto não recebeu transação nem foi editada, calculada pela regra do cartão.
///
/// Properties:
/// * [competencia] - Primeiro dia do mês do vencimento.
/// * [dataFechamento] 
/// * [dataVencimento] 
/// * [status] - Aberta antes do fechamento; fechada a partir dele.
/// * [valor] - O maior entre o informado e o calculado.
/// * [valorCalculado] - Compras menos estornos da fatura, com rascunhos e sem as ignoradas.
/// * [valorInformado] - O total que o banco mostra.
@BuiltValue()
abstract class FaturaResumo implements Built<FaturaResumo, FaturaResumoBuilder> {
  /// Primeiro dia do mês do vencimento.
  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  @BuiltValueField(wireName: r'data_fechamento')
  Date get dataFechamento;

  @BuiltValueField(wireName: r'data_vencimento')
  Date get dataVencimento;

  /// Aberta antes do fechamento; fechada a partir dele.
  @BuiltValueField(wireName: r'status')
  StatusFatura get status;
  // enum statusEnum {  aberta,  fechada,  };

  /// O maior entre o informado e o calculado.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// Compras menos estornos da fatura, com rascunhos e sem as ignoradas.
  @BuiltValueField(wireName: r'valor_calculado')
  String get valorCalculado;

  /// O total que o banco mostra.
  @BuiltValueField(wireName: r'valor_informado')
  String? get valorInformado;

  FaturaResumo._();

  factory FaturaResumo([void updates(FaturaResumoBuilder b)]) = _$FaturaResumo;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaResumoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaResumo> get serializer => _$FaturaResumoSerializer();
}

class _$FaturaResumoSerializer implements PrimitiveSerializer<FaturaResumo> {
  @override
  final Iterable<Type> types = const [FaturaResumo, _$FaturaResumo];

  @override
  final String wireName = r'FaturaResumo';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaResumo object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'competencia';
    yield serializers.serialize(
      object.competencia,
      specifiedType: const FullType(Date),
    );
    yield r'data_fechamento';
    yield serializers.serialize(
      object.dataFechamento,
      specifiedType: const FullType(Date),
    );
    yield r'data_vencimento';
    yield serializers.serialize(
      object.dataVencimento,
      specifiedType: const FullType(Date),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(StatusFatura),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'valor_calculado';
    yield serializers.serialize(
      object.valorCalculado,
      specifiedType: const FullType(String),
    );
    yield r'valor_informado';
    yield object.valorInformado == null ? null : serializers.serialize(
      object.valorInformado,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaResumo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaResumoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.competencia = valueDes;
          break;
        case r'data_fechamento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataFechamento = valueDes;
          break;
        case r'data_vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataVencimento = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(StatusFatura),
          ) as StatusFatura;
          result.status = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'valor_calculado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valorCalculado = valueDes;
          break;
        case r'valor_informado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.valorInformado = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaResumo deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaResumoBuilder();
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


