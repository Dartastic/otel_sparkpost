// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_sparkpost_suppression.dart';

const _tracerName = 'dartastic_otel_libs_sparkpost';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class SparkpostResult {
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

class SparkpostCallResult<T> {
  const SparkpostCallResult({required this.value, this.result});
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
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transmissionId != null) {
        extras.add(OTel.attributeString(
          'sparkpost.transmission.id',
          r.result!.transmissionId!,
        ));
      }
      if (r.result!.totalAcceptedRecipients != null) {
        extras.add(OTel.attributeInt(
          'sparkpost.accepted',
          r.result!.totalAcceptedRecipients!,
        ));
      }
      if (r.result!.totalRejectedRecipients != null) {
        extras.add(OTel.attributeInt(
          'sparkpost.rejected',
          r.result!.totalRejectedRecipients!,
        ));
      }
      if (r.result!.templateId != null) {
        extras.add(OTel.attributeString(
          'sparkpost.template.id',
          r.result!.templateId!,
        ));
      }
      if (r.result!.subaccountId != null) {
        extras.add(OTel.attributeInt(
          'sparkpost.subaccount.id',
          r.result!.subaccountId!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTel.attributeString(
          'sparkpost.region',
          r.result!.region!,
        ));
      }
      if (r.result!.sandboxFrom != null) {
        extras.add(OTel.attributeBool(
          'sparkpost.sandbox_from',
          r.result!.sandboxFrom!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'sparkpost.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
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
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
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
