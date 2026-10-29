//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'linha_repetida_saida.g.dart';

/// LinhaRepetidaSaida
///
/// Properties:
/// * [fitid] - O identificador repetido: FITID no OFX, REFERENCE_ID no CSV do Mercado Pago.
/// * [data] 
/// * [valor] - Com sinal, como no arquivo: negativo é saída.
/// * [descricao] 
@BuiltValue()
abstract class LinhaRepetidaSaida implements Built<LinhaRepetidaSaida, LinhaRepetidaSaidaBuilder> {
  /// O identificador repetido: FITID no OFX, REFERENCE_ID no CSV do Mercado Pago.
  @BuiltValueField(wireName: r'fitid')
  String get fitid;

  @BuiltValueField(wireName: r'data')
  Date get data;

  /// Com sinal, como no arquivo: negativo é saída.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  LinhaRepetidaSaida._();

  factory LinhaRepetidaSaida([void updates(LinhaRepetidaSaidaBuilder b)]) = _$LinhaRepetidaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LinhaRepetidaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LinhaRepetidaSaida> get serializer => _$LinhaRepetidaSaidaSerializer();
}

class _$LinhaRepetidaSaidaSerializer implements PrimitiveSerializer<LinhaRepetidaSaida> {
  @override
  final Iterable<Type> types = const [LinhaRepetidaSaida, _$LinhaRepetidaSaida];

  @override
  final String wireName = r'LinhaRepetidaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LinhaRepetidaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'fitid';
    yield serializers.serialize(
      object.fitid,
      specifiedType: const FullType(String),
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
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LinhaRepetidaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LinhaRepetidaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'fitid':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.fitid = valueDes;
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
  LinhaRepetidaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LinhaRepetidaSaidaBuilder();
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


