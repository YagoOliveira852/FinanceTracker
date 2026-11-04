//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resultado_sync_saida.g.dart';

/// ResultadoSyncSaida
///
/// Properties:
/// * [ok] 
/// * [erro] 
/// * [novas] 
/// * [atualizadas] 
/// * [removidas] - Rascunhos que sumiram da Pluggy e foram apagados.
/// * [marcadasRemovidas] - Confirmadas que sumiram da Pluggy (alerta na revisão).
@BuiltValue()
abstract class ResultadoSyncSaida implements Built<ResultadoSyncSaida, ResultadoSyncSaidaBuilder> {
  @BuiltValueField(wireName: r'ok')
  bool get ok;

  @BuiltValueField(wireName: r'erro')
  String? get erro;

  @BuiltValueField(wireName: r'novas')
  int get novas;

  @BuiltValueField(wireName: r'atualizadas')
  int get atualizadas;

  /// Rascunhos que sumiram da Pluggy e foram apagados.
  @BuiltValueField(wireName: r'removidas')
  int get removidas;

  /// Confirmadas que sumiram da Pluggy (alerta na revisão).
  @BuiltValueField(wireName: r'marcadas_removidas')
  int get marcadasRemovidas;

  ResultadoSyncSaida._();

  factory ResultadoSyncSaida([void updates(ResultadoSyncSaidaBuilder b)]) = _$ResultadoSyncSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResultadoSyncSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResultadoSyncSaida> get serializer => _$ResultadoSyncSaidaSerializer();
}

class _$ResultadoSyncSaidaSerializer implements PrimitiveSerializer<ResultadoSyncSaida> {
  @override
  final Iterable<Type> types = const [ResultadoSyncSaida, _$ResultadoSyncSaida];

  @override
  final String wireName = r'ResultadoSyncSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResultadoSyncSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'ok';
    yield serializers.serialize(
      object.ok,
      specifiedType: const FullType(bool),
    );
    yield r'erro';
    yield object.erro == null ? null : serializers.serialize(
      object.erro,
      specifiedType: const FullType.nullable(String),
    );
    yield r'novas';
    yield serializers.serialize(
      object.novas,
      specifiedType: const FullType(int),
    );
    yield r'atualizadas';
    yield serializers.serialize(
      object.atualizadas,
      specifiedType: const FullType(int),
    );
    yield r'removidas';
    yield serializers.serialize(
      object.removidas,
      specifiedType: const FullType(int),
    );
    yield r'marcadas_removidas';
    yield serializers.serialize(
      object.marcadasRemovidas,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResultadoSyncSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ResultadoSyncSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'ok':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.ok = valueDes;
          break;
        case r'erro':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.erro = valueDes;
          break;
        case r'novas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.novas = valueDes;
          break;
        case r'atualizadas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.atualizadas = valueDes;
          break;
        case r'removidas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.removidas = valueDes;
          break;
        case r'marcadas_removidas':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.marcadasRemovidas = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResultadoSyncSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResultadoSyncSaidaBuilder();
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


