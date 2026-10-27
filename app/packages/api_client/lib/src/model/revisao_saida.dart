//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/transacao_revisao.dart';
import 'package:api_client/src/model/duplicata_saida.dart';
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/rascunho_saida.dart';
import 'package:api_client/src/model/par_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revisao_saida.g.dart';

/// RevisaoSaida
///
/// Properties:
/// * [total] - Linhas para revisar (um par conta 1): o contador da aba.
/// * [qtdSugeridos] - Rascunhos comuns com categoria sugerida (o lote).
/// * [pares] 
/// * [pagamentos] - Pagamentos de fatura das fontes.
/// * [duplicatas] 
/// * [sumidas] - Confirmadas que sumiram da origem.
/// * [rascunhos] - Os comuns, da data mais recente.
@BuiltValue()
abstract class RevisaoSaida implements Built<RevisaoSaida, RevisaoSaidaBuilder> {
  /// Linhas para revisar (um par conta 1): o contador da aba.
  @BuiltValueField(wireName: r'total')
  int get total;

  /// Rascunhos comuns com categoria sugerida (o lote).
  @BuiltValueField(wireName: r'qtd_sugeridos')
  int get qtdSugeridos;

  @BuiltValueField(wireName: r'pares')
  BuiltList<ParSaida> get pares;

  /// Pagamentos de fatura das fontes.
  @BuiltValueField(wireName: r'pagamentos')
  BuiltList<TransacaoRevisao> get pagamentos;

  @BuiltValueField(wireName: r'duplicatas')
  BuiltList<DuplicataSaida> get duplicatas;

  /// Confirmadas que sumiram da origem.
  @BuiltValueField(wireName: r'sumidas')
  BuiltList<TransacaoRevisao> get sumidas;

  /// Os comuns, da data mais recente.
  @BuiltValueField(wireName: r'rascunhos')
  BuiltList<RascunhoSaida> get rascunhos;

  RevisaoSaida._();

  factory RevisaoSaida([void updates(RevisaoSaidaBuilder b)]) = _$RevisaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevisaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevisaoSaida> get serializer => _$RevisaoSaidaSerializer();
}

class _$RevisaoSaidaSerializer implements PrimitiveSerializer<RevisaoSaida> {
  @override
  final Iterable<Type> types = const [RevisaoSaida, _$RevisaoSaida];

  @override
  final String wireName = r'RevisaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevisaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'total';
    yield serializers.serialize(
      object.total,
      specifiedType: const FullType(int),
    );
    yield r'qtd_sugeridos';
    yield serializers.serialize(
      object.qtdSugeridos,
      specifiedType: const FullType(int),
    );
    yield r'pares';
    yield serializers.serialize(
      object.pares,
      specifiedType: const FullType(BuiltList, [FullType(ParSaida)]),
    );
    yield r'pagamentos';
    yield serializers.serialize(
      object.pagamentos,
      specifiedType: const FullType(BuiltList, [FullType(TransacaoRevisao)]),
    );
    yield r'duplicatas';
    yield serializers.serialize(
      object.duplicatas,
      specifiedType: const FullType(BuiltList, [FullType(DuplicataSaida)]),
    );
    yield r'sumidas';
    yield serializers.serialize(
      object.sumidas,
      specifiedType: const FullType(BuiltList, [FullType(TransacaoRevisao)]),
    );
    yield r'rascunhos';
    yield serializers.serialize(
      object.rascunhos,
      specifiedType: const FullType(BuiltList, [FullType(RascunhoSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevisaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RevisaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.total = valueDes;
          break;
        case r'qtd_sugeridos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdSugeridos = valueDes;
          break;
        case r'pares':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ParSaida)]),
          ) as BuiltList<ParSaida>;
          result.pares.replace(valueDes);
          break;
        case r'pagamentos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TransacaoRevisao)]),
          ) as BuiltList<TransacaoRevisao>;
          result.pagamentos.replace(valueDes);
          break;
        case r'duplicatas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(DuplicataSaida)]),
          ) as BuiltList<DuplicataSaida>;
          result.duplicatas.replace(valueDes);
          break;
        case r'sumidas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TransacaoRevisao)]),
          ) as BuiltList<TransacaoRevisao>;
          result.sumidas.replace(valueDes);
          break;
        case r'rascunhos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(RascunhoSaida)]),
          ) as BuiltList<RascunhoSaida>;
          result.rascunhos.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RevisaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevisaoSaidaBuilder();
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


