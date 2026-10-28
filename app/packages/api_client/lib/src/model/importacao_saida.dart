//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/fatura_da_importacao.dart';
import 'package:api_client/src/model/conta_da_importacao.dart';
import 'package:api_client/src/model/saldo_extrato_saida.dart';
import 'package:api_client/src/model/fonte_importacao.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'importacao_saida.g.dart';

/// ImportacaoSaida
///
/// Properties:
/// * [id] 
/// * [criadoEm] 
/// * [nomeArquivo] 
/// * [fonte] 
/// * [conta] 
/// * [periodoInicio] 
/// * [periodoFim] 
/// * [qtdNovas] - Entraram como rascunho (sem as possíveis duplicatas).
/// * [qtdPossiveisDuplicatas] - Entraram como rascunho, marcadas.
/// * [qtdJaImportadas] - Já estavam no app; ficaram de fora.
/// * [qtdParcelas] - Parcelas, com a data da compra estimada.
/// * [qtdConfirmadas] - Transações desta importação já confirmadas.
/// * [qtdPendentes] - Transações desta importação ainda na revisão.
/// * [podeDesfazer] - Nenhuma transação desta importação foi confirmada.
/// * [saldoExtrato] - Só no extrato da conta.
/// * [fatura] - Só na fatura do cartão.
@BuiltValue()
abstract class ImportacaoSaida implements Built<ImportacaoSaida, ImportacaoSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'criado_em')
  DateTime get criadoEm;

  @BuiltValueField(wireName: r'nome_arquivo')
  String? get nomeArquivo;

  @BuiltValueField(wireName: r'fonte')
  FonteImportacao get fonte;
  // enum fonteEnum {  ofx,  csv_mercadopago,  pluggy,  };

  @BuiltValueField(wireName: r'conta')
  ContaDaImportacao? get conta;

  @BuiltValueField(wireName: r'periodo_inicio')
  Date? get periodoInicio;

  @BuiltValueField(wireName: r'periodo_fim')
  Date? get periodoFim;

  /// Entraram como rascunho (sem as possíveis duplicatas).
  @BuiltValueField(wireName: r'qtd_novas')
  int get qtdNovas;

  /// Entraram como rascunho, marcadas.
  @BuiltValueField(wireName: r'qtd_possiveis_duplicatas')
  int get qtdPossiveisDuplicatas;

  /// Já estavam no app; ficaram de fora.
  @BuiltValueField(wireName: r'qtd_ja_importadas')
  int get qtdJaImportadas;

  /// Parcelas, com a data da compra estimada.
  @BuiltValueField(wireName: r'qtd_parcelas')
  int get qtdParcelas;

  /// Transações desta importação já confirmadas.
  @BuiltValueField(wireName: r'qtd_confirmadas')
  int get qtdConfirmadas;

  /// Transações desta importação ainda na revisão.
  @BuiltValueField(wireName: r'qtd_pendentes')
  int get qtdPendentes;

  /// Nenhuma transação desta importação foi confirmada.
  @BuiltValueField(wireName: r'pode_desfazer')
  bool get podeDesfazer;

  /// Só no extrato da conta.
  @BuiltValueField(wireName: r'saldo_extrato')
  SaldoExtratoSaida? get saldoExtrato;

  /// Só na fatura do cartão.
  @BuiltValueField(wireName: r'fatura')
  FaturaDaImportacao? get fatura;

  ImportacaoSaida._();

  factory ImportacaoSaida([void updates(ImportacaoSaidaBuilder b)]) = _$ImportacaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ImportacaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ImportacaoSaida> get serializer => _$ImportacaoSaidaSerializer();
}

class _$ImportacaoSaidaSerializer implements PrimitiveSerializer<ImportacaoSaida> {
  @override
  final Iterable<Type> types = const [ImportacaoSaida, _$ImportacaoSaida];

