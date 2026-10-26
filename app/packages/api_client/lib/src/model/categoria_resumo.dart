//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/grupo_categoria.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'categoria_resumo.g.dart';

/// CategoriaResumo
///
/// Properties:
/// * [id] 
/// * [nome] 
/// * [grupo] 
@BuiltValue()
abstract class CategoriaResumo implements Built<CategoriaResumo, CategoriaResumoBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'grupo')
  GrupoCategoria get grupo;
  // enum grupoEnum {  essencial,  variavel,  renda,  investimento,  };

  CategoriaResumo._();

  factory CategoriaResumo([void updates(CategoriaResumoBuilder b)]) = _$CategoriaResumo;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CategoriaResumoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CategoriaResumo> get serializer => _$CategoriaResumoSerializer();
}

class _$CategoriaResumoSerializer implements PrimitiveSerializer<CategoriaResumo> {
  @override
  final Iterable<Type> types = const [CategoriaResumo, _$CategoriaResumo];

  @override
  final String wireName = r'CategoriaResumo';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CategoriaResumo object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    CategoriaResumo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CategoriaResumoBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CategoriaResumo deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CategoriaResumoBuilder();
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


