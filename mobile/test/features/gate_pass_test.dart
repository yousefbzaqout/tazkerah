import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/constants/app_constants.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/utils/clock.dart';
import 'package:tazkerah/features/tickets/domain/gate_pass.dart';
import 'package:tazkerah/features/tickets/domain/gate_pass_repository.dart';
import 'package:tazkerah/features/tickets/domain/gate_pass_state.dart';
import 'package:tazkerah/features/tickets/domain/screen_capture_detector.dart';
import 'package:tazkerah/features/tickets/presentation/controllers/gate_pass_controller.dart';
import 'package:tazkerah/features/tickets/presentation/gate_pass_screen.dart';
import 'package:tazkerah/features/tickets/presentation/widgets/clock_skew_fallback.dart';
import 'package:tazkerah/features/tickets/presentation/widgets/pass_intercept_banner.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_screen_brightness_controller.dart';

/// A [GatePassRepository] a test can steer.
class FakeGatePassRepository implements GatePassRepository {
  FakeGatePassRepository({this.pass, this.fetchFailure, this.issueFailure});

  GatePass? pass;
  Failure? fetchFailure;
  Failure? issueFailure;

  /// How long each issued code lasts.
  Duration codeLifetime = AppConstants.qrRotationInterval;

  int issued = 0;
  int manualIssued = 0;
  int resyncCalls = 0;
  final List<String> captureReports = [];

  Failure? manualFailure;
  Failure? timeFailure;

  /// What a re-sync learns. Null means "agree with the device".
  DateTime? serverTime;

  @override
  Future<GatePass> fetchPass(String ticketId) async {
    final failure = fetchFailure;
    if (failure != null) throw failure;
    return pass ?? testPass(id: ticketId);
  }

  @override
  Future<PresentationCode> issueCode(String ticketId) async {
    final failure = issueFailure;
    if (failure != null) throw failure;

    issued++;
    final now = DateTime.now().toUtc();
    return PresentationCode(
      payload: 'PAYLOAD-$issued',
      issuedAt: now,
      expiresAt: now.add(codeLifetime),
      displayHash: 'HASH-$issued',
    );
  }

  @override
  Future<void> reportCapture(String ticketId) async {
    captureReports.add(ticketId);
  }

  @override
  Future<ManualEntryCode> issueManualCode(String ticketId) async {
    final failure = manualFailure;
    if (failure != null) throw failure;
    manualIssued++;
    return ManualEntryCode(
      digits: '48291703',
      displayHash: '9F84-E210',
      issuedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<DateTime> fetchServerTime() async {
    final failure = timeFailure;
    if (failure != null) throw failure;
    resyncCalls++;
    // Returns the time the test asked for, so a re-sync can be made to leave
    // the clock still skewed.
    return serverTime ?? DateTime.now().toUtc();
  }
}

/// A detector a test can fire by hand.
class FakeCaptureDetector implements ScreenCaptureDetector {
  final _controller = StreamController<ScreenCaptureEvent>.broadcast();
  bool started = false;
  bool stopped = false;

  @override
  Stream<ScreenCaptureEvent> get events => _controller.stream;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;

  void fire() => _controller.add(
    ScreenCaptureEvent(at: DateTime.now(), kind: CaptureKind.screenshot),
  );

  void dispose() => _controller.close();
}

GatePass testPass({
  String id = 'tkt_1',
  GatePassStatus status = GatePassStatus.active,
  Duration? rotationInterval,
}) {
  return GatePass(
    id: id,
    reference: 'FR-021',
    eventTitle: 'Soundstorm 2025: Big Beast',
    venueName: 'AlUla Starlight Pavilion',
    zoneLabel: 'ZONE 1',
    seatLabel: 'VIP A-12',
    holderName: 'Tariq Al-Mansoor',
    entranceLabel: 'Gate 4',
    status: status,
    rotationInterval: rotationInterval ?? AppConstants.qrRotationInterval,
    deviceId: '#TZ-8841-A',
    isFastTrack: true,
  );
}

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

(ProviderContainer, FakeGatePassRepository, FakeCaptureDetector) build({
  FakeGatePassRepository? repository,
  AppClock? clock,
  FakeScreenBrightnessController? brightness,
}) {
  final repo = repository ?? FakeGatePassRepository();
  final detector = FakeCaptureDetector();
  addTearDown(detector.dispose);

  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      gatePassRepositoryProvider.overrideWithValue(repo),
      screenCaptureDetectorProvider.overrideWithValue(detector),
      screenBrightnessControllerProvider.overrideWithValue(
        brightness ?? FakeScreenBrightnessController(),
      ),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  // Disposing twice is a no-op in Riverpod, so tests that dispose early to
  // stop the rotation ticker still get a safety net here.
  addTearDown(container.dispose);
  return (container, repo, detector);
}

Widget wrap(ProviderContainer container, {Locale? locale}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GatePassScreen(ticketId: 'tkt_1'),
    ),
  );
}

