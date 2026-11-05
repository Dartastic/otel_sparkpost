// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_sparkpost_suppression.dart';

const _tracerName = 'dartastic_otel_libs_sparkpost';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class SparkpostResult {
  /// Creates a result.
  const SparkpostResult({
    this.transmissionId,
    this.totalAcceptedRecipients,
    this.totalRejectedRecipients,
    this.templateId,
    this.subaccountId,
    this.region,
    this.sandboxFrom,
    this.requestId,
    this.statusCode,
  });

  /// `transmissionId` returned by transmissions endpoint.
  final String? transmissionId;

  /// Acceptance count.
  final int? totalAcceptedRecipients;

  /// Pre-send rejection count (suppression list, bounce list, etc.).
  /// Distinct from delivery failure — surfaces silent drops.
  final int? totalRejectedRecipients;

  /// Stored template id used.
  final String? templateId;

  /// Subaccount id (multi-tenant SparkPost deployments bill per
  /// subaccount).
  final int? subaccountId;

  /// `us` / `eu` — SparkPost vs SparkPost EU.
  final String? region;

  /// Whether `sparkpostbox.com` sandbox domain was used (free,
  /// limited, no production sending).
  final bool? sandboxFrom;

  /// `X-SparkPost-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class SparkpostCallResult<T> {
  /// Creates a call result.
  const SparkpostCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final SparkpostResult? result;
}

/// Wraps a SparkPost API call in a CLIENT span. [operation] is one of
/// `transmissions.send`, `transmissions.get`, `transmissions.list`,
/// `templates.create`, `templates.preview`, `templates.update`,
/// `recipient_lists.create`, `recipient_lists.list`,
/// `suppression_list.upsert`, `suppression_list.search`,
/// `subaccounts.list`, `subaccounts.create`, `webhooks.create`,
/// `events.message`, `metrics.deliverability`, `inbound_domains.list`.
Future<T> tracedSparkpost<T>({
  required String operation,
  required Future<SparkpostCallResult<T>> Function() invoke,
  String? region,
}) async {
  if (sparkpostInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'sparkpost',
    'rpc.method': operation,
    'sparkpost.operation': operation,
  };
  if (region != null) m['sparkpost.region'] = region;

  final span = _tracer().startSpan(
    'sparkpost $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transmissionId != null) {
        extras.add(OTelAPI.attributeString(
          'sparkpost.transmission.id',
          r.result!.transmissionId!,
        ));
      }
      if (r.result!.totalAcceptedRecipients != null) {
        extras.add(OTelAPI.attributeInt(
          'sparkpost.accepted',
          r.result!.totalAcceptedRecipients!,
        ));
      }
      if (r.result!.totalRejectedRecipients != null) {
        extras.add(OTelAPI.attributeInt(
          'sparkpost.rejected',
          r.result!.totalRejectedRecipients!,
        ));
      }
      if (r.result!.templateId != null) {
        extras.add(OTelAPI.attributeString(
          'sparkpost.template.id',
          r.result!.templateId!,
        ));
      }
      if (r.result!.subaccountId != null) {
        extras.add(OTelAPI.attributeInt(
          'sparkpost.subaccount.id',
          r.result!.subaccountId!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTelAPI.attributeString(
          'sparkpost.region',
          r.result!.region!,
        ));
      }
      if (r.result!.sandboxFrom != null) {
        extras.add(OTelAPI.attributeBool(
          'sparkpost.sandbox_from',
          r.result!.sandboxFrom!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'sparkpost.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'SparkPost HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
