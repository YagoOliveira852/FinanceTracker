//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'renda_entrada.g.dart';

/// As regras (descrição preenchida, valor > 0, dia de 1 a 31, conta corrente ou carteira ativa) ficam no service, com as mensagens da tela.
///
/// Properties:
/// * [descricao] 
/// * [valor] - O líquido que cai na conta; maior que zero.
/// * [diaPrevisto] - Dia do mês, de 1 a 31.
/// * [contaId] - Corrente ou carteira ativa onde o crédito aparece.
@BuiltValue()
abstract class RendaEntrada implements Built<RendaEntrada, RendaEntradaBuilder> {
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

  RendaEntrada._();

  factory RendaEntrada([void updates(RendaEntradaBuilder b)]) = _$RendaEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RendaEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RendaEntrada> get serializer => _$RendaEntradaSerializer();
}

class _$RendaEntradaSerializer implements PrimitiveSerializer<RendaEntrada> {
  @override
  final Iterable<Type> types = const [RendaEntrada, _$RendaEntrada];

  @override
  final String wireName = r'RendaEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RendaEntrada object, {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    RendaEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RendaEntradaBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RendaEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RendaEntradaBuilder();
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


