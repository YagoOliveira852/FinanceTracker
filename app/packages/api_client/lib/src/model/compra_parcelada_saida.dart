//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/date.dart';
import 'package:api_client/src/model/transacao_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'compra_parcelada_saida.g.dart';

/// CompraParceladaSaida
///
/// Properties:
/// * [id] 
/// * [descricao] 
/// * [valorTotal] 
/// * [qtdParcelas] 
/// * [dataCompra] 
/// * [dataCompraEstimada] 
/// * [parcelas] - Da 1ª à última parcela.
@BuiltValue()
abstract class CompraParceladaSaida implements Built<CompraParceladaSaida, CompraParceladaSaidaBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  @BuiltValueField(wireName: r'valor_total')
  String get valorTotal;

  @BuiltValueField(wireName: r'qtd_parcelas')
  int get qtdParcelas;

  @BuiltValueField(wireName: r'data_compra')
  Date get dataCompra;

  @BuiltValueField(wireName: r'data_compra_estimada')
  bool get dataCompraEstimada;

  /// Da 1ª à última parcela.
  @BuiltValueField(wireName: r'parcelas')
  BuiltList<TransacaoSaida> get parcelas;

  CompraParceladaSaida._();

  factory CompraParceladaSaida([void updates(CompraParceladaSaidaBuilder b)]) = _$CompraParceladaSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompraParceladaSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompraParceladaSaida> get serializer => _$CompraParceladaSaidaSerializer();
}

class _$CompraParceladaSaidaSerializer implements PrimitiveSerializer<CompraParceladaSaida> {
  @override
  final Iterable<Type> types = const [CompraParceladaSaida, _$CompraParceladaSaida];

  @override
  final String wireName = r'CompraParceladaSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompraParceladaSaida object, {
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
    yield r'valor_total';
    yield serializers.serialize(
      object.valorTotal,
      specifiedType: const FullType(String),
    );
    yield r'qtd_parcelas';
    yield serializers.serialize(
      object.qtdParcelas,
      specifiedType: const FullType(int),
    );
    yield r'data_compra';
    yield serializers.serialize(
      object.dataCompra,
      specifiedType: const FullType(Date),
    );
    yield r'data_compra_estimada';
    yield serializers.serialize(
      object.dataCompraEstimada,
      specifiedType: const FullType(bool),
    );
    yield r'parcelas';
    yield serializers.serialize(
      object.parcelas,
      specifiedType: const FullType(BuiltList, [FullType(TransacaoSaida)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CompraParceladaSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CompraParceladaSaidaBuilder result,
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
        case r'valor_total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.valorTotal = valueDes;
          break;
        case r'qtd_parcelas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.qtdParcelas = valueDes;
          break;
        case r'data_compra':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataCompra = valueDes;
          break;
        case r'data_compra_estimada':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.dataCompraEstimada = valueDes;
          break;
        case r'parcelas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TransacaoSaida)]),
          ) as BuiltList<TransacaoSaida>;
          result.parcelas.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CompraParceladaSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompraParceladaSaidaBuilder();
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


