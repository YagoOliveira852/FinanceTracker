//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:api_client/src/model/importacao_saida.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resultado_importacao_saida.g.dart';

/// ResultadoImportacaoSaida
///
/// Properties:
/// * [jaImportada] - O arquivo já tinha sido importado: `importacao` é a anterior, nada mudou.
/// * [importacao] 
@BuiltValue()
abstract class ResultadoImportacaoSaida implements Built<ResultadoImportacaoSaida, ResultadoImportacaoSaidaBuilder> {
  /// O arquivo já tinha sido importado: `importacao` é a anterior, nada mudou.
  @BuiltValueField(wireName: r'ja_importada')
  bool get jaImportada;

  @BuiltValueField(wireName: r'importacao')
  ImportacaoSaida get importacao;

  ResultadoImportacaoSaida._();

  factory ResultadoImportacaoSaida([void updates(ResultadoImportacaoSaidaBuilder b)]) = _$ResultadoImportacaoSaida;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResultadoImportacaoSaidaBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResultadoImportacaoSaida> get serializer => _$ResultadoImportacaoSaidaSerializer();
}

class _$ResultadoImportacaoSaidaSerializer implements PrimitiveSerializer<ResultadoImportacaoSaida> {
  @override
  final Iterable<Type> types = const [ResultadoImportacaoSaida, _$ResultadoImportacaoSaida];

  @override
  final String wireName = r'ResultadoImportacaoSaida';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResultadoImportacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'ja_importada';
    yield serializers.serialize(
      object.jaImportada,
      specifiedType: const FullType(bool),
    );
    yield r'importacao';
    yield serializers.serialize(
      object.importacao,
      specifiedType: const FullType(ImportacaoSaida),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResultadoImportacaoSaida object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ResultadoImportacaoSaidaBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'ja_importada':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.jaImportada = valueDes;
          break;
        case r'importacao':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ImportacaoSaida),
          ) as ImportacaoSaida;
          result.importacao.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResultadoImportacaoSaida deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResultadoImportacaoSaidaBuilder();
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


