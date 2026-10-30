//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'renda_edicao.g.dart';

/// Os campos do cadastro, mais `ativa` (desativar ou reativar).
///
/// Properties:
/// * [descricao] 
/// * [valor] - O líquido que cai na conta; maior que zero.
/// * [diaPrevisto] - Dia do mês, de 1 a 31.
/// * [contaId] - Corrente ou carteira ativa onde o crédito aparece.
/// * [ativa] 
@BuiltValue()
abstract class RendaEdicao implements Built<RendaEdicao, RendaEdicaoBuilder> {
  @BuiltValueField(wireName: r'descricao')
  String get descricao;

  /// O líquido que cai na conta; maior que zero.
  @BuiltValueField(wireName: r'valor')
  String get valor;

  /// Dia do mês, de 1 a 31.
  @BuiltValueField(wireName: r'dia_previsto')
  int get diaPrevisto;

  /// Corrente ou carteira ativa onde o crédito aparece.
  @BuiltValueField(wireName: r'conta_id')
  String get contaId;

  @BuiltValueField(wireName: r'ativa')
  bool get ativa;

  RendaEdicao._();

  factory RendaEdicao([void updates(RendaEdicaoBuilder b)]) = _$RendaEdicao;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RendaEdicaoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RendaEdicao> get serializer => _$RendaEdicaoSerializer();
}

class _$RendaEdicaoSerializer implements PrimitiveSerializer<RendaEdicao> {
  @override
  final Iterable<Type> types = const [RendaEdicao, _$RendaEdicao];

  @override
  final String wireName = r'RendaEdicao';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RendaEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    RendaEdicao object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RendaEdicaoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RendaEdicao deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RendaEdicaoBuilder();
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


