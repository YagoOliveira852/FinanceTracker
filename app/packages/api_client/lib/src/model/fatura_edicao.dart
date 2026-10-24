//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fatura_edicao.g.dart';

/// Os três campos vão sempre (o formulário manda tudo): `valor_informado` nulo apaga o valor informado.
///
/// Properties:
/// * [dataFechamento] 
/// * [dataVencimento] 
/// * [valorInformado] 
@BuiltValue()
abstract class FaturaEdicao implements Built<FaturaEdicao, FaturaEdicaoBuilder> {
  @BuiltValueField(wireName: r'data_fechamento')
  Date get dataFechamento;

  @BuiltValueField(wireName: r'data_vencimento')
  Date get dataVencimento;

  @BuiltValueField(wireName: r'valor_informado')
  String? get valorInformado;

  FaturaEdicao._();

  factory FaturaEdicao([void updates(FaturaEdicaoBuilder b)]) = _$FaturaEdicao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FaturaEdicaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FaturaEdicao> get serializer => _$FaturaEdicaoSerializer();
}

class _$FaturaEdicaoSerializer implements PrimitiveSerializer<FaturaEdicao> {
  @override
  final Iterable<Type> types = const [FaturaEdicao, _$FaturaEdicao];

  @override
  final String wireName = r'FaturaEdicao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FaturaEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data_fechamento';
    yield serializers.serialize(
      object.dataFechamento,
      specifiedType: const FullType(Date),
    );
    yield r'data_vencimento';
    yield serializers.serialize(
      object.dataVencimento,
      specifiedType: const FullType(Date),
    );
    yield r'valor_informado';
    yield object.valorInformado == null ? null : serializers.serialize(
      object.valorInformado,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FaturaEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FaturaEdicaoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data_fechamento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataFechamento = valueDes;
          break;
        case r'data_vencimento':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataVencimento = valueDes;
          break;
        case r'valor_informado':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.valorInformado = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FaturaEdicao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FaturaEdicaoBuilder();
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


