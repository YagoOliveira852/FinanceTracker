//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'confirmacao_entrada.g.dart';

/// ConfirmacaoEntrada
///
/// Properties:
/// * [descricao] 
/// * [categoriaId] - Ativa e do grupo que combina com o tipo.
/// * [tipo] - Troca o tipo no mesmo sentido (saída: despesa; entrada: receita ou estorno); nulo mantém.
@BuiltValue()
abstract class ConfirmacaoEntrada implements Built<ConfirmacaoEntrada, ConfirmacaoEntradaBuilder> {
  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  /// Ativa e do grupo que combina com o tipo.
  @BuiltValueField(wireName: r'categoria_id')
  String get categoriaId;

  /// Troca o tipo no mesmo sentido (saída: despesa; entrada: receita ou estorno); nulo mantém.
  @BuiltValueField(wireName: r'tipo')
  ConfirmacaoEntradaTipoEnum? get tipo;
  // enum tipoEnum {  despesa,  receita,  estorno,  };

  ConfirmacaoEntrada._();

  factory ConfirmacaoEntrada([void updates(ConfirmacaoEntradaBuilder b)]) = _$ConfirmacaoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConfirmacaoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConfirmacaoEntrada> get serializer => _$ConfirmacaoEntradaSerializer();
}

class _$ConfirmacaoEntradaSerializer implements PrimitiveSerializer<ConfirmacaoEntrada> {
  @override
  final Iterable<Type> types = const [ConfirmacaoEntrada, _$ConfirmacaoEntrada];

  @override
  final String wireName = r'ConfirmacaoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConfirmacaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
    yield r'categoria_id';
    yield serializers.serialize(
      object.categoriaId,
      specifiedType: const FullType(String),
    );
    if (object.tipo != null) {
      yield r'tipo';
      yield serializers.serialize(
        object.tipo,
        specifiedType: const FullType.nullable(ConfirmacaoEntradaTipoEnum),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ConfirmacaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConfirmacaoEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
            specifiedType: const FullType(String),
          ) as String;
          result.categoriaId = valueDes;
          break;
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(ConfirmacaoEntradaTipoEnum),
          ) as ConfirmacaoEntradaTipoEnum?;
          if (valueDes == null) continue;
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
  ConfirmacaoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConfirmacaoEntradaBuilder();
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


/// Troca o tipo no mesmo sentido (saída: despesa; entrada: receita ou estorno); nulo mantém.
class ConfirmacaoEntradaTipoEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'despesa')
  static const ConfirmacaoEntradaTipoEnum despesa = _$confirmacaoEntradaTipoEnum_despesa;
  @BuiltValueEnumConst(wireName: r'receita')
  static const ConfirmacaoEntradaTipoEnum receita = _$confirmacaoEntradaTipoEnum_receita;
  @BuiltValueEnumConst(wireName: r'estorno')
  static const ConfirmacaoEntradaTipoEnum estorno = _$confirmacaoEntradaTipoEnum_estorno;

  static Serializer<ConfirmacaoEntradaTipoEnum> get serializer => _$confirmacaoEntradaTipoEnumSerializer;

  const ConfirmacaoEntradaTipoEnum._(String name): super(name);

  static BuiltSet<ConfirmacaoEntradaTipoEnum> get values => _$confirmacaoEntradaTipoEnumValues;
  static ConfirmacaoEntradaTipoEnum valueOf(String name) => _$confirmacaoEntradaTipoEnumValueOf(name);
}

