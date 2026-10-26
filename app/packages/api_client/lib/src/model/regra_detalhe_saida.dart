//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/rascunhos_casados_saida.dart';
import 'package:api_client/src/model/conta_da_regra.dart';
import 'package:api_client/src/model/categoria_resumo.dart';
import 'package:api_client/src/model/origem_regra.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'regra_detalhe_saida.g.dart';

/// RegraDetalheSaida
///
/// Properties:
/// * [id] 
/// * [padrao] 
/// * [categoria] 
/// * [conta] - A conta a que a regra se restringe.
/// * [origem] - Aprendida na revisão ou manual (editar torna manual).
/// * [vezesAplicada] - Sugestões confirmadas como vieram.
/// * [criadoEm] 
/// * [rascunhos] 
@BuiltValue()
abstract class RegraDetalheSaida implements Built<RegraDetalheSaida, RegraDetalheSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'padrao')
  String get padrao;

  @BuiltValueField(wireName: r'categoria')
  CategoriaResumo get categoria;

  /// A conta a que a regra se restringe.
  @BuiltValueField(wireName: r'conta')
  ContaDaRegra? get conta;

  /// Aprendida na revisão ou manual (editar torna manual).
  @BuiltValueField(wireName: r'origem')
  OrigemRegra get origem;
  // enum origemEnum {  manual,  aprendida,  };

  /// Sugestões confirmadas como vieram.
  @BuiltValueField(wireName: r'vezes_aplicada')
  int get vezesAplicada;

  @BuiltValueField(wireName: r'criado_em')
  DateTime get criadoEm;

  @BuiltValueField(wireName: r'rascunhos')
  RascunhosCasadosSaida get rascunhos;

  RegraDetalheSaida._();

  factory RegraDetalheSaida([void updates(RegraDetalheSaidaBuilder b)]) = _$RegraDetalheSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RegraDetalheSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RegraDetalheSaida> get serializer => _$RegraDetalheSaidaSerializer();
}

class _$RegraDetalheSaidaSerializer implements PrimitiveSerializer<RegraDetalheSaida> {
  @override
  final Iterable<Type> types = const [RegraDetalheSaida, _$RegraDetalheSaida];

  @override
  final String wireName = r'RegraDetalheSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RegraDetalheSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'padrao';
    yield serializers.serialize(
      object.padrao,
      specifiedType: const FullType(String),
    );
    yield r'categoria';
    yield serializers.serialize(
      object.categoria,
      specifiedType: const FullType(CategoriaResumo),
    );
    yield r'conta';
    yield object.conta == null ? null : serializers.serialize(
      object.conta,
      specifiedType: const FullType.nullable(ContaDaRegra),
    );
    yield r'origem';
    yield serializers.serialize(
      object.origem,
      specifiedType: const FullType(OrigemRegra),
    );
    yield r'vezes_aplicada';
    yield serializers.serialize(
      object.vezesAplicada,
      specifiedType: const FullType(int),
    );
    yield r'criado_em';
    yield serializers.serialize(
      object.criadoEm,
      specifiedType: const FullType(DateTime),
    );
    yield r'rascunhos';
    yield serializers.serialize(
      object.rascunhos,
      specifiedType: const FullType(RascunhosCasadosSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RegraDetalheSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RegraDetalheSaidaBuilder result,
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
        case r'padrao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.padrao = valueDes;
          break;
        case r'categoria':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CategoriaResumo),
          ) as CategoriaResumo;
          result.categoria.replace(valueDes);
          break;
        case r'conta':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ContaDaRegra),
          ) as ContaDaRegra?;
          if (valueDes == null) continue;
          result.conta.replace(valueDes);
          break;
        case r'origem':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(OrigemRegra),
          ) as OrigemRegra;
          result.origem = valueDes;
          break;
        case r'vezes_aplicada':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.vezesAplicada = valueDes;
          break;
        case r'criado_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.criadoEm = valueDes;
          break;
        case r'rascunhos':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(RascunhosCasadosSaida),
          ) as RascunhosCasadosSaida;
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
  RegraDetalheSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RegraDetalheSaidaBuilder();
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


