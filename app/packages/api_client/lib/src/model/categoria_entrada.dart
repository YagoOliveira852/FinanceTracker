//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/grupo_categoria.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'categoria_entrada.g.dart';

/// CategoriaEntrada
///
/// Properties:
/// * [nome] - Único, sem diferenciar maiúsculas.
/// * [grupo] - Essencial e variável são gasto (despesa e estorno); renda vale para receita; investimento, para aporte e resgate.
@BuiltValue()
abstract class CategoriaEntrada implements Built<CategoriaEntrada, CategoriaEntradaBuilder> {
  /// Único, sem diferenciar maiúsculas.
  @BuiltValueField(wireName: r'nome')
  String get nome;

  /// Essencial e variável são gasto (despesa e estorno); renda vale para receita; investimento, para aporte e resgate.
  @BuiltValueField(wireName: r'grupo')
  GrupoCategoria get grupo;
  // enum grupoEnum {  essencial,  variavel,  renda,  investimento,  };

  CategoriaEntrada._();

  factory CategoriaEntrada([void updates(CategoriaEntradaBuilder b)]) = _$CategoriaEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CategoriaEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CategoriaEntrada> get serializer => _$CategoriaEntradaSerializer();
}

class _$CategoriaEntradaSerializer implements PrimitiveSerializer<CategoriaEntrada> {
  @override
  final Iterable<Type> types = const [CategoriaEntrada, _$CategoriaEntrada];

  @override
  final String wireName = r'CategoriaEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CategoriaEntrada object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    CategoriaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CategoriaEntradaBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CategoriaEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CategoriaEntradaBuilder();
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


