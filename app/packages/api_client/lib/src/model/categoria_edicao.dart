//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/grupo_categoria.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'categoria_edicao.g.dart';

/// Os mesmos campos do cadastro, mais `ativa` (desativar ou reativar).  O grupo só troca de natureza (gasto, renda, investimento) enquanto nenhuma transação usa a categoria.
///
/// Properties:
/// * [nome] - Único, sem diferenciar maiúsculas.
/// * [grupo] - Essencial e variável são gasto (despesa e estorno); renda vale para receita; investimento, para aporte e resgate.
/// * [ativa] 
@BuiltValue()
abstract class CategoriaEdicao implements Built<CategoriaEdicao, CategoriaEdicaoBuilder> {
  /// Único, sem diferenciar maiúsculas.
  @BuiltValueField(wireName: r'nome')
  String get nome;

  /// Essencial e variável são gasto (despesa e estorno); renda vale para receita; investimento, para aporte e resgate.
  @BuiltValueField(wireName: r'grupo')
  GrupoCategoria get grupo;
  // enum grupoEnum {  essencial,  variavel,  renda,  investimento,  };

  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  CategoriaEdicao._();

  factory CategoriaEdicao([void updates(CategoriaEdicaoBuilder b)]) = _$CategoriaEdicao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CategoriaEdicaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CategoriaEdicao> get serializer => _$CategoriaEdicaoSerializer();
}

class _$CategoriaEdicaoSerializer implements PrimitiveSerializer<CategoriaEdicao> {
  @override
  final Iterable<Type> types = const [CategoriaEdicao, _$CategoriaEdicao];

  @override
  final String wireName = r'CategoriaEdicao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CategoriaEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    CategoriaEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CategoriaEdicaoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CategoriaEdicao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CategoriaEdicaoBuilder();
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


