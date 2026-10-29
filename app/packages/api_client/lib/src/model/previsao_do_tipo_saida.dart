//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/sugestao_saida.dart';
import 'package:api_client/src/model/efeito_aprendizado.dart';
import 'package:api_client/src/model/tipo_transacao.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'previsao_do_tipo_saida.g.dart';

/// PrevisaoDoTipoSaida
///
/// Properties:
/// * [tipo] 
/// * [sugestao] - A sugestão como se o rascunho tivesse este tipo.
/// * [efeitoConfirmando] 
/// * [efeitoCorrigindo] 
@BuiltValue()
abstract class PrevisaoDoTipoSaida implements Built<PrevisaoDoTipoSaida, PrevisaoDoTipoSaidaBuilder> {
  @BuiltValueField(wireName: r'tipo')
  TipoTransacao get tipo;
  // enum tipoEnum {  despesa,  receita,  transferencia_saida,  transferencia_entrada,  pagamento_fatura,  aporte,  resgate,  estorno,  ajuste_entrada,  ajuste_saida,  };

  /// A sugestão como se o rascunho tivesse este tipo.
  @BuiltValueField(wireName: r'sugestao')
  SugestaoSaida? get sugestao;

  @BuiltValueField(wireName: r'efeito_confirmando')
  EfeitoAprendizado get efeitoConfirmando;
  // enum efeitoConfirmandoEnum {  criada,  reforcada,  corrigida,  especializada,  manual_mantida,  nenhuma,  };

  @BuiltValueField(wireName: r'efeito_corrigindo')
  EfeitoAprendizado get efeitoCorrigindo;
  // enum efeitoCorrigindoEnum {  criada,  reforcada,  corrigida,  especializada,  manual_mantida,  nenhuma,  };

  PrevisaoDoTipoSaida._();

  factory PrevisaoDoTipoSaida([void updates(PrevisaoDoTipoSaidaBuilder b)]) = _$PrevisaoDoTipoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PrevisaoDoTipoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PrevisaoDoTipoSaida> get serializer => _$PrevisaoDoTipoSaidaSerializer();
}

class _$PrevisaoDoTipoSaidaSerializer implements PrimitiveSerializer<PrevisaoDoTipoSaida> {
  @override
  final Iterable<Type> types = const [PrevisaoDoTipoSaida, _$PrevisaoDoTipoSaida];

  @override
  final String wireName = r'PrevisaoDoTipoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PrevisaoDoTipoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(TipoTransacao),
    );
    yield r'sugestao';
    yield object.sugestao == null ? null : serializers.serialize(
      object.sugestao,
      specifiedType: const FullType.nullable(SugestaoSaida),
    );
    yield r'efeito_confirmando';
    yield serializers.serialize(
      object.efeitoConfirmando,
      specifiedType: const FullType(EfeitoAprendizado),
    );
    yield r'efeito_corrigindo';
    yield serializers.serialize(
      object.efeitoCorrigindo,
      specifiedType: const FullType(EfeitoAprendizado),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PrevisaoDoTipoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PrevisaoDoTipoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TipoTransacao),
          ) as TipoTransacao;
          result.tipo = valueDes;
          break;
        case r'sugestao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(SugestaoSaida),
          ) as SugestaoSaida?;
          if (valueDes == null) continue;
          result.sugestao.replace(valueDes);
          break;
        case r'efeito_confirmando':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EfeitoAprendizado),
          ) as EfeitoAprendizado;
          result.efeitoConfirmando = valueDes;
          break;
        case r'efeito_corrigindo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EfeitoAprendizado),
          ) as EfeitoAprendizado;
          result.efeitoCorrigindo = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PrevisaoDoTipoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PrevisaoDoTipoSaidaBuilder();
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


