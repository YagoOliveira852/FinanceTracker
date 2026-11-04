//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_do_app_saida.g.dart';

/// ContaDoAppSaida
///
/// Properties:
/// * [id] 
/// * [nome] 
/// * [tipo] 
@BuiltValue()
abstract class ContaDoAppSaida implements Built<ContaDoAppSaida, ContaDoAppSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'tipo')
  TipoConta get tipo;
  // enum tipoEnum {  corrente,  cartao_credito,  carteira,  };

  ContaDoAppSaida._();

  factory ContaDoAppSaida([void updates(ContaDoAppSaidaBuilder b)]) = _$ContaDoAppSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaDoAppSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaDoAppSaida> get serializer => _$ContaDoAppSaidaSerializer();
}

class _$ContaDoAppSaidaSerializer implements PrimitiveSerializer<ContaDoAppSaida> {
  @override
  final Iterable<Type> types = const [ContaDoAppSaida, _$ContaDoAppSaida];

  @override
  final String wireName = r'ContaDoAppSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaDoAppSaida object, {
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
    ContaDoAppSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaDoAppSaidaBuilder result,
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
  ContaDoAppSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaDoAppSaidaBuilder();
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


