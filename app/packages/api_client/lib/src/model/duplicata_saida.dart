//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/transacao_revisao.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'duplicata_saida.g.dart';

/// DuplicataSaida
///
/// Properties:
/// * [rascunho] - O que chegou por último, marcado.
/// * [outra] - A que já estava (confirmada ou rascunho).
@BuiltValue()
abstract class DuplicataSaida implements Built<DuplicataSaida, DuplicataSaidaBuilder> {
  /// O que chegou por último, marcado.
  @BuiltValueField(wireName: r'rascunho')
  TransacaoRevisao get rascunho;

  /// A que já estava (confirmada ou rascunho).
  @BuiltValueField(wireName: r'outra')
  TransacaoRevisao get outra;

  DuplicataSaida._();

  factory DuplicataSaida([void updates(DuplicataSaidaBuilder b)]) = _$DuplicataSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DuplicataSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DuplicataSaida> get serializer => _$DuplicataSaidaSerializer();
}

class _$DuplicataSaidaSerializer implements PrimitiveSerializer<DuplicataSaida> {
  @override
  final Iterable<Type> types = const [DuplicataSaida, _$DuplicataSaida];

  @override
  final String wireName = r'DuplicataSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DuplicataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'rascunho';
    yield serializers.serialize(
      object.rascunho,
      specifiedType: const FullType(TransacaoRevisao),
    );
    yield r'outra';
    yield serializers.serialize(
      object.outra,
      specifiedType: const FullType(TransacaoRevisao),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DuplicataSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DuplicataSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'rascunho':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoRevisao),
          ) as TransacaoRevisao;
          result.rascunho.replace(valueDes);
          break;
        case r'outra':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransacaoRevisao),
          ) as TransacaoRevisao;
          result.outra.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DuplicataSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DuplicataSaidaBuilder();
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


