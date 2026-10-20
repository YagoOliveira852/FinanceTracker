//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'tipo_transacao.g.dart';

class TipoTransacao extends EnumClass {

  @BuiltValueEnumConst(wireName: r'despesa')
  static const TipoTransacao despesa = _$despesa;
  @BuiltValueEnumConst(wireName: r'receita')
  static const TipoTransacao receita = _$receita;
  @BuiltValueEnumConst(wireName: r'transferencia_saida')
  static const TipoTransacao transferenciaSaida = _$transferenciaSaida;
  @BuiltValueEnumConst(wireName: r'transferencia_entrada')
  static const TipoTransacao transferenciaEntrada = _$transferenciaEntrada;
  @BuiltValueEnumConst(wireName: r'pagamento_fatura')
  static const TipoTransacao pagamentoFatura = _$pagamentoFatura;
  @BuiltValueEnumConst(wireName: r'aporte')
  static const TipoTransacao aporte = _$aporte;
  @BuiltValueEnumConst(wireName: r'resgate')
  static const TipoTransacao resgate = _$resgate;
  @BuiltValueEnumConst(wireName: r'estorno')
  static const TipoTransacao estorno = _$estorno;
  @BuiltValueEnumConst(wireName: r'ajuste_entrada')
  static const TipoTransacao ajusteEntrada = _$ajusteEntrada;
  @BuiltValueEnumConst(wireName: r'ajuste_saida')
  static const TipoTransacao ajusteSaida = _$ajusteSaida;

  static Serializer<TipoTransacao> get serializer => _$tipoTransacaoSerializer;

  const TipoTransacao._(String name): super(name);

  static BuiltSet<TipoTransacao> get values => _$values;
  static TipoTransacao valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class TipoTransacaoMixin = Object with _$TipoTransacaoMixin;

