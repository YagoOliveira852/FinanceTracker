//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/categoria_resumo.dart';
import 'package:api_client/src/model/origem_regra.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sugestao_saida.g.dart';

/// SugestaoSaida
///
/// Properties:
/// * [regraId] 
/// * [padrao] 
/// * [origem] 
/// * [categoria] 
@BuiltValue()
abstract class SugestaoSaida implements Built<SugestaoSaida, SugestaoSaidaBuilder> {
  @BuiltValueField(wireName: r'regra_id')
  String get regraId;

  @BuiltValueField(wireName: r'padrao')
  String get padrao;

  @BuiltValueField(wireName: r'origem')
  OrigemRegra get origem;
  // enum origemEnum {  manual,  aprendida,  };

  @BuiltValueField(wireName: r'categoria')
  CategoriaResumo get categoria;

  SugestaoSaida._();

  factory SugestaoSaida([void updates(SugestaoSaidaBuilder b)]) = _$SugestaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SugestaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SugestaoSaida> get serializer => _$SugestaoSaidaSerializer();
}

class _$SugestaoSaidaSerializer implements PrimitiveSerializer<SugestaoSaida> {
  @override
  final Iterable<Type> types = const [SugestaoSaida, _$SugestaoSaida];

  @override
  final String wireName = r'SugestaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SugestaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'regra_id';
    yield serializers.serialize(
      object.regraId,
      specifiedType: const FullType(String),
    );
    yield r'padrao';
    yield serializers.serialize(
      object.padrao,
      specifiedType: const FullType(String),
    );
    yield r'origem';
    yield serializers.serialize(
      object.origem,
      specifiedType: const FullType(OrigemRegra),
    );
    yield r'categoria';
    yield serializers.serialize(
      object.categoria,
      specifiedType: const FullType(CategoriaResumo),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SugestaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SugestaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'regra_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.regraId = valueDes;
          break;
        case r'padrao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.padrao = valueDes;
          break;
        case r'origem':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(OrigemRegra),
          ) as OrigemRegra;
          result.origem = valueDes;
          break;
        case r'categoria':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CategoriaResumo),
          ) as CategoriaResumo;
          result.categoria.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SugestaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SugestaoSaidaBuilder();
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


