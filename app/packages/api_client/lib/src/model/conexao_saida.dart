//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/conta_do_app_saida.dart';
import 'package:api_client/src/model/problema.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conexao_saida.g.dart';

/// ConexaoSaida
///
/// Properties:
/// * [id] 
/// * [itemId] 
/// * [instituicao] - Nome do banco (do conector da Pluggy).
/// * [status] - Como a Pluggy informa o item (UPDATED, LOGIN_ERROR...).
/// * [ativa] 
/// * [consentimentoExpiraEm] 
/// * [ultimoSyncEm] - Último sync bem-sucedido.
/// * [ultimaTentativaEm] 
/// * [ultimoErro] - Em português; nulo depois de um sucesso.
/// * [proximoSync] - Próximo sync diário; nulo se desativada.
/// * [buscarAPartirDe] - Quando o Buscar agora volta a valer (1×/hora); nulo se já vale.
/// * [problema] - Só nas ativas; nulo quando está tudo bem.
/// * [contas] - Contas do app que a conexão alimenta.
@BuiltValue()
abstract class ConexaoSaida implements Built<ConexaoSaida, ConexaoSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'item_id')
  String get itemId;

  /// Nome do banco (do conector da Pluggy).
  @BuiltValueField(wireName: r'instituicao')
  String get instituicao;

  /// Como a Pluggy informa o item (UPDATED, LOGIN_ERROR...).
  @BuiltValueField(wireName: r'status')
  String? get status;

  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  @BuiltValueField(wireName: r'consentimento_expira_em')
  DateTime? get consentimentoExpiraEm;

  /// Último sync bem-sucedido.
  @BuiltValueField(wireName: r'ultimo_sync_em')
  DateTime? get ultimoSyncEm;

  @BuiltValueField(wireName: r'ultima_tentativa_em')
  DateTime? get ultimaTentativaEm;

  /// Em português; nulo depois de um sucesso.
  @BuiltValueField(wireName: r'ultimo_erro')
  String? get ultimoErro;

  /// Próximo sync diário; nulo se desativada.
  @BuiltValueField(wireName: r'proximo_sync')
  DateTime? get proximoSync;

  /// Quando o Buscar agora volta a valer (1×/hora); nulo se já vale.
  @BuiltValueField(wireName: r'buscar_a_partir_de')
  DateTime? get buscarAPartirDe;

  /// Só nas ativas; nulo quando está tudo bem.
  @BuiltValueField(wireName: r'problema')
  Problema? get problema;
  // enum problemaEnum {  vencido,  erro,  sem_dados,  vencendo,  };

  /// Contas do app que a conexão alimenta.
  @BuiltValueField(wireName: r'contas')
  BuiltList<ContaDoAppSaida> get contas;

  ConexaoSaida._();

  factory ConexaoSaida([void updates(ConexaoSaidaBuilder b)]) = _$ConexaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConexaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConexaoSaida> get serializer => _$ConexaoSaidaSerializer();
}

class _$ConexaoSaidaSerializer implements PrimitiveSerializer<ConexaoSaida> {
  @override
  final Iterable<Type> types = const [ConexaoSaida, _$ConexaoSaida];

  @override
  final String wireName = r'ConexaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConexaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'item_id';
    yield serializers.serialize(
      object.itemId,
      specifiedType: const FullType(String),
    );
    yield r'instituicao';
    yield serializers.serialize(
      object.instituicao,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield object.status == null ? null : serializers.serialize(
      object.status,
      specifiedType: const FullType.nullable(String),
    );
    yield r'ativa';
    yield serializers.serialize(
      object.ativa,
      specifiedType: const FullType(bool),
    );
    yield r'consentimento_expira_em';
    yield object.consentimentoExpiraEm == null ? null : serializers.serialize(
      object.consentimentoExpiraEm,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'ultimo_sync_em';
    yield object.ultimoSyncEm == null ? null : serializers.serialize(
      object.ultimoSyncEm,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'ultima_tentativa_em';
    yield object.ultimaTentativaEm == null ? null : serializers.serialize(
      object.ultimaTentativaEm,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'ultimo_erro';
    yield object.ultimoErro == null ? null : serializers.serialize(
      object.ultimoErro,
      specifiedType: const FullType.nullable(String),
    );
    yield r'proximo_sync';
    yield object.proximoSync == null ? null : serializers.serialize(
      object.proximoSync,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'buscar_a_partir_de';
    yield object.buscarAPartirDe == null ? null : serializers.serialize(
      object.buscarAPartirDe,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'problema';
    yield object.problema == null ? null : serializers.serialize(
      object.problema,
      specifiedType: const FullType.nullable(Problema),
    );
    yield r'contas';
    yield serializers.serialize(
      object.contas,
      specifiedType: const FullType(BuiltList, [FullType(ContaDoAppSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ConexaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConexaoSaidaBuilder result,
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
        case r'item_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.itemId = valueDes;
          break;
        case r'instituicao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.instituicao = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.status = valueDes;
          break;
        case r'ativa':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ativa = valueDes;
          break;
        case r'consentimento_expira_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.consentimentoExpiraEm = valueDes;
          break;
        case r'ultimo_sync_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.ultimoSyncEm = valueDes;
          break;
        case r'ultima_tentativa_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.ultimaTentativaEm = valueDes;
          break;
        case r'ultimo_erro':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.ultimoErro = valueDes;
          break;
        case r'proximo_sync':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.proximoSync = valueDes;
          break;
        case r'buscar_a_partir_de':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.buscarAPartirDe = valueDes;
          break;
        case r'problema':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(Problema),
          ) as Problema?;
          if (valueDes == null) continue;
          result.problema = valueDes;
          break;
        case r'contas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ContaDoAppSaida)]),
          ) as BuiltList<ContaDoAppSaida>;
          result.contas.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ConexaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConexaoSaidaBuilder();
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


