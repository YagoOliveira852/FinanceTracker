//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'status_transacao.g.dart';

class StatusTransacao extends EnumClass {

  @BuiltValueEnumConst(wireName: r'rascunho')
  static const StatusTransacao rascunho = _$rascunho;
  @BuiltValueEnumConst(wireName: r'confirmada')
  static const StatusTransacao confirmada = _$confirmada;
  @BuiltValueEnumConst(wireName: r'ignorada')
  static const StatusTransacao ignorada = _$ignorada;

  static Serializer<StatusTransacao> get serializer => _$statusTransacaoSerializer;

  const StatusTransacao._(String name): super(name);

  static BuiltSet<StatusTransacao> get values => _$values;
  static StatusTransacao valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class StatusTransacaoMixin = Object with _$StatusTransacaoMixin;

