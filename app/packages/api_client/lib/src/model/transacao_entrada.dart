//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transacao_entrada.g.dart';

/// Lançamento manual. Entra já confirmado: só o que vem de importação ou da Pluggy passa pela revisão.
///
/// Properties:
/// * [contaId] 
/// * [tipo] 
/// * [valor] - Sempre positivo; o sentido vem do `tipo`.
/// * [data] 
/// * [descricao] 
/// * [categoriaId] - Ativa e do grupo que combina com o tipo; não cria regra.
@BuiltValue()
abstract class TransacaoEntrada implements Built<TransacaoEntrada, TransacaoEntradaBuilder> {
  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  @BuiltValueField(wireName: r'tipo')
  TransacaoEntradaTipoEnum get tipo;
  // enum tipoEnum {  despesa,  receita,  };

  /// Sempre positivo; o sentido vem do `tipo`.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'data')
  Date get data;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  /// Ativa e do grupo que combina com o tipo; não cria regra.
  @BuiltValueField(wireName: r'categoria_id')
  String? get categoriaId;

  TransacaoEntrada._();

  factory TransacaoEntrada([void updates(TransacaoEntradaBuilder b)]) = _$TransacaoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransacaoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransacaoEntrada> get serializer => _$TransacaoEntradaSerializer();
}

class _$TransacaoEntradaSerializer implements PrimitiveSerializer<TransacaoEntrada> {
  @override
  final Iterable<Type> types = const [TransacaoEntrada, _$TransacaoEntrada];

  @override
  final String wireName = r'TransacaoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransacaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
      specifiedType: const FullType(String),
    );
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(TransacaoEntradaTipoEnum),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(Date),
    );
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
    if (object.categoriaId != null) {
      yield r'categoria_id';
      yield serializers.serialize(
        object.categoriaId,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    TransacaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransacaoEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaId = valueDes;
          break;
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoEntradaTipoEnum),
          ) as TransacaoEntradaTipoEnum;
          result.tipo = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.data = valueDes;
          break;
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
          break;
        case r'categoria_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.categoriaId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TransacaoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransacaoEntradaBuilder();
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


class TransacaoEntradaTipoEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'despesa')
  static const TransacaoEntradaTipoEnum despesa = _$transacaoEntradaTipoEnum_despesa;
  @BuiltValueEnumConst(wireName: r'receita')
  static const TransacaoEntradaTipoEnum receita = _$transacaoEntradaTipoEnum_receita;

  static Serializer<TransacaoEntradaTipoEnum> get serializer => _$transacaoEntradaTipoEnumSerializer;

  const TransacaoEntradaTipoEnum._(String name): super(name);

  static BuiltSet<TransacaoEntradaTipoEnum> get values => _$transacaoEntradaTipoEnumValues;
  static TransacaoEntradaTipoEnum valueOf(String name) => _$transacaoEntradaTipoEnumValueOf(name);
}