/// Lets the controller's scheduled load run to completion.
///
/// Holds a subscription for the duration. The provider is `isAutoDispose`, so
/// a bare `read` is torn down the moment it returns — taking the scheduled
/// load with it — and the state would never leave `loading`. A live listener
/// is also what the real screen provides via `ref.watch`.
Future<void> settle(ProviderContainer c) async {
  final sub = c.listen(gatePassControllerProvider('tkt_1'), (_, _) {});
  addTearDown(sub.close);

  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
    if (read(c).status != GatePassViewStatus.loading) return;
  }
}

GatePassViewState read(ProviderContainer c) =>
    c.read(gatePassControllerProvider('tkt_1'));

GatePassController notifier(ProviderContainer c) =>
    c.read(gatePassControllerProvider('tkt_1').notifier);

void main() {
  group('Rotation policy', () {
    test('the app rotates on the interval the design specifies', () {
      // The design says "refreshes every 20s" and "STRICT 20s TOTP cycle".
      expect(AppConstants.qrRotationInterval, const Duration(seconds: 20));
    });

    test('the interval travels with the grant, not a constant', () async {
      final repo = FakeGatePassRepository(
        pass: testPass(rotationInterval: const Duration(seconds: 45)),
      );
      final (container, _, _) = build(repository: repo);
      await settle(container);

      // The screen must advertise what the server granted, so a backend change
      // needs no app release.
      expect(read(container).pass!.rotationInterval.inSeconds, 45);
    });
  });

  group('GatePassController', () {
    test('loads the pass and its first code', () async {
      final (container, repo, detector) = build();
      await settle(container);

      final state = read(container);
      expect(state.status, GatePassViewStatus.active);
      expect(state.code!.payload, 'PAYLOAD-1');
      expect(state.isPresentable, isTrue);
      expect(repo.issued, 1);
      expect(detector.started, isTrue, reason: 'watching for captures');
    });

    test('a consumed pass is never presentable', () async {
      final repo = FakeGatePassRepository(
        pass: testPass(status: GatePassStatus.consumed),
      );
      final (container, _, _) = build(repository: repo);
      await settle(container);

      final state = read(container);
      expect(state.status, GatePassViewStatus.unavailable);
      expect(state.code, isNull, reason: 'no code is issued at all');
      expect(repo.issued, 0);
    });

    test('a capture withholds the payload and reports it', () async {
      final (container, repo, detector) = build();
      await settle(container);
      expect(read(container).code, isNotNull);

      detector.fire();
      await Future<void>.delayed(Duration.zero);

      final state = read(container);
      expect(state.status, GatePassViewStatus.intercepted);
      // The payload is gone from state, not merely hidden behind a flag.
      expect(state.code, isNull);
      expect(state.isPresentable, isFalse);
      // The hash identifies the withheld rotation without reproducing it.
      expect(state.intercept!.withheldHash, 'HASH-1');
      expect(state.intercept!.reason, InterceptReason.screenCapture);

      await Future<void>.delayed(Duration.zero);
      expect(
        repo.captureReports,
        ['tkt_1'],
        reason: 'the issuer must invalidate the captured code',
      );
    });

    test('revealing after a capture issues a different code', () async {
      final (container, repo, detector) = build();
      await settle(container);
      final firstPayload = read(container).code!.payload;

      detector.fire();
      await Future<void>.delayed(Duration.zero);
      await notifier(container).revealFreshCode();

      final state = read(container);
      expect(state.status, GatePassViewStatus.active);
      expect(state.code!.payload, isNot(firstPayload));
      expect(repo.issued, 2);
    });

    test('revealing does nothing unless intercepted', () async {
      final (container, repo, _) = build();
      await settle(container);

      await notifier(container).revealFreshCode();
      expect(repo.issued, 1, reason: 'no extra code requested');
    });

    test('a failed code request leaves nothing presentable', () async {
      final repo = FakeGatePassRepository(issueFailure: const NetworkFailure());
      final (container, _, _) = build(repository: repo);
      await settle(container);

      final state = read(container);
      expect(state.status, GatePassViewStatus.error);
      expect(state.code, isNull);
    });

    test('an expired code reads as zero, never negative', () {
      final code = PresentationCode(
        payload: 'x',
        issuedAt: DateTime.utc(2020),
        expiresAt: DateTime.utc(2020, 1, 1, 0, 0, 20),
        displayHash: 'AAAA-BBBB',
      );

      expect(code.remaining(DateTime.utc(2026)), Duration.zero);
      expect(code.isExpired(DateTime.utc(2026)), isTrue);
      expect(code.progress(DateTime.utc(2026)), 1.0);
      expect(code.progress(DateTime.utc(2020)), 0.0);
    });
  });

  group('Clock skew', () {
    test('the threshold matches the design', () {
      // The design says "SKEW > 180s" and cites policy FR-003.
      expect(
        AppConstants.clockSkewSuppressionThreshold,
        const Duration(seconds: 180),
      );
    });

    test('excessive skew suppresses the QR and issues a fallback', () async {
      final clock = AppClock();
      // 246 seconds ahead, past the 180s threshold.
      clock.syncTo(DateTime.now().toUtc().add(const Duration(seconds: 246)));

      final repo = FakeGatePassRepository();
      final (container, _, _) = build(repository: repo, clock: clock);
      await settle(container);

      final state = read(container);
      expect(state.status, GatePassViewStatus.intercepted);
      expect(state.intercept!.reason, InterceptReason.clockDrift);
      // The code is never even requested: one that would be rejected at the
      // gate is worse than none.
      expect(repo.issued, 0, reason: 'no QR is requested at all');
      expect(state.code, isNull);
      expect(state.manualCode!.digits, '48291703');
      expect(repo.manualIssued, 1);
    });

    test('the fallback is not offered for a screenshot intercept', () async {
      final (container, repo, detector) = build();
      await settle(container);

      detector.fire();
      await Future<void>.delayed(Duration.zero);

      // A capture is recoverable by revealing a new code; handing out a gate
      // credential there would answer a solved problem.
      expect(read(container).manualCode, isNull);
      expect(repo.manualIssued, 0);
    });

    test('a successful re-sync restores the rotating code', () async {
      final clock = AppClock();
      clock.syncTo(DateTime.now().toUtc().add(const Duration(seconds: 246)));

      final repo = FakeGatePassRepository();
      final (container, _, _) = build(repository: repo, clock: clock);
      await settle(container);
      expect(read(container).status, GatePassViewStatus.intercepted);

      // The server now agrees with the device.
      repo.serverTime = DateTime.now().toUtc();
      await notifier(container).attemptTimeResync();

      final state = read(container);
      expect(state.status, GatePassViewStatus.active);
      expect(state.code, isNotNull);
      expect(state.manualCode, isNull, reason: 'fallback is withdrawn');
      container.dispose();
    });

    test('a re-sync that does not fix the drift keeps the fallback', () async {
      final clock = AppClock();
      clock.syncTo(DateTime.now().toUtc().add(const Duration(seconds: 246)));

      final repo = FakeGatePassRepository();
      final (container, _, _) = build(repository: repo, clock: clock);
      await settle(container);

      // Still badly out.
      repo.serverTime = DateTime.now().toUtc().add(
        const Duration(seconds: 300),
      );
      await notifier(container).attemptTimeResync();

      final state = read(container);
      expect(state.status, GatePassViewStatus.intercepted);
      expect(state.code, isNull, reason: 'no code the gate would reject');
      expect(state.manualCode, isNotNull);
    });

    test('a failed re-sync leaves the fallback untouched', () async {
      final clock = AppClock();
      clock.syncTo(DateTime.now().toUtc().add(const Duration(seconds: 246)));

      final repo = FakeGatePassRepository();
      final (container, _, _) = build(repository: repo, clock: clock);
      await settle(container);
      final code = read(container).manualCode;

      repo.timeFailure = const NetworkFailure();
      await notifier(container).attemptTimeResync();

      expect(read(container).manualCode, same(code));
      expect(read(container).status, GatePassViewStatus.intercepted);
    });
  });

  group('GatePassScreen', () {
    testWidgets('renders the active pass with its QR and countdown', (
      tester,
    ) async {
      useTallViewport(tester);
      final (container, _, _) = build();

      await tester.pumpWidget(wrap(container));
      await tester.pump();
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('ACTIVE GATE PASS'), findsOneWidget);
      expect(find.text('FR-021 · TOTP'), findsOneWidget);
      expect(find.text('VIP A-12'), findsOneWidget);
      expect(find.text('Code refreshes every 20s'), findsOneWidget);
      expect(find.text('Tariq Al-Mansoor'), findsOneWidget);
      expect(find.text('Gate 4 · FastTrack'), findsOneWidget);
      expect(find.text('Online Validated'), findsOneWidget);

      // Dispose so the rotation ticker is cancelled: a live pass keeps
      // redrawing its countdown, and the binding fails a test that leaves a
      // periodic timer pending. The container outlives the widget tree, so
      // unmounting alone is not enough.
      container.dispose();
      await tester.pump();
    });

    testWidgets('a capture replaces the QR with the redacted placeholder', (
      tester,
    ) async {
      useTallViewport(tester);
      final (container, _, detector) = build();

      await tester.pumpWidget(wrap(container));
      await tester.pump();
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);

      detector.fire();
      await tester.pump();
      await tester.pump();

      // The code is gone from the tree entirely.
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(PassInterceptBanner), findsOneWidget);
      expect(find.text('SECURITY INTERCEPT'), findsOneWidget);
      expect(find.text('PAYLOAD REDACTED'), findsOneWidget);
      expect(find.text('NEW TOKEN READY'), findsOneWidget);
      expect(find.text('Reveal fresh dynamic QR'), findsOneWidget);
    });

    testWidgets('renders the clock skew fallback frame', (tester) async {
      useTallViewport(tester);
      final clock = AppClock();
      clock.syncTo(DateTime.now().toUtc().add(const Duration(seconds: 246)));
      final (container, _, _) = build(clock: clock);

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      expect(find.byType(ClockSkewFallback), findsOneWidget);
      expect(find.text('SKEW > 180s'), findsOneWidget);
      expect(find.text('DEVICE TIME OUT OF SYNC'), findsOneWidget);
      expect(find.text('QR DISPLAY SUPPRESSED (FR-021)'), findsOneWidget);
      expect(find.text('MANUAL ENTRY FALLBACK CODE'), findsOneWidget);
      expect(find.text('4 8 2 9 1 7 0 3'), findsOneWidget);
      expect(find.text('Attempt Time Re-sync (NTP)'), findsOneWidget);
      // The QR must be entirely absent, not merely hidden.
      expect(find.byType(QrImageView), findsNothing);

      container.dispose();
      await tester.pump();
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      useTallViewport(tester);
      final (container, _, _) = build();

      await tester.pumpWidget(wrap(container, locale: const Locale('ar')));
      await tester.pump();
      await tester.pump();

      expect(find.text('تصريح دخول فعّال'), findsOneWidget);
      expect(find.text('حامل التذكرة'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('حامل التذكرة'))),
        TextDirection.rtl,
      );

      container.dispose();
      await tester.pump();
    });
  });

  group('Screen brightness', () {
    test('raises the screen once a code is on display', () async {
      final brightness = FakeScreenBrightnessController();
      final (container, _, _) = build(brightness: brightness);
      await settle(container);

      expect(read(container).status, GatePassViewStatus.active);
      expect(brightness.calls, ['boost']);
    });

    test('does not raise the screen when the pass cannot be presented', () async {
      final repo = FakeGatePassRepository(
        pass: testPass(status: GatePassStatus.consumed),
      );
      final brightness = FakeScreenBrightnessController();
      final (container, _, _) = build(repository: repo, brightness: brightness);
      await settle(container);

      // Nothing scannable is on screen, so there is nothing to light up.
      expect(read(container).status, GatePassViewStatus.unavailable);
      expect(brightness.calls, isEmpty);
    });

    test('does not raise the screen for an error frame', () async {
      final repo = FakeGatePassRepository(
        issueFailure: const NetworkFailure(),
      );
      final brightness = FakeScreenBrightnessController();
      final (container, _, _) = build(repository: repo, brightness: brightness);
      await settle(container);

      expect(read(container).status, GatePassViewStatus.error);
      expect(brightness.calls, isEmpty);
    });

    test('dims again when a capture withholds the code', () async {
      final brightness = FakeScreenBrightnessController();
      final (container, _, detector) = build(brightness: brightness);
      await settle(container);
      expect(brightness.isBoosted, isTrue);

      detector.fire();
      await Future<void>.delayed(Duration.zero);

      // Holding the screen bright over a redacted placeholder would also make
      // a recording still in progress easier to read.
      expect(read(container).status, GatePassViewStatus.intercepted);
      expect(brightness.calls, ['boost', 'restore']);
    });

    test('raises the screen again when a fresh code is revealed', () async {
      final brightness = FakeScreenBrightnessController();
      final (container, _, detector) = build(brightness: brightness);
      await settle(container);

      detector.fire();
      await Future<void>.delayed(Duration.zero);

      await notifier(container).revealFreshCode();

      expect(read(container).status, GatePassViewStatus.active);
      expect(brightness.calls, ['boost', 'restore', 'boost']);
    });

    test('hands the screen back when the pass is disposed', () async {
      final brightness = FakeScreenBrightnessController();
      final (container, _, _) = build(brightness: brightness);
      await settle(container);
      expect(brightness.isBoosted, isTrue);

      container.dispose();

      // A pass left bright after the user navigated away would drain a battery
      // they may still need to present a ticket later.
      expect(brightness.calls.last, 'restore');
    });
  });
}