  @override
  final String wireName = r'ImportacaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ImportacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'criado_em';
    yield serializers.serialize(
      object.criadoEm,
      specifiedType: const FullType(DateTime),
    );
    yield r'nome_arquivo';
    yield object.nomeArquivo == null ? null : serializers.serialize(
      object.nomeArquivo,
      specifiedType: const FullType.nullable(String),
    );
    yield r'fonte';
    yield serializers.serialize(
      object.fonte,
      specifiedType: const FullType(FonteImportacao),
    );
    yield r'conta';
    yield object.conta == null ? null : serializers.serialize(
      object.conta,
      specifiedType: const FullType.nullable(ContaDaImportacao),
    );
    yield r'periodo_inicio';
    yield object.periodoInicio == null ? null : serializers.serialize(
      object.periodoInicio,
      specifiedType: const FullType.nullable(Date),
    );
    yield r'periodo_fim';
    yield object.periodoFim == null ? null : serializers.serialize(
      object.periodoFim,
      specifiedType: const FullType.nullable(Date),
    );
    yield r'qtd_novas';
    yield serializers.serialize(
      object.qtdNovas,
      specifiedType: const FullType(int),
    );
    yield r'qtd_possiveis_duplicatas';
    yield serializers.serialize(
      object.qtdPossiveisDuplicatas,
      specifiedType: const FullType(int),
    );
    yield r'qtd_ja_importadas';
    yield serializers.serialize(
      object.qtdJaImportadas,
      specifiedType: const FullType(int),
    );
    yield r'qtd_parcelas';
    yield serializers.serialize(
      object.qtdParcelas,
      specifiedType: const FullType(int),
    );
    yield r'qtd_confirmadas';
    yield serializers.serialize(
      object.qtdConfirmadas,
      specifiedType: const FullType(int),
    );
    yield r'qtd_pendentes';
    yield serializers.serialize(
      object.qtdPendentes,
      specifiedType: const FullType(int),
    );
    yield r'pode_desfazer';
    yield serializers.serialize(
      object.podeDesfazer,
      specifiedType: const FullType(bool),
    );
    yield r'saldo_extrato';
    yield object.saldoExtrato == null ? null : serializers.serialize(
      object.saldoExtrato,
      specifiedType: const FullType.nullable(SaldoExtratoSaida),
    );
    yield r'fatura';
    yield object.fatura == null ? null : serializers.serialize(
      object.fatura,
      specifiedType: const FullType.nullable(FaturaDaImportacao),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ImportacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ImportacaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'criado_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.criadoEm = valueDes;
          break;
        case r'nome_arquivo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.nomeArquivo = valueDes;
          break;
        case r'fonte':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(FonteImportacao),
          ) as FonteImportacao;
          result.fonte = valueDes;
          break;
        case r'conta':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ContaDaImportacao),
          ) as ContaDaImportacao?;
          if (valueDes == null) continue;
          result.conta.replace(valueDes);
          break;
        case r'periodo_inicio':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(Date),
          ) as Date?;
          if (valueDes == null) continue;
          result.periodoInicio = valueDes;
          break;
        case r'periodo_fim':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(Date),
          ) as Date?;
          if (valueDes == null) continue;
          result.periodoFim = valueDes;
          break;
        case r'qtd_novas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdNovas = valueDes;
          break;
        case r'qtd_possiveis_duplicatas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdPossiveisDuplicatas = valueDes;
          break;
        case r'qtd_ja_importadas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdJaImportadas = valueDes;
          break;
        case r'qtd_parcelas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdParcelas = valueDes;
          break;
        case r'qtd_confirmadas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdConfirmadas = valueDes;
          break;
        case r'qtd_pendentes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdPendentes = valueDes;
          break;
        case r'pode_desfazer':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.podeDesfazer = valueDes;
          break;
        case r'saldo_extrato':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(SaldoExtratoSaida),
          ) as SaldoExtratoSaida?;
          if (valueDes == null) continue;
          result.saldoExtrato.replace(valueDes);
          break;
        case r'fatura':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(FaturaDaImportacao),
          ) as FaturaDaImportacao?;
          if (valueDes == null) continue;
          result.fatura.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ImportacaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ImportacaoSaidaBuilder();
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


