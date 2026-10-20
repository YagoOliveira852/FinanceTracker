//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/conta_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'contas_resumo.g.dart';

/// ContasResumo
///
/// Properties:
/// * [totalDisponivel] - Soma dos saldos das contas correntes e carteiras ativas; cartão não entra.
/// * [contas] 
@BuiltValue()
abstract class ContasResumo implements Built<ContasResumo, ContasResumoBuilder> {
  /// Soma dos saldos das contas correntes e carteiras ativas; cartão não entra.
  @BuiltValueField(wireName: r'total_disponivel')
  String get totalDisponivel;

  @BuiltValueField(wireName: r'contas')
  BuiltList<ContaSaida> get contas;

  ContasResumo._();

  factory ContasResumo([void updates(ContasResumoBuilder b)]) = _$ContasResumo;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContasResumoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContasResumo> get serializer => _$ContasResumoSerializer();
}

class _$ContasResumoSerializer implements PrimitiveSerializer<ContasResumo> {
  @override
  final Iterable<Type> types = const [ContasResumo, _$ContasResumo];

  @override
  final String wireName = r'ContasResumo';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContasResumo object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'total_disponivel';
    yield serializers.serialize(
      object.totalDisponivel,
      specifiedType: const FullType(String),
    );
    yield r'contas';
    yield serializers.serialize(
      object.contas,
      specifiedType: const FullType(BuiltList, [FullType(ContaSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContasResumo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContasResumoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'total_disponivel':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.totalDisponivel = valueDes;
          break;
        case r'contas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ContaSaida)]),
          ) as BuiltList<ContaSaida>;
          result.contas.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContasResumo deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContasResumoBuilder();
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


