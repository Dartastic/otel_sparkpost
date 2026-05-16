// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_sparkpost/otel_sparkpost.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_sparkpost-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('transmissions.send records accepted/rejected + subaccount', () async {
    await tracedSparkpost<String>(
      operation: 'transmissions.send',
      region: 'eu',
      invoke: () async => const SparkpostCallResult(
        value: 'ok',
        result: SparkpostResult(
          transmissionId: 't-1',
          totalAcceptedRecipients: 95,
          totalRejectedRecipients: 5,
          templateId: 'welcome',
          subaccountId: 42,
          region: 'eu',
          sandboxFrom: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('sparkpost transmissions.send')!);
    expect(a['sparkpost.region'], 'eu');
    expect(a['sparkpost.accepted'], 95);
    expect(a['sparkpost.rejected'], 5);
    expect(a['sparkpost.subaccount.id'], 42);
    expect(a['sparkpost.template.id'], 'welcome');
  });

  test('suppression skips spans', () async {
    await runWithoutSparkpostInstrumentationAsync(() async {
      await tracedSparkpost<String>(
        operation: 'metrics.deliverability',
        invoke: () async => const SparkpostCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('sparkpost '), isEmpty);
  });
}
