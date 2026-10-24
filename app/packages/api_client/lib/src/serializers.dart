//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:api_client/src/date_serializer.dart';
import 'package:api_client/src/model/date.dart';

import 'package:api_client/src/model/cartao_entrada.dart';
import 'package:api_client/src/model/cartao_saida.dart';
import 'package:api_client/src/model/conta_entrada.dart';
import 'package:api_client/src/model/conta_saida.dart';
import 'package:api_client/src/model/contas_resumo.dart';
import 'package:api_client/src/model/datas_fatura_saida.dart';
import 'package:api_client/src/model/erro_campo.dart';
import 'package:api_client/src/model/fatura_resumo.dart';
import 'package:api_client/src/model/fonte_transacao.dart';
import 'package:api_client/src/model/http_validation_error.dart';
import 'package:api_client/src/model/instituicao_saida.dart';
import 'package:api_client/src/model/location_inner.dart';
import 'package:api_client/src/model/login_entrada.dart';
import 'package:api_client/src/model/refresh_entrada.dart';
import 'package:api_client/src/model/resposta_erro.dart';
import 'package:api_client/src/model/saude.dart';
import 'package:api_client/src/model/status_fatura.dart';
import 'package:api_client/src/model/status_transacao.dart';
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:api_client/src/model/tipo_transacao.dart';
import 'package:api_client/src/model/tokens.dart';
import 'package:api_client/src/model/transacao_entrada.dart';
import 'package:api_client/src/model/transacao_saida.dart';
import 'package:api_client/src/model/usuario_saida.dart';
import 'package:api_client/src/model/validation_error.dart';

part 'serializers.g.dart';

@SerializersFor([
  CartaoEntrada,
  CartaoSaida,
  ContaEntrada,
  ContaSaida,
  ContasResumo,
  DatasFaturaSaida,
  ErroCampo,
  FaturaResumo,
  FonteTransacao,
  HTTPValidationError,
  InstituicaoSaida,
  LocationInner,
  LoginEntrada,
  RefreshEntrada,
  RespostaErro,
  Saude,
  StatusFatura,
  StatusTransacao,
  TipoConta,
  TipoTransacao,
  Tokens,
  TransacaoEntrada,
  TransacaoSaida,
  UsuarioSaida,
  ValidationError,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(LocationInner)]),
        () => ListBuilder<LocationInner>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ContaSaida)]),
        () => ListBuilder<ContaSaida>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ValidationError)]),
        () => ListBuilder<ValidationError>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ErroCampo)]),
        () => ListBuilder<ErroCampo>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(TransacaoSaida)]),
        () => ListBuilder<TransacaoSaida>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
