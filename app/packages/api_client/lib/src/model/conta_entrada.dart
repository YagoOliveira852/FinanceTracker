//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:api_client/src/model/date.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'conta_entrada.g.dart';

/// ContaEntrada
///
/// Properties:
/// * [nome] 
/// * [tipo] 
/// * [instituicao] - Nome da instituição. Obrigatório na conta corrente e ausente na carteira. Se nenhuma instituição tiver esse nome (sem diferenciar maiúsculas), uma nova é criada.
/// * [saldoInicial] - Saldo no começo do dia `data_saldo_inicial`.
/// * [dataSaldoInicial] - Não pode ser depois de hoje.
@BuiltValue()
abstract class ContaEntrada implements Built<ContaEntrada, ContaEntradaBuilder> {
  @BuiltValueField(wireName: r'nome')
  String get nome;

  @BuiltValueField(wireName: r'tipo')
  ContaEntradaTipoEnum get tipo;
  // enum tipoEnum {  corrente,  carteira,  };

  /// Nome da instituição. Obrigatório na conta corrente e ausente na carteira. Se nenhuma instituição tiver esse nome (sem diferenciar maiúsculas), uma nova é criada.
  @BuiltValueField(wireName: r'instituicao')
  String? get instituicao;

  /// Saldo no começo do dia `data_saldo_inicial`.
  @BuiltValueField(wireName: r'saldo_inicial')
  String get saldoInicial;

  /// Não pode ser depois de hoje.
  @BuiltValueField(wireName: r'data_saldo_inicial')
  Date get dataSaldoInicial;

  ContaEntrada._();

  factory ContaEntrada([void updates(ContaEntradaBuilder b)]) = _$ContaEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContaEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContaEntrada> get serializer => _$ContaEntradaSerializer();
}

class _$ContaEntradaSerializer implements PrimitiveSerializer<ContaEntrada> {
  @override
  final Iterable<Type> types = const [ContaEntrada, _$ContaEntrada];

  @override
  final String wireName = r'ContaEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'nome';
    yield serializers.serialize(
      object.nome,
      specifiedType: const FullType(String),
    );
    yield r'tipo';
    yield serializers.serialize(
      object.tipo,
      specifiedType: const FullType(ContaEntradaTipoEnum),
    );
    if (object.instituicao != null) {
      yield r'instituicao';
      yield serializers.serialize(
        object.instituicao,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'saldo_inicial';
    yield serializers.serialize(
      object.saldoInicial,
      specifiedType: const FullType(String),
    );
    yield r'data_saldo_inicial';
    yield serializers.serialize(
      object.dataSaldoInicial,
      specifiedType: const FullType(Date),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContaEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'nome':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nome = valueDes;
          break;
        case r'tipo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ContaEntradaTipoEnum),
          ) as ContaEntradaTipoEnum;
          result.tipo = valueDes;
          break;
        case r'instituicao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.instituicao = valueDes;
          break;
        case r'saldo_inicial':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.saldoInicial = valueDes;
          break;
        case r'data_saldo_inicial':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Date),
          ) as Date;
          result.dataSaldoInicial = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContaEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContaEntradaBuilder();
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


class ContaEntradaTipoEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'corrente')
  static const ContaEntradaTipoEnum corrente = _$contaEntradaTipoEnum_corrente;
  @BuiltValueEnumConst(wireName: r'carteira')
  static const ContaEntradaTipoEnum carteira = _$contaEntradaTipoEnum_carteira;

  static Serializer<ContaEntradaTipoEnum> get serializer => _$contaEntradaTipoEnumSerializer;

  const ContaEntradaTipoEnum._(String name): super(name);

  static BuiltSet<ContaEntradaTipoEnum> get values => _$contaEntradaTipoEnumValues;
  static ContaEntradaTipoEnum valueOf(String name) => _$contaEntradaTipoEnumValueOf(name);
}

