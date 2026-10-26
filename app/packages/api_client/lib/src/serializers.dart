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

import 'package:api_client/src/model/ajuste_data_saida.dart';
import 'package:api_client/src/model/ajuste_entrada.dart';
import 'package:api_client/src/model/cartao_edicao.dart';
import 'package:api_client/src/model/cartao_entrada.dart';
import 'package:api_client/src/model/cartao_saida.dart';
import 'package:api_client/src/model/categoria_edicao.dart';
import 'package:api_client/src/model/categoria_entrada.dart';
import 'package:api_client/src/model/categoria_resumo.dart';
import 'package:api_client/src/model/categoria_saida.dart';
import 'package:api_client/src/model/compra_parcelada_entrada.dart';
import 'package:api_client/src/model/compra_parcelada_saida.dart';
import 'package:api_client/src/model/conta_da_regra.dart';
import 'package:api_client/src/model/conta_entrada.dart';
import 'package:api_client/src/model/conta_saida.dart';
import 'package:api_client/src/model/contas_resumo.dart';
import 'package:api_client/src/model/datas_fatura_saida.dart';
import 'package:api_client/src/model/erro_campo.dart';
import 'package:api_client/src/model/exemplo_rascunho.dart';
import 'package:api_client/src/model/fatura_detalhe_saida.dart';
import 'package:api_client/src/model/fatura_edicao.dart';
import 'package:api_client/src/model/fatura_resumo.dart';
import 'package:api_client/src/model/feriado_saida.dart';
import 'package:api_client/src/model/fonte_transacao.dart';
import 'package:api_client/src/model/grupo_categoria.dart';
import 'package:api_client/src/model/http_validation_error.dart';
import 'package:api_client/src/model/instituicao_saida.dart';
import 'package:api_client/src/model/lista_faturas_saida.dart';
import 'package:api_client/src/model/location_inner.dart';
import 'package:api_client/src/model/login_entrada.dart';
import 'package:api_client/src/model/origem_regra.dart';
import 'package:api_client/src/model/pagamento_entrada.dart';
import 'package:api_client/src/model/parcela_saida.dart';
import 'package:api_client/src/model/rascunhos_casados_saida.dart';
import 'package:api_client/src/model/refresh_entrada.dart';
import 'package:api_client/src/model/regra_detalhe_saida.dart';
import 'package:api_client/src/model/regra_entrada.dart';
import 'package:api_client/src/model/regra_saida.dart';
import 'package:api_client/src/model/resposta_erro.dart';
import 'package:api_client/src/model/saude.dart';
import 'package:api_client/src/model/status_fatura.dart';
import 'package:api_client/src/model/status_transacao.dart';
import 'package:api_client/src/model/tipo_conta.dart';
import 'package:api_client/src/model/tipo_transacao.dart';
import 'package:api_client/src/model/tokens.dart';
import 'package:api_client/src/model/transacao_entrada.dart';
import 'package:api_client/src/model/transacao_saida.dart';
import 'package:api_client/src/model/transferencia_entrada.dart';
import 'package:api_client/src/model/transferencia_par_saida.dart';
import 'package:api_client/src/model/transferencia_saida.dart';
import 'package:api_client/src/model/usuario_saida.dart';
import 'package:api_client/src/model/validation_error.dart';

part 'serializers.g.dart';

@SerializersFor([
  AjusteDataSaida,
  AjusteEntrada,
  CartaoEdicao,
  CartaoEntrada,
  CartaoSaida,
  CategoriaEdicao,
  CategoriaEntrada,
  CategoriaResumo,
  CategoriaSaida,
  CompraParceladaEntrada,
  CompraParceladaSaida,
  ContaDaRegra,
  ContaEntrada,
  ContaSaida,
  ContasResumo,
  DatasFaturaSaida,
  ErroCampo,
  ExemploRascunho,
  FaturaDetalheSaida,
  FaturaEdicao,
  FaturaResumo,
  FeriadoSaida,
  FonteTransacao,
  GrupoCategoria,
  HTTPValidationError,
  InstituicaoSaida,
  ListaFaturasSaida,
  LocationInner,
  LoginEntrada,
  OrigemRegra,
  PagamentoEntrada,
  ParcelaSaida,
  RascunhosCasadosSaida,
  RefreshEntrada,
  RegraDetalheSaida,
  RegraEntrada,
  RegraSaida,
  RespostaErro,
  Saude,
  StatusFatura,
  StatusTransacao,
  TipoConta,
  TipoTransacao,
  Tokens,
  TransacaoEntrada,
  TransacaoSaida,
  TransferenciaEntrada,
  TransferenciaParSaida,
  TransferenciaSaida,
  UsuarioSaida,
  ValidationError,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(FeriadoSaida)]),
        () => ListBuilder<FeriadoSaida>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(FaturaResumo)]),
        () => ListBuilder<FaturaResumo>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(LocationInner)]),
        () => ListBuilder<LocationInner>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(CategoriaSaida)]),
        () => ListBuilder<CategoriaSaida>(),
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
        const FullType(BuiltList, [FullType(RegraSaida)]),
        () => ListBuilder<RegraSaida>(),
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
