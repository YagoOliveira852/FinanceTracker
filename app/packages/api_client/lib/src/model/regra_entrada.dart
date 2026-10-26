//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'regra_entrada.g.dart';

/// RegraEntrada
///
/// Properties:
/// * [padrao] - Normalizado ao salvar: sem acentos, números, datas e termos genéricos como \"pix enviado\". Não pode ficar vazio depois disso.
/// * [categoriaId] - Categoria ativa.
/// * [contaId] - Restringe a regra a uma conta ativa; nulo = todas.
@BuiltValue()
abstract class RegraEntrada implements Built<RegraEntrada, RegraEntradaBuilder> {
  /// Normalizado ao salvar: sem acentos, números, datas e termos genéricos como \"pix enviado\". Não pode ficar vazio depois disso.
  @BuiltValueField(wireName: r'padrao')
  String get padrao;

  /// Categoria ativa.
  @BuiltValueField(wireName: r'categoria_id')
  String get categoriaId;

  /// Restringe a regra a uma conta ativa; nulo = todas.
  @BuiltValueField(wireName: r'conta_id')
  String? get contaId;

  RegraEntrada._();

  factory RegraEntrada([void updates(RegraEntradaBuilder b)]) = _$RegraEntrada;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RegraEntradaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RegraEntrada> get serializer => _$RegraEntradaSerializer();
}

class _$RegraEntradaSerializer implements PrimitiveSerializer<RegraEntrada> {
  @override
  final Iterable<Type> types = const [RegraEntrada, _$RegraEntrada];

  @override
  final String wireName = r'RegraEntrada';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RegraEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'padrao';
    yield serializers.serialize(
      object.padrao,
      specifiedType: const FullType(String),
    );
    yield r'categoria_id';
    yield serializers.serialize(
      object.categoriaId,
      specifiedType: const FullType(String),
    );
    if (object.contaId != null) {
      yield r'conta_id';
      yield serializers.serialize(
        object.contaId,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    RegraEntrada object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RegraEntradaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'padrao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.padrao = valueDes;
          break;
        case r'categoria_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.categoriaId = valueDes;
          break;
        case r'conta_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
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
  RegraEntrada deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RegraEntradaBuilder();
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


