//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/efeito_aprendizado.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'confirmacao_saida.g.dart';

/// ConfirmacaoSaida
///
/// Properties:
/// * [efeito] - O que a confirmação fez com as regras.
/// * [regraPadrao] - O padrão da regra criada, reforçada ou mantida.
@BuiltValue()
abstract class ConfirmacaoSaida implements Built<ConfirmacaoSaida, ConfirmacaoSaidaBuilder> {
  /// O que a confirmação fez com as regras.
  @BuiltValueField(wireName: r'efeito')
  EfeitoAprendizado get efeito;
  // enum efeitoEnum {  criada,  reforcada,  corrigida,  especializada,  manual_mantida,  nenhuma,  };

  /// O padrão da regra criada, reforçada ou mantida.
  @BuiltValueField(wireName: r'regra_padrao')
  String? get regraPadrao;

  ConfirmacaoSaida._();

  factory ConfirmacaoSaida([void updates(ConfirmacaoSaidaBuilder b)]) = _$ConfirmacaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConfirmacaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConfirmacaoSaida> get serializer => _$ConfirmacaoSaidaSerializer();
}

class _$ConfirmacaoSaidaSerializer implements PrimitiveSerializer<ConfirmacaoSaida> {
  @override
  final Iterable<Type> types = const [ConfirmacaoSaida, _$ConfirmacaoSaida];

  @override
  final String wireName = r'ConfirmacaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConfirmacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'efeito';
    yield serializers.serialize(
      object.efeito,
      specifiedType: const FullType(EfeitoAprendizado),
    );
    yield r'regra_padrao';
    yield object.regraPadrao == null ? null : serializers.serialize(
      object.regraPadrao,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ConfirmacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConfirmacaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'efeito':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EfeitoAprendizado),
          ) as EfeitoAprendizado;
          result.efeito = valueDes;
          break;
        case r'regra_padrao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.regraPadrao = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ConfirmacaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConfirmacaoSaidaBuilder();
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


