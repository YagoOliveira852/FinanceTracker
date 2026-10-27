//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_na_revisao.g.dart';

/// ContaNaRevisao
///
/// Properties:
/// * [id] 
/// * [nome] 
/// * [tipo] 
@BuiltValue()
abstract class ContaNaRevisao implements Built<ContaNaRevisao, ContaNaRevisaoBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'tipo')
  TipoConta get tipo;
  // enum tipoEnum {  corrente,  cartao_credito,  carteira,  };

  ContaNaRevisao._();

  factory ContaNaRevisao([void updates(ContaNaRevisaoBuilder b)]) = _$ContaNaRevisao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaNaRevisaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaNaRevisao> get serializer => _$ContaNaRevisaoSerializer();
}

class _$ContaNaRevisaoSerializer implements PrimitiveSerializer<ContaNaRevisao> {
  @override
  final Iterable<Type> types = const [ContaNaRevisao, _$ContaNaRevisao];

  @override
  final String wireName = r'ContaNaRevisao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaNaRevisao object, {
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
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(TipoConta),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContaNaRevisao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaNaRevisaoBuilder result,
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
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TipoConta),
          ) as TipoConta;
          result.tipo = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContaNaRevisao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaNaRevisaoBuilder();
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


