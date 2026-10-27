//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transferencia_revisao_entrada.g.dart';

/// TransferenciaRevisaoEntrada
///
/// Properties:
/// * [contaId] - A outra conta: \"Para\" numa saída, \"De\" numa entrada. Corrente ou carteira ativa.
/// * [descricao] - Vale para os dois lados.
@BuiltValue()
abstract class TransferenciaRevisaoEntrada implements Built<TransferenciaRevisaoEntrada, TransferenciaRevisaoEntradaBuilder> {
  /// A outra conta: \"Para\" numa saída, \"De\" numa entrada. Corrente ou carteira ativa.
  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  /// Vale para os dois lados.
  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  TransferenciaRevisaoEntrada._();

  factory TransferenciaRevisaoEntrada([void updates(TransferenciaRevisaoEntradaBuilder b)]) = _$TransferenciaRevisaoEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransferenciaRevisaoEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransferenciaRevisaoEntrada> get serializer => _$TransferenciaRevisaoEntradaSerializer();
}

class _$TransferenciaRevisaoEntradaSerializer implements PrimitiveSerializer<TransferenciaRevisaoEntrada> {
  @override
  final Iterable<Type> types = const [TransferenciaRevisaoEntrada, _$TransferenciaRevisaoEntrada];

  @override
  final String wireName = r'TransferenciaRevisaoEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransferenciaRevisaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
      specifiedType: const FullType(String),
    );
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TransferenciaRevisaoEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransferenciaRevisaoEntradaBuilder result,
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
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TransferenciaRevisaoEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransferenciaRevisaoEntradaBuilder();
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


