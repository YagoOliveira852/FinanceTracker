//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/fatura_resumo.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'lista_faturas_saida.g.dart';

/// ListaFaturasSaida
///
/// Properties:
/// * [atual] - A fatura de uma compra feita hoje.
/// * [proximas] - Gravadas depois da atual, em ordem.
/// * [anteriores] - Gravadas antes da atual, da mais recente.
@BuiltValue()
abstract class ListaFaturasSaida implements Built<ListaFaturasSaida, ListaFaturasSaidaBuilder> {
  /// A fatura de uma compra feita hoje.
  @BuiltValueField(wireName: r'atual')
  FaturaResumo get atual;

  /// Gravadas depois da atual, em ordem.
  @BuiltValueField(wireName: r'proximas')
  BuiltList<FaturaResumo> get proximas;

  /// Gravadas antes da atual, da mais recente.
  @BuiltValueField(wireName: r'anteriores')
  BuiltList<FaturaResumo> get anteriores;

  ListaFaturasSaida._();

  factory ListaFaturasSaida([void updates(ListaFaturasSaidaBuilder b)]) = _$ListaFaturasSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ListaFaturasSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ListaFaturasSaida> get serializer => _$ListaFaturasSaidaSerializer();
}

class _$ListaFaturasSaidaSerializer implements PrimitiveSerializer<ListaFaturasSaida> {
  @override
  final Iterable<Type> types = const [ListaFaturasSaida, _$ListaFaturasSaida];

  @override
  final String wireName = r'ListaFaturasSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ListaFaturasSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'atual';
    yield serializers.serialize(
      object.atual,
      specifiedType: const FullType(FaturaResumo),
    );
    yield r'proximas';
    yield serializers.serialize(
      object.proximas,
      specifiedType: const FullType(BuiltList, [FullType(FaturaResumo)]),
    );
    yield r'anteriores';
    yield serializers.serialize(
      object.anteriores,
      specifiedType: const FullType(BuiltList, [FullType(FaturaResumo)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ListaFaturasSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ListaFaturasSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'atual':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(FaturaResumo),
          ) as FaturaResumo;
          result.atual.replace(valueDes);
          break;
        case r'proximas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(FaturaResumo)]),
          ) as BuiltList<FaturaResumo>;
          result.proximas.replace(valueDes);
          break;
        case r'anteriores':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(FaturaResumo)]),
          ) as BuiltList<FaturaResumo>;
          result.anteriores.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ListaFaturasSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ListaFaturasSaidaBuilder();
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


