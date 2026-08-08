import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/errors/error_message_resolver.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart';

import '../../support/localized_widget_test_harness.dart';

/// `REFACTOR_ROADMAP.md` Phase 21: this resolver is the single place every
/// write action's `catch` block should go through instead of a hand-picked
/// generic `*_failed` string — verifies it actually distinguishes real
/// connectivity failures, server rejections, and truly-unknown errors
/// rather than blaming "check your connection" for everything, which was
/// the original bug report. Uses the real `assets/lang/ar.json` strings
/// (via [pumpLocalized]), not `.tr()`'s silent raw-key fallback — see
/// `CLAUDE.md`'s localization section for why that distinction matters.
class _MessageProbe extends StatelessWidget {
  const _MessageProbe(this.error, {required this.fallback});

  final Object error;
  final String fallback;

  @override
  Widget build(final BuildContext context) =>
      Text(resolveWriteErrorMessage(error, fallback: fallback));
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  testWidgets('a NetworkException resolves to the real no-internet string',
      (final tester) async {
    await pumpLocalized(
      tester,
      _MessageProbe(NetworkException(), fallback: 'unused'),
    );
    expect(
      find.text('لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة.'),
      findsOneWidget,
    );
  });

  testWidgets('a TimeoutException resolves to the real timeout string',
      (final tester) async {
    await pumpLocalized(
      tester,
      _MessageProbe(TimeoutException(), fallback: 'unused'),
    );
    expect(
      find.text('انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.'),
      findsOneWidget,
    );
  });

  testWidgets('a ConflictException resolves to the real conflict string',
      (final tester) async {
    await pumpLocalized(
      tester,
      _MessageProbe(ConflictException(), fallback: 'unused'),
    );
    expect(find.text('خطأ تعارض. البيانات موجودة بالفعل.'), findsOneWidget);
  });

  testWidgets('a ValidationException resolves to the real validation string',
      (final tester) async {
    await pumpLocalized(
      tester,
      _MessageProbe(ValidationException(), fallback: 'unused'),
    );
    expect(
      find.text('خطأ في التحقق. يرجى التحقق من المدخلات.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a plain/unrecognized error falls back to the action-specific message '
    'instead of a generic connectivity claim',
    (final tester) async {
      await pumpLocalized(
        tester,
        _MessageProbe(
          Exception('some totally unrelated failure'),
          fallback: 'تعذّر حذف السجل — حاول مرة أخرى',
        ),
      );
      expect(find.text('تعذّر حذف السجل — حاول مرة أخرى'), findsOneWidget);
    },
  );

  testWidgets(
    'a raw SocketException that bypassed ErrorHandler falls back rather '
    'than being reclassified here — proves the connectivity classification '
    'lives in ErrorHandler.handleException, not duplicated in this '
    'resolver, which only understands AppException subtypes',
    (final tester) async {
      await pumpLocalized(
        tester,
        const _MessageProbe(
          SocketException('Failed host lookup'),
          fallback: 'fallback text',
        ),
      );
      expect(find.text('fallback text'), findsOneWidget);
    },
  );
}
