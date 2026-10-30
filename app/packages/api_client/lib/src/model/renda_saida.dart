//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/proxima_data_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'renda_saida.g.dart';

/// RendaSaida
///
/// Properties:
/// * [id] 
/// * [descricao] 
/// * [valor] 
/// * [diaPrevisto] 
/// * [contaId] 
/// * [ativa] 
/// * [proxima] 
@BuiltValue()
abstract class RendaSaida implements Built<RendaSaida, RendaSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  @BuiltValueField(wireName: r'valor')
  String get valor;

  @BuiltValueField(wireName: r'dia_previsto')
  int get diaPrevisto;

  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  @BuiltValueField(wireName: r'proxima')
  ProximaDataSaida get proxima;

  RendaSaida._();

  factory RendaSaida([void updates(RendaSaidaBuilder b)]) = _$RendaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RendaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RendaSaida> get serializer => _$RendaSaidaSerializer();
}

class _$RendaSaidaSerializer implements PrimitiveSerializer<RendaSaida> {
  @override
  final Iterable<Type> types = const [RendaSaida, _$RendaSaida];

  @override
  final String wireName = r'RendaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RendaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
    yield r'valor';
    yield serializers.serialize(
      object.valor,
      specifiedType: const FullType(String),
    );
    yield r'dia_previsto';
    yield serializers.serialize(
      object.diaPrevisto,
      specifiedType: const FullType(int),
    );
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
      specifiedType: const FullType(String),
    );
    yield r'ativa';
    yield serializers.serialize(
      object.ativa,
      specifiedType: const FullType(bool),
    );
    yield r'proxima';
    yield serializers.serialize(
      object.proxima,
      specifiedType: const FullType(ProximaDataSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RendaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RendaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'descricao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.descricao = valueDes;
          break;
        case r'valor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valor = valueDes;
          break;
        case r'dia_previsto':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.diaPrevisto = valueDes;
          break;
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.contaId = valueDes;
          break;
        case r'ativa':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ativa = valueDes;
          break;
        case r'proxima':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ProximaDataSaida),
          ) as ProximaDataSaida;
          result.proxima.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RendaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RendaSaidaBuilder();
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


