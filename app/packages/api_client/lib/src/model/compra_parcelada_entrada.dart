//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'compra_parcelada_entrada.g.dart';

/// Compra parcelada no cartão: gera uma despesa por parcela, cada uma na sua fatura. À vista é o lançamento comum.
///
/// Properties:
/// * [contaId] 
/// * [valorTotal] - O total da compra; o centavo que sobra da divisão vai para a 1ª parcela.
/// * [qtdParcelas] 
/// * [dataCompra] 
/// * [descricao] 
/// * [categoriaId] - De gasto e ativa; vale para todas as parcelas.
@BuiltValue()
abstract class CompraParceladaEntrada implements Built<CompraParceladaEntrada, CompraParceladaEntradaBuilder> {
  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  /// O total da compra; o centavo que sobra da divisão vai para a 1ª parcela.
  @BuiltValueField(wireName: r'valor_total')
  String get valorTotal;

  @BuiltValueField(wireName: r'qtd_parcelas')
  int get qtdParcelas;

  @BuiltValueField(wireName: r'data_compra')
  Date get dataCompra;

  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  /// De gasto e ativa; vale para todas as parcelas.
  @BuiltValueField(wireName: r'categoria_id')
  String? get categoriaId;

  CompraParceladaEntrada._();

  factory CompraParceladaEntrada([void updates(CompraParceladaEntradaBuilder b)]) = _$CompraParceladaEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompraParceladaEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompraParceladaEntrada> get serializer => _$CompraParceladaEntradaSerializer();
}

class _$CompraParceladaEntradaSerializer implements PrimitiveSerializer<CompraParceladaEntrada> {
  @override
  final Iterable<Type> types = const [CompraParceladaEntrada, _$CompraParceladaEntrada];

  @override
  final String wireName = r'CompraParceladaEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompraParceladaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conta_id';
    yield serializers.serialize(
      object.contaId,
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
    yield r'descricao';
    yield serializers.serialize(
      object.descricao,
      specifiedType: const FullType(String),
    );
    if (object.categoriaId != null) {
      yield r'categoria_id';
      yield serializers.serialize(
        object.categoriaId,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CompraParceladaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CompraParceladaEntradaBuilder result,
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
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.categoriaId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CompraParceladaEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompraParceladaEntradaBuilder();
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


