//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'salario_recebido_saida.g.dart';

/// SalarioRecebidoSaida
///
/// Properties:
/// * [rendaId] 
/// * [descricao] - Descrição da renda.
/// * [contaId] 
/// * [conta] - Nome da conta onde o salário caiu.
/// * [dataEsperada] - A data efetiva da renda neste ciclo; com a renda, identifica o salário.
/// * [data] - Data do crédito.
/// * [valor] 
@BuiltValue()
abstract class SalarioRecebidoSaida implements Built<SalarioRecebidoSaida, SalarioRecebidoSaidaBuilder> {
  @BuiltValueField(wireName: r'renda_id')
  String get rendaId;

  /// Descrição da renda.
  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  /// Nome da conta onde o salário caiu.
  @BuiltValueField(wireName: r'conta')
  String get conta;

  /// A data efetiva da renda neste ciclo; com a renda, identifica o salário.
  @BuiltValueField(wireName: r'data_esperada')
  Date get dataEsperada;

  /// Data do crédito.
  @BuiltValueField(wireName: r'data')
  Date get data;

  @BuiltValueField(wireName: r'valor')
  String get valor;

  SalarioRecebidoSaida._();

  factory SalarioRecebidoSaida([void updates(SalarioRecebidoSaidaBuilder b)]) = _$SalarioRecebidoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SalarioRecebidoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SalarioRecebidoSaida> get serializer => _$SalarioRecebidoSaidaSerializer();
}

class _$SalarioRecebidoSaidaSerializer implements PrimitiveSerializer<SalarioRecebidoSaida> {
  @override
  final Iterable<Type> types = const [SalarioRecebidoSaida, _$SalarioRecebidoSaida];

  @override
  final String wireName = r'SalarioRecebidoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SalarioRecebidoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'renda_id';
    yield serializers.serialize(
      object.rendaId,
      specifiedType: const FullType(String),
    );
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
      specifiedType: const FullType(String),
    );
    yield r'conta';
    yield serializers.serialize(
      object.conta,
      specifiedType: const FullType(String),
    );
    yield r'data_esperada';
    yield serializers.serialize(
      object.dataEsperada,
      specifiedType: const FullType(Date),
    );
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(Date),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SalarioRecebidoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SalarioRecebidoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'renda_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.rendaId = valueDes;
          break;
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
          break;
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaId = valueDes;
          break;
        case r'conta':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.conta = valueDes;
          break;
        case r'data_esperada':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataEsperada = valueDes;
          break;
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.data = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SalarioRecebidoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SalarioRecebidoSaidaBuilder();
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


