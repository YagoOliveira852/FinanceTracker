//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:api_client/src/model/conta_do_app_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_da_previa_saida.g.dart';

/// ContaDaPreviaSaida
///
/// Properties:
/// * [pluggyAccountId] 
/// * [tipo] - Tipo que a conta tem (ou teria) no app.
/// * [nome] 
/// * [numeroFinal] - 4 últimos dígitos do número.
/// * [sugestao] - Conta do app sugerida pelo final do número; nula sem sugestão.
/// * [podeCriar] - Falso no cartão sem fechamento na Pluggy: só vincular a um existente.
@BuiltValue()
abstract class ContaDaPreviaSaida implements Built<ContaDaPreviaSaida, ContaDaPreviaSaidaBuilder> {
  @BuiltValueField(wireName: r'pluggy_account_id')
  String get pluggyAccountId;

  /// Tipo que a conta tem (ou teria) no app.
  @BuiltValueField(wireName: r'tipo')
  TipoConta get tipo;
  // enum tipoEnum {  corrente,  cartao_credito,  carteira,  };

  @BuiltValueField(wireName: r'nome')
  String get nome;

  /// 4 últimos dígitos do número.
  @BuiltValueField(wireName: r'numero_final')
  String? get numeroFinal;

  /// Conta do app sugerida pelo final do número; nula sem sugestão.
  @BuiltValueField(wireName: r'sugestao')
  ContaDoAppSaida? get sugestao;

  /// Falso no cartão sem fechamento na Pluggy: só vincular a um existente.
  @BuiltValueField(wireName: r'pode_criar')
  bool get podeCriar;

  ContaDaPreviaSaida._();

  factory ContaDaPreviaSaida([void updates(ContaDaPreviaSaidaBuilder b)]) = _$ContaDaPreviaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaDaPreviaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaDaPreviaSaida> get serializer => _$ContaDaPreviaSaidaSerializer();
}

class _$ContaDaPreviaSaidaSerializer implements PrimitiveSerializer<ContaDaPreviaSaida> {
  @override
  final Iterable<Type> types = const [ContaDaPreviaSaida, _$ContaDaPreviaSaida];

  @override
  final String wireName = r'ContaDaPreviaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaDaPreviaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'pluggy_account_id';
    yield serializers.serialize(
      object.pluggyAccountId,
      specifiedType: const FullType(String),
    );
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(TipoConta),
    );
    yield r'nome';
    yield serializers.serialize(
      object.nome,
      specifiedType: const FullType(String),
    );
    yield r'numero_final';
    yield object.numeroFinal == null ? null : serializers.serialize(
      object.numeroFinal,
      specifiedType: const FullType.nullable(String),
    );
    yield r'sugestao';
    yield object.sugestao == null ? null : serializers.serialize(
      object.sugestao,
      specifiedType: const FullType.nullable(ContaDoAppSaida),
    );
    yield r'pode_criar';
    yield serializers.serialize(
      object.podeCriar,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContaDaPreviaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaDaPreviaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'pluggy_account_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.pluggyAccountId = valueDes;
          break;
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TipoConta),
          ) as TipoConta;
          result.tipo = valueDes;
          break;
        case r'nome':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nome = valueDes;
          break;
        case r'numero_final':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.numeroFinal = valueDes;
          break;
        case r'sugestao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ContaDoAppSaida),
          ) as ContaDoAppSaida?;
          if (valueDes == null) continue;
          result.sugestao.replace(valueDes);
          break;
        case r'pode_criar':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.podeCriar = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContaDaPreviaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaDaPreviaSaidaBuilder();
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


