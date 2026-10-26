//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transferencia_entrada.g.dart';

/// Transferência entre contas próprias (corrente ou carteira): gera a saída na origem e a entrada no destino, ligadas.
///
/// Properties:
/// * [contaOrigemId] 
/// * [contaDestinoId] 
/// * [valor] 
/// * [data] 
/// * [descricao] - Vazia ou nula: \"Transferência\".
@BuiltValue()
abstract class TransferenciaEntrada implements Built<TransferenciaEntrada, TransferenciaEntradaBuilder> {
  @BuiltValueField(wireName: r'conta_origem_id')
  String get contaOrigemId;

  @BuiltValueField(wireName: r'conta_destino_id')
  String get contaDestinoId;

  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'data')
  Date get data;

  /// Vazia ou nula: \"Transferência\".
  @BuiltValueField(wireName: r'descricao')
  String? get descricao;

  TransferenciaEntrada._();

  factory TransferenciaEntrada([void updates(TransferenciaEntradaBuilder b)]) = _$TransferenciaEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransferenciaEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TransferenciaEntrada> get serializer => _$TransferenciaEntradaSerializer();
}

class _$TransferenciaEntradaSerializer implements PrimitiveSerializer<TransferenciaEntrada> {
  @override
  final Iterable<Type> types = const [TransferenciaEntrada, _$TransferenciaEntrada];

  @override
  final String wireName = r'TransferenciaEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TransferenciaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conta_origem_id';
    yield serializers.serialize(
      object.contaOrigemId,
      specifiedType: const FullType(String),
    );
    yield r'conta_destino_id';
    yield serializers.serialize(
      object.contaDestinoId,
      specifiedType: const FullType(String),
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
    if (object.descricao != null) {
      yield r'descricao';
      yield serializers.serialize(
        object.descricao,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    TransferenciaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransferenciaEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conta_origem_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaOrigemId = valueDes;
          break;
        case r'conta_destino_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaDestinoId = valueDes;
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
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
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
  TransferenciaEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransferenciaEntradaBuilder();
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


