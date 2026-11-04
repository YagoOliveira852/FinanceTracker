//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/conexao_saida.dart';
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/problema_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'lista_conexoes_saida.g.dart';

/// ListaConexoesSaida
///
/// Properties:
/// * [conexoes] - Ativas primeiro, pela criação.
/// * [problema] - O mais grave entre as ativas (vencido > erro > sem_dados > vencendo): o card do Início; nulo sem problema.
@BuiltValue()
abstract class ListaConexoesSaida implements Built<ListaConexoesSaida, ListaConexoesSaidaBuilder> {
  /// Ativas primeiro, pela criação.
  @BuiltValueField(wireName: r'conexoes')
  BuiltList<ConexaoSaida> get conexoes;

  /// O mais grave entre as ativas (vencido > erro > sem_dados > vencendo): o card do Início; nulo sem problema.
  @BuiltValueField(wireName: r'problema')
  ProblemaSaida? get problema;

  ListaConexoesSaida._();

  factory ListaConexoesSaida([void updates(ListaConexoesSaidaBuilder b)]) = _$ListaConexoesSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListaConexoesSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListaConexoesSaida> get serializer => _$ListaConexoesSaidaSerializer();
}

class _$ListaConexoesSaidaSerializer implements PrimitiveSerializer<ListaConexoesSaida> {
  @override
  final Iterable<Type> types = const [ListaConexoesSaida, _$ListaConexoesSaida];

  @override
  final String wireName = r'ListaConexoesSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListaConexoesSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conexoes';
    yield serializers.serialize(
      object.conexoes,
      specifiedType: const FullType(BuiltList, [FullType(ConexaoSaida)]),
    );
    yield r'problema';
    yield object.problema == null ? null : serializers.serialize(
      object.problema,
      specifiedType: const FullType.nullable(ProblemaSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListaConexoesSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListaConexoesSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conexoes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ConexaoSaida)]),
          ) as BuiltList<ConexaoSaida>;
          result.conexoes.replace(valueDes);
          break;
        case r'problema':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ProblemaSaida),
          ) as ProblemaSaida?;
          if (valueDes == null) continue;
          result.problema.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListaConexoesSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListaConexoesSaidaBuilder();
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


