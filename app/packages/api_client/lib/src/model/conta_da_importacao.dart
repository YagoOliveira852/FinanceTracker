//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_da_importacao.g.dart';

/// ContaDaImportacao
///
/// Properties:
/// * [id] 
/// * [nome] 
/// * [tipo] 
@BuiltValue()
abstract class ContaDaImportacao implements Built<ContaDaImportacao, ContaDaImportacaoBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'tipo')
  TipoConta get tipo;
  // enum tipoEnum {  corrente,  cartao_credito,  carteira,  };

  ContaDaImportacao._();

  factory ContaDaImportacao([void updates(ContaDaImportacaoBuilder b)]) = _$ContaDaImportacao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaDaImportacaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaDaImportacao> get serializer => _$ContaDaImportacaoSerializer();
}

class _$ContaDaImportacaoSerializer implements PrimitiveSerializer<ContaDaImportacao> {
  @override
  final Iterable<Type> types = const [ContaDaImportacao, _$ContaDaImportacao];

  @override
  final String wireName = r'ContaDaImportacao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaDaImportacao object, {
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
    ContaDaImportacao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaDaImportacaoBuilder result,
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
  ContaDaImportacao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaDaImportacaoBuilder();
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


