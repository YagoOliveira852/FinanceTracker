//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/grupo_categoria.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'categoria_saida.g.dart';

/// CategoriaSaida
///
/// Properties:
/// * [id] 
/// * [nome] 
/// * [grupo] 
/// * [ativa] - Desativada sai das opções; as regras dela não sugerem.
/// * [qtdRegras] 
/// * [qtdTransacoes] 
@BuiltValue()
abstract class CategoriaSaida implements Built<CategoriaSaida, CategoriaSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'grupo')
  GrupoCategoria get grupo;
  // enum grupoEnum {  essencial,  variavel,  renda,  investimento,  };

  /// Desativada sai das opções; as regras dela não sugerem.
  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  @BuiltValueField(wireName: r'qtd_regras')
  int get qtdRegras;

  @BuiltValueField(wireName: r'qtd_transacoes')
  int get qtdTransacoes;

  CategoriaSaida._();

  factory CategoriaSaida([void updates(CategoriaSaidaBuilder b)]) = _$CategoriaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CategoriaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CategoriaSaida> get serializer => _$CategoriaSaidaSerializer();
}

class _$CategoriaSaidaSerializer implements PrimitiveSerializer<CategoriaSaida> {
  @override
  final Iterable<Type> types = const [CategoriaSaida, _$CategoriaSaida];

  @override
  final String wireName = r'CategoriaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CategoriaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'nome';
    yield serializers.serialize(
      object.nome,
      specifiedType: const FullType(String),
    );
    yield r'grupo';
    yield serializers.serialize(
      object.grupo,
      specifiedType: const FullType(GrupoCategoria),
    );
    yield r'ativa';
    yield serializers.serialize(
      object.ativa,
      specifiedType: const FullType(bool),
    );
    yield r'qtd_regras';
    yield serializers.serialize(
      object.qtdRegras,
      specifiedType: const FullType(int),
    );
    yield r'qtd_transacoes';
    yield serializers.serialize(
      object.qtdTransacoes,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CategoriaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CategoriaSaidaBuilder result,
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
        case r'nome':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nome = valueDes;
          break;
        case r'grupo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(GrupoCategoria),
          ) as GrupoCategoria;
          result.grupo = valueDes;
          break;
        case r'ativa':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ativa = valueDes;
          break;
        case r'qtd_regras':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdRegras = valueDes;
          break;
        case r'qtd_transacoes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdTransacoes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CategoriaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CategoriaSaidaBuilder();
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


