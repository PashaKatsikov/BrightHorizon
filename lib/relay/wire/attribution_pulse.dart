import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../config/relay_config.dart';
import 'veiled_strings.dart';

// ============================================================
// ATTRIBUTION PULSE — AppsFlyer install + deep-link collector
// ============================================================
// Collects three signals and folds them into the verdict body:
//   1. onInstallConversionData — install-attribution payload
//   2. onDeepLinking            — UDL / OneLink deep-link click
//   3. onAppOpenAttribution     — returning-user attribution
//
// The install callback is forwarded as AppsFlyer sent it, including an
// `af_status` of Organic. There is no follow-up GCD query: that second
// round trip (and the delay in front of it) held the first launch on
// the boot screen.
//
// [SHORT-CIRCUIT]  When no dev key is packed yet, the SDK never boots
// and the futures complete immediately with an empty map. This lets QA
// smoke-test the game path without a working attribution stack.
// ============================================================

class AttributionPulse {
  AttributionPulse();

  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _appOpenPayload;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _started = false;

  /// Boot the SDK and wire the three callbacks. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final String devKey = RelayConfig.attributionKey;
    if (devKey.isEmpty) {
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: RelayConfig.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) {
      final Map<String, dynamic> payload = _unpackMap(raw);
      _installPayload = payload;
      _resolveInstall(payload);
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _appOpenPayload = _unpackMap(raw);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkPayload = Map<String, dynamic>.from(click);
      }
      _resolveDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
    }
  }

  /// Waits (with a cap) for the install-conversion callback AND the
  /// deep-link callback. Used by the boot pipeline right before the
  /// verdict request goes out.
  Future<void> awaitSignals({int? installSeconds}) async {
    final int seconds = installSeconds ?? RelayConfig.firstInstallAwaitSeconds;
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(
        Duration(seconds: seconds),
        onTimeout: () => <String, dynamic>{},
      ),
      _deepLinkReady.future.timeout(
        Duration(seconds: RelayConfig.deepLinkAwaitSeconds),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> deviceId() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assemble the verdict request body. Every field from
  /// `onInstallConversionData` is forwarded VERBATIM — nothing renamed,
  /// nothing dropped — plus the seven device-side fields defined by the
  /// backend contract.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installPayload != null) body.addAll(_installPayload!);
    _deepLinkPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceId() ?? '';
    body['bundle_id'] = RelayConfig.applicationId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = RelayConfig.storeId;
    body[VeiledStrings.get('k_locale')] = locale;

    // Omitted (never "" / null) when FCM never initialised — the
    // backend contract treats absence as "no push capability".
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = RelayConfig.messagingProjectId;
    if (project.isNotEmpty) {
      body[VeiledStrings.get('k_fbp')] = project;
    }

    assert(() {
      // ignore: avoid_print
      print('[RELAY.PULSE] compose ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  void _resolveInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _resolveDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _unpackMap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner =
        raw[VeiledStrings.get('k_payload')] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
