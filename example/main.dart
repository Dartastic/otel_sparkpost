// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_sparkpost/otel_sparkpost.dart';

/// Traces SparkPost calls with OpenTelemetry.
///
/// `otel_sparkpost` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each SparkPost call in
/// [tracedSparkpost]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'sparkpost-example');

  // Wraps a SparkPost API call in a CLIENT span.
  final sparkpostId = await tracedSparkpost<String>(
    operation: 'templates.create',
    region: 'us-east-1',
    invoke: () async {
      // Make the SparkPost call here, then report what it returned.
      const id = 'sparkpost_8f3a2c';
      return const SparkpostCallResult(
          value: id,
          result: SparkpostResult(
              transmissionId: 'transmission_8f3a2c',
              totalAcceptedRecipients: 1,
              totalRejectedRecipients: 1,
              templateId: 'template_8f3a2c',
              subaccountId: 3,
              region: 'us',
              sandboxFrom: true,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedSparkpost templates.create returned $sparkpostId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSparkpostInstrumentationAsync.
  await runWithoutSparkpostInstrumentationAsync(
    () => tracedSparkpost<String>(
      operation: 'templates.create',
      region: 'us-east-1',
      invoke: () async {
        const id = 'sparkpost_8f3a2c';
        return const SparkpostCallResult(
            value: id,
            result: SparkpostResult(
                transmissionId: 'transmission_8f3a2c',
                totalAcceptedRecipients: 1,
                totalRejectedRecipients: 1,
                templateId: 'template_8f3a2c',
                subaccountId: 3,
                region: 'us',
                sandboxFrom: true,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
