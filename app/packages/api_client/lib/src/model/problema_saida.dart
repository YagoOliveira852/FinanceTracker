//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/problema.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'problema_saida.g.dart';

/// ProblemaSaida
///
/// Properties:
/// * [problema] 
/// * [conexaoId] 
/// * [instituicao] 
@BuiltValue()
abstract class ProblemaSaida implements Built<ProblemaSaida, ProblemaSaidaBuilder> {
  @BuiltValueField(wireName: r'problema')
  Problema get problema;
  // enum problemaEnum {  vencido,  erro,  sem_dados,  vencendo,  };

  @BuiltValueField(wireName: r'conexao_id')
  String get conexaoId;

  @BuiltValueField(wireName: r'instituicao')
  String get instituicao;

  ProblemaSaida._();

  factory ProblemaSaida([void updates(ProblemaSaidaBuilder b)]) = _$ProblemaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ProblemaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ProblemaSaida> get serializer => _$ProblemaSaidaSerializer();
}

class _$ProblemaSaidaSerializer implements PrimitiveSerializer<ProblemaSaida> {
  @override
  final Iterable<Type> types = const [ProblemaSaida, _$ProblemaSaida];

  @override
  final String wireName = r'ProblemaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ProblemaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'problema';
    yield serializers.serialize(
      object.problema,
      specifiedType: const FullType(Problema),
    );
    yield r'conexao_id';
    yield serializers.serialize(
      object.conexaoId,
      specifiedType: const FullType(String),
    );
    yield r'instituicao';
    yield serializers.serialize(
      object.instituicao,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ProblemaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ProblemaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'problema':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Problema),
          ) as Problema;
          result.problema = valueDes;
          break;
        case r'conexao_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.conexaoId = valueDes;
          break;
        case r'instituicao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.instituicao = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ProblemaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ProblemaSaidaBuilder();
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


