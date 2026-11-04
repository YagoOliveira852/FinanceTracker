//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/conta_da_previa_saida.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'previa_saida.g.dart';

/// PreviaSaida
///
/// Properties:
/// * [itemId] 
/// * [instituicao] 
/// * [consentimentoExpiraEm] 
/// * [contas] 
@BuiltValue()
abstract class PreviaSaida implements Built<PreviaSaida, PreviaSaidaBuilder> {
  @BuiltValueField(wireName: r'item_id')
  String get itemId;

  @BuiltValueField(wireName: r'instituicao')
  String get instituicao;

  @BuiltValueField(wireName: r'consentimento_expira_em')
  DateTime? get consentimentoExpiraEm;

  @BuiltValueField(wireName: r'contas')
  BuiltList<ContaDaPreviaSaida> get contas;

  PreviaSaida._();

  factory PreviaSaida([void updates(PreviaSaidaBuilder b)]) = _$PreviaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PreviaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PreviaSaida> get serializer => _$PreviaSaidaSerializer();
}

class _$PreviaSaidaSerializer implements PrimitiveSerializer<PreviaSaida> {
  @override
  final Iterable<Type> types = const [PreviaSaida, _$PreviaSaida];

  @override
  final String wireName = r'PreviaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PreviaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'item_id';
    yield serializers.serialize(
      object.itemId,
      specifiedType: const FullType(String),
    );
    yield r'instituicao';
    yield serializers.serialize(
      object.instituicao,
      specifiedType: const FullType(String),
    );
    yield r'consentimento_expira_em';
    yield object.consentimentoExpiraEm == null ? null : serializers.serialize(
      object.consentimentoExpiraEm,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'contas';
    yield serializers.serialize(
      object.contas,
      specifiedType: const FullType(BuiltList, [FullType(ContaDaPreviaSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PreviaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PreviaSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'item_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.itemId = valueDes;
          break;
        case r'instituicao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.instituicao = valueDes;
          break;
        case r'consentimento_expira_em':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.consentimentoExpiraEm = valueDes;
          break;
        case r'contas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ContaDaPreviaSaida)]),
          ) as BuiltList<ContaDaPreviaSaida>;
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
  PreviaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PreviaSaidaBuilder();
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


