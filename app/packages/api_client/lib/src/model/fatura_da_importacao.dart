//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_da_importacao.g.dart';

/// FaturaDaImportacao
///
/// Properties:
/// * [competencia] - Primeiro dia do mês do vencimento.
/// * [valorInformado] - O valor do banco gravado na fatura.
/// * [dataFechamento] - O fechamento do arquivo, gravado na fatura.
@BuiltValue()
abstract class FaturaDaImportacao implements Built<FaturaDaImportacao, FaturaDaImportacaoBuilder> {
  /// Primeiro dia do mês do vencimento.
  @BuiltValueField(wireName: r'competencia')
  Date get competencia;

  /// O valor do banco gravado na fatura.
  @BuiltValueField(wireName: r'valor_informado')
  String? get valorInformado;

  /// O fechamento do arquivo, gravado na fatura.
  @BuiltValueField(wireName: r'data_fechamento')
  Date get dataFechamento;

  FaturaDaImportacao._();

  factory FaturaDaImportacao([void updates(FaturaDaImportacaoBuilder b)]) = _$FaturaDaImportacao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaDaImportacaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaDaImportacao> get serializer => _$FaturaDaImportacaoSerializer();
}

class _$FaturaDaImportacaoSerializer implements PrimitiveSerializer<FaturaDaImportacao> {
  @override
  final Iterable<Type> types = const [FaturaDaImportacao, _$FaturaDaImportacao];

  @override
  final String wireName = r'FaturaDaImportacao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaDaImportacao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'competencia';
    yield serializers.serialize(
      object.competencia,
      specifiedType: const FullType(Date),
    );
    yield r'valor_informado';
    yield object.valorInformado == null ? null : serializers.serialize(
      object.valorInformado,
      specifiedType: const FullType.nullable(String),
    );
    yield r'data_fechamento';
    yield serializers.serialize(
      object.dataFechamento,
      specifiedType: const FullType(Date),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaDaImportacao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaDaImportacaoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'competencia':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.competencia = valueDes;
          break;
        case r'valor_informado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.valorInformado = valueDes;
          break;
        case r'data_fechamento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataFechamento = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaDaImportacao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaDaImportacaoBuilder();
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


