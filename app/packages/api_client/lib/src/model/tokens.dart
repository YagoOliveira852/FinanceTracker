//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'tokens.g.dart';

/// Tokens
///
/// Properties:
/// * [accessToken] 
/// * [refreshToken] 
/// * [tokenType] 
/// * [expiresIn] - Segundos até o access token expirar.
@BuiltValue()
abstract class Tokens implements Built<Tokens, TokensBuilder> {
  @BuiltValueField(wireName: r'access_token')
  String get accessToken;

  @BuiltValueField(wireName: r'refresh_token')
  String get refreshToken;

  @BuiltValueField(wireName: r'token_type')
  TokensTokenTypeEnum? get tokenType;
  // enum tokenTypeEnum {  bearer,  };

  /// Segundos até o access token expirar.
  @BuiltValueField(wireName: r'expires_in')
  int get expiresIn;

  Tokens._();

  factory Tokens([void updates(TokensBuilder b)]) = _$Tokens;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TokensBuilder b) => b
      ..tokenType = TokensTokenTypeEnum.valueOf('bearer');

  @BuiltValueSerializer(custom: true)
  static Serializer<Tokens> get serializer => _$TokensSerializer();
}

class _$TokensSerializer implements PrimitiveSerializer<Tokens> {
  @override
  final Iterable<Type> types = const [Tokens, _$Tokens];

  @override
  final String wireName = r'Tokens';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Tokens object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'access_token';
    yield serializers.serialize(
      object.accessToken,
      specifiedType: const FullType(String),
    );
    yield r'refresh_token';
    yield serializers.serialize(
      object.refreshToken,
      specifiedType: const FullType(String),
    );
    if (object.tokenType != null) {
      yield r'token_type';
      yield serializers.serialize(
        object.tokenType,
        specifiedType: const FullType(TokensTokenTypeEnum),
      );
    }
    yield r'expires_in';
    yield serializers.serialize(
      object.expiresIn,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Tokens object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TokensBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'access_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accessToken = valueDes;
          break;
        case r'refresh_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.refreshToken = valueDes;
          break;
        case r'token_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(TokensTokenTypeEnum),
          ) as TokensTokenTypeEnum?;
          if (valueDes == null) continue;
          result.tokenType = valueDes;
          break;
        case r'expires_in':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.expiresIn = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Tokens deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TokensBuilder();
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


class TokensTokenTypeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'bearer')
  static const TokensTokenTypeEnum bearer = _$tokensTokenTypeEnum_bearer;

  static Serializer<TokensTokenTypeEnum> get serializer => _$tokensTokenTypeEnumSerializer;

  const TokensTokenTypeEnum._(String name): super(name);

  static BuiltSet<TokensTokenTypeEnum> get values => _$tokensTokenTypeEnumValues;
  static TokensTokenTypeEnum valueOf(String name) => _$tokensTokenTypeEnumValueOf(name);
}

