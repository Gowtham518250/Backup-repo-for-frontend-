// =============================================================================
// payment_announcement_service.dart  —  V8 HUMAN-LIKE VOICE SYSTEM
// Thin orchestrator. Wires LanguageEngine + Humanizer + IntelligenceEngine
// + VoiceEngine + QueueManager. All heavy logic lives in those modules.
//
// PUBLIC API (unchanged from V7 — drop-in replacement)
// ─────────────────────────────────────────────────────
//  init()
//  announceReceipt(amount, payerName?, method?, language, mode, isPartial?, ...)
//  announceFailure(language)
//  speakSimple(message, language)
//  queryDailyTotal(language)       ← NEW (INTEL-3)
//  testAnnouncement(language)
//  updateConfig(AnnouncementConfig)
//  updateVoiceSelection(name, locale)
//  stop()
//  todaySnapshot()                 ← NEW (INTEL-1)
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import 'language_engine.dart';
import 'humanizer.dart';
import 'intelligence_engine.dart';
import 'voice_engine.dart';
import 'queue_manager.dart';

export 'language_engine.dart'    show VoiceStyle, AnnouncementMode, AnnouncementPriority, PaymentMethod;
export 'intelligence_engine.dart' show TxRecord, AnomalyEvent, AnomalyType;

final _log = Logger(
  printer: PrettyPrinter(methodCount: 1, lineLength: 80, colors: kDebugMode),
  level: kDebugMode ? Level.debug : Level.warning,
);

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

class AnnouncementConfig {
  final double       volume;
  final double       speechRate;
  final bool         repeatOnPartial;
  final int          repeatCount;
  final Duration     repeatDelay;
  final VoiceStyle   defaultStyle;
  final String?      successAudio;
  final String?      warningAudio;
  final String?      criticalAudio;
  final bool         useStitchedVoice;
  final double       budgetDeviceTimeoutMultiplier;
  final bool         showPaise;
  final bool         isNoisyEnvironment;

  const AnnouncementConfig({
    this.volume                        = 1.0,
    this.speechRate                    = 0.55,
    this.repeatOnPartial               = true,
    this.repeatCount                   = 2,
    this.repeatDelay                   = const Duration(milliseconds: 900),
    this.defaultStyle                  = VoiceStyle.formal,
    this.successAudio,
    this.warningAudio,
    this.criticalAudio,
    this.useStitchedVoice              = false,
    this.budgetDeviceTimeoutMultiplier = 1.3,
    this.showPaise                     = false,
    this.isNoisyEnvironment            = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PaymentAnnouncementService
// ─────────────────────────────────────────────────────────────────────────────

class PaymentAnnouncementService {
  static final PaymentAnnouncementService _i =
      PaymentAnnouncementService._internal();
  factory PaymentAnnouncementService() => _i;
  PaymentAnnouncementService._internal();

  final _lang    = LanguageEngine();
  final _human   = Humanizer();
  final _intel   = IntelligenceEngine();
  final _voice   = VoiceEngine();
  final _queue   = QueueManager();

  AnnouncementConfig _config = const AnnouncementConfig();

  final List<(double, String?)> _burstAmounts = [];
  Timer?    _burstTimer;
  DateTime? _lastSpeakTime;
  double?   _lastAmount;
  bool?     _lastIsPartial;
  String?   _lastSpokenEvent;

  static const _minSpeakInterval = Duration(seconds: 3);
  static const _burstWindow      = Duration(milliseconds: 1500);

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> init({AnnouncementConfig? config}) async {
    await _loadConfig();
    if (config != null) _config = config;

    _intel.isNoisyEnvironment = _config.isNoisyEnvironment;

    _voice.onSpeakComplete = () {};
    _voice.onSpeakError    = () {};

    final prefs = await SharedPreferences.getInstance();
    await _voice.init(
      volume:            _config.volume,
      speechRate:        _config.speechRate,
      savedVoiceName:    prefs.getString('selected_tts_voice'),
      savedVoiceLocale:  prefs.getString('selected_tts_locale'),
      useStitchedVoice:  _config.useStitchedVoice,
    );
  }

  // ── Config ────────────────────────────────────────────────────────────────

  Future<void> _loadConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      _config = AnnouncementConfig(
        volume:                          p.getDouble('pds_volume')          ?? 1.0,
        speechRate:                      p.getDouble('pds_speech_rate')     ?? 0.55,
        repeatOnPartial:                 p.getBool('pds_repeat_partial')    ?? true,
        repeatCount:                     p.getInt('pds_repeat_count')       ?? 2,
        defaultStyle:                    VoiceStyle.values[
                                           p.getInt('pds_voice_style')      ?? 0],
        successAudio:                    p.getString('pds_success_audio'),
        warningAudio:                    p.getString('pds_warning_audio'),
        criticalAudio:                   p.getString('pds_critical_audio'),
        useStitchedVoice:                p.getBool('pds_use_stitched')      ?? false,
        budgetDeviceTimeoutMultiplier:   p.getDouble('pds_timeout_mult')    ?? 1.3,
        showPaise:                       p.getBool('pds_show_paise')        ?? false,
        isNoisyEnvironment:              p.getBool('pds_noisy_env')         ?? false,
      );
    } catch (e, st) {
      _log.e('_loadConfig failed', error: e, stackTrace: st);
    }
  }

  Future<void> updateConfig(AnnouncementConfig cfg) async {
    _config = cfg;
    _intel.isNoisyEnvironment = cfg.isNoisyEnvironment;
    await _voice.setVolume(cfg.volume);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('pds_volume',          cfg.volume);
      await p.setDouble('pds_speech_rate',     cfg.speechRate);
      await p.setBool('pds_repeat_partial',    cfg.repeatOnPartial);
      await p.setInt('pds_repeat_count',       cfg.repeatCount);
      await p.setInt('pds_voice_style',        cfg.defaultStyle.index);
      await p.setString('pds_success_audio',   cfg.successAudio  ?? '');
      await p.setString('pds_warning_audio',   cfg.warningAudio  ?? '');
      await p.setString('pds_critical_audio',  cfg.criticalAudio ?? '');
      await p.setBool('pds_use_stitched',      cfg.useStitchedVoice);
      await p.setDouble('pds_timeout_mult',    cfg.budgetDeviceTimeoutMultiplier);
      await p.setBool('pds_show_paise',        cfg.showPaise);
      await p.setBool('pds_noisy_env',         cfg.isNoisyEnvironment);
    } catch (e, st) {
      _log.e('updateConfig persist failed', error: e, stackTrace: st);
    }
  }

  Future<void> updateVoiceSelection(String name, String locale) async {
    await _voice.updateVoice(name, locale);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('selected_tts_voice',  name);
      await p.setString('selected_tts_locale', locale);
    } catch (e, st) {
      _log.e('updateVoiceSelection persist failed', error: e, stackTrace: st);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void announceReceipt({
    required double            amount,
    String?                    payerName,
    PaymentMethod?             method,
    required String            language,
    required AnnouncementMode  mode,
    bool                       isPartial  = false,
    double                     remaining  = 0.0,
    AnnouncementPriority       priority   = AnnouncementPriority.normal,
    VoiceStyle?                style,
  }) {
    if (mode == AnnouncementMode.silent) return;
    var effectiveStyle = style ?? _config.defaultStyle;
    // Auto-escalate to fastShop if shopkeeper is in rush (sentiment-aware tone)
    effectiveStyle = _intel.getAdaptiveStyle(effectiveStyle);

    if (!isPartial) {
      final tx = TxRecord(
        amount:   amount,
        payerName: payerName,
        method:   method ?? PaymentMethod.unknown,
        time:     DateTime.now(),
      );
      final anomaly = _intel.recordTransaction(tx);
      if (anomaly != null) _handleAnomaly(anomaly, language, effectiveStyle);
    }

    if (!isPartial && mode == AnnouncementMode.shopkeeper) {
      _burstAmounts.add((amount, payerName));
      _burstTimer?.cancel();
      _burstTimer = Timer(_burstWindow, () {
        if (_burstAmounts.length > 1) {
          final total = _burstAmounts.fold(0.0, (v, e) => v + e.$1);
          final items = List<(double, String?)>.from(_burstAmounts);
          _burstAmounts.clear();
          _enqueueBurst(items, total, language, effectiveStyle);
        } else if (_burstAmounts.isNotEmpty) {
          final item = _burstAmounts.removeAt(0);
          _enqueueSingle(
            item.$1, item.$2, method, language, mode,
            false, 0.0, priority, effectiveStyle,
          );
        }
      });
      return;
    }

    _enqueueSingle(amount, payerName, method, language, mode,
        isPartial, remaining, priority, effectiveStyle);
  }

  void announceFailure({required String language, VoiceStyle? style}) {
    final lang = _lang.resolve(language);
    final raw  = lang.failure;

    final result = _human.process(
      rawText:    raw,
      style:      style ?? VoiceStyle.alert,
      langKey:    lang.langKey,
      isCritical: true,
    );

    _enqueueItem(
      priority:   AnnouncementPriority.critical,
      ttsText:    result.text,
      audioPath:  _config.criticalAudio,
      result:     result,
      locale:     lang.locale,
    );
  }

  void speakSimple(String message, String language) {
    if (_config.volume <= 0) return;
    final lang = _lang.resolve(language);
    final timeout = _voice.calculateTimeout(message, _config.budgetDeviceTimeoutMultiplier);
    _queue.enqueue(QueueItem(
      priority:   AnnouncementPriority.low,
      ttsText:    message,
      timeoutSec: timeout,
      task: () => _voice.speakRaw(message, lang.locale),
    ));
  }

  void queryDailyTotal(String language) {
    final phrase  = _intel.queryDailyTotal(language);
    final lang    = _lang.resolve(language);
    // Use friendly style, but adapt to rush mode if active
    final style = _intel.getAdaptiveStyle(VoiceStyle.friendly);
    final result  = _human.process(
      rawText: phrase,
      style:   style,
      langKey: lang.langKey,
    );
    _enqueueItem(
      priority:  AnnouncementPriority.normal,
      ttsText:   result.text,
      audioPath: null,
      result:    result,
      locale:    lang.locale,
    );
  }

  void testAnnouncement(String language, {VoiceStyle style = VoiceStyle.formal}) {
    final lang = _lang.resolve(language);
    final items = [
      lang.test('100'),
      lang.partial('50', '50', style),
      lang.failure,
    ];
    final audios = [
      _config.successAudio,
      _config.warningAudio,
      _config.criticalAudio,
    ];
    final isPartials   = [false, true, false];
    final isCriticals  = [false, false, true];

    final queueItems = List.generate(items.length, (i) {
      final result = _human.process(
        rawText:    items[i],
        style:      style,
        langKey:    lang.langKey,
        isPartial:  isPartials[i],
        isCritical: isCriticals[i],
      );
      final timeout = _voice.calculateTimeout(result.text, _config.budgetDeviceTimeoutMultiplier);
      return QueueItem(
        priority:   AnnouncementPriority.low,
        ttsText:    result.text,
        timeoutSec: timeout,
        task: () async {
          await _voice.playAnnouncement(
            audioPath: audios[i],
            result:    result,
            locale:    lang.locale,
          );
          if (i < items.length - 1) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        },
      );
    });

    _queue.enqueueAll(queueItems);
  }

  Map<String, dynamic> todaySnapshot() => _intel.todaySnapshot();

  Future<void> stop() async {
    _burstTimer?.cancel();
    _queue.clear();
    _human.resetRepetitionState();
    await _voice.stop();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _enqueueSingle(
    double amount, String? payerName, PaymentMethod? method,
    String language, AnnouncementMode mode,
    bool isPartial, double remaining,
    AnnouncementPriority priority, VoiceStyle style,
  ) {
    final now       = DateTime.now();
    
    // ── VOICE DEDUP CACHE: Avoid repeating same announcement within 3 seconds (Fix 8) ──
    final String eventKey = '${amount.toStringAsFixed(2)}_${payerName ?? "anon"}_${isPartial ? 'P' : 'F'}';
    if (_lastSpokenEvent == eventKey && 
        _lastSpeakTime != null && 
        now.difference(_lastSpeakTime!) < const Duration(seconds: 3)) {
      print('🔊 Voice Dedup: skipping repeated announcement for $eventKey');
      return;
    }

    _lastSpeakTime   = now;
    _lastSpokenEvent = eventKey;
    _lastAmount      = amount;
    _lastIsPartial   = isPartial;

    final lang   = _lang.resolve(language);
    final fmtAmt = _fmt(amount);
    final fmtRem = _fmt(remaining);

    final raw = isPartial
        ? lang.partial(fmtAmt, fmtRem, style)
        : (payerName != null)
            ? lang.withSender(payerName, fmtAmt, style)
            : (method != null && method != PaymentMethod.unknown)
                ? lang.withMethod(fmtAmt, method, style)
                : lang.success(fmtAmt, style);

    final result = _human.process(
      rawText:    raw,
      style:      style,
      langKey:    lang.langKey,
      isPartial:  isPartial,
      amount:     amount,
    );

    final adjustedResult = _config.isNoisyEnvironment
        ? HumanizerResult(
            text:   result.text,
            chunks: result.chunks,
            pitch:  result.pitch,
            rate:   _intel.noiseAdjustedRate(result.rate),
          )
        : result;

    _enqueueItem(
      priority:   isPartial ? AnnouncementPriority.critical : priority,
      ttsText:    adjustedResult.text,
      audioPath:  isPartial ? _config.warningAudio : _config.successAudio,
      result:     adjustedResult,
      locale:     lang.locale,
      onComplete: isPartial && _config.repeatOnPartial
          ? () => _scheduleRepeat(adjustedResult, lang.locale)
          : null,
    );
  }

  void _enqueueBurst(
    List<(double, String?)> items, double total,
    String language, VoiceStyle style,
  ) {
    final lang = _lang.resolve(language);

    final smart = _intel.smartBurstSummary(
      count:    items.length,
      total:    total,
      language: language,
    );

    final raw = smart ?? (() {
      if (items.any((i) => i.$2 != null)) {
        final named = items.take(2).map((i) {
          final a = _fmt(i.$1);
          return i.$2 != null ? '${i.$2} $a' : a;
        }).join(', ');
        final more = items.length > 2
            ? ' ${_lang.andMore(language, items.length - 2)}'
            : '';
        return '$named$more ${_lang.receivedWord(language)}';
      }
      return lang.burst(items.length, _fmt(total), style);
    })();

    final result = _human.process(
      rawText: raw,
      style:   style,
      langKey: lang.langKey,
    );

    _enqueueItem(
      priority:  AnnouncementPriority.high,
      ttsText:   result.text,
      audioPath: _config.successAudio,
      result:    result,
      locale:    lang.locale,
    );
  }

  void _handleAnomaly(AnomalyEvent anomaly, String language, VoiceStyle style) {
    if (anomaly.type == AnomalyType.firstOfDay) return;

    final lang = _lang.resolve(language);

    final raw = switch (anomaly.type) {
      AnomalyType.largeTx       => lang.anomalyAlert(_fmt(anomaly.tx.amount)),
      AnomalyType.rapidRepeat   => _rapidRepeatWarning(lang.langKey, _fmt(anomaly.tx.amount)),
      AnomalyType.quietPeriodBroken => lang.success(_fmt(anomaly.tx.amount), VoiceStyle.friendly),
      _                         => lang.success(_fmt(anomaly.tx.amount), style),
    };

    final result = _human.process(
      rawText:    raw,
      style:      VoiceStyle.alert,
      langKey:    lang.langKey,
      isCritical: anomaly.type == AnomalyType.largeTx,
    );

    _enqueueItem(
      priority:  AnnouncementPriority.critical,
      ttsText:   result.text,
      audioPath: anomaly.type == AnomalyType.largeTx
          ? _config.criticalAudio
          : _config.warningAudio,
      result:    result,
      locale:    lang.locale,
    );
  }

  String _rapidRepeatWarning(String langKey, String amt) {
    switch (langKey) {
      case 'hi': return '$amt बार-बार आ रहा है, जांचें';
      case 'ta': return '$amt மீண்டும் மீண்டும் வருகிறது, சரிபாருங்க';
      case 'te': return '$amt మళ్ళీ మళ్ళీ వస్తుంది, చెక్ చేయండి';
      default:   return '$amt repeated — please verify';
    }
  }

  void _scheduleRepeat(HumanizerResult result, String locale) {
    Timer(_config.repeatDelay, () {
      for (int i = 1; i < _config.repeatCount; i++) {
        _queue.enqueue(QueueItem(
          priority:   AnnouncementPriority.high,
          ttsText:    result.text,
          timeoutSec: _voice.calculateTimeout(result.text, _config.budgetDeviceTimeoutMultiplier),
          task: () => _voice.playAnnouncement(
            audioPath: _config.warningAudio,
            result:    result,
            locale:    locale,
          ),
        ));
      }
    });
  }

  void _enqueueItem({
    required AnnouncementPriority priority,
    required String               ttsText,
    required String?              audioPath,
    required HumanizerResult      result,
    required String               locale,
    VoidCallback?                 onComplete,
  }) {
    final timeout = _voice.calculateTimeout(ttsText, _config.budgetDeviceTimeoutMultiplier);
    _queue.enqueue(QueueItem(
      priority:   priority,
      ttsText:    ttsText,
      timeoutSec: timeout,
      task: () async {
        await _voice.playAnnouncement(
          audioPath: audioPath,
          result:    result,
          locale:    locale,
        );
        onComplete?.call();
      },
    ));
  }

  String _fmt(double amount) {
    if (_config.showPaise && amount != amount.floorToDouble()) {
      final p = ((amount - amount.floor()) * 100).round();
      return '${amount.floor()}.${p.toString().padLeft(2, '0')}';
    }
    return amount.toInt().toString();
  }

  // ── SENTIMENT-AWARE TONE API ───────────────────────────────────────────────
  
  /// Check if shopkeeper is in rush mode (rapid transaction rate).
  /// Returns true when 2+ transactions detected within 10 seconds.
  /// Auto-resets after 20 seconds of inactivity.
  /// 
  /// Usage:
  /// ```dart
  /// if (service.isRushMode) {
  ///   // Show UI indicator: "🏃 RUSH MODE ACTIVE"
  ///   // Announcements auto-switch to fastShop style (shorter, faster)
  /// }
  /// ```
  bool get isRushMode => _intel.isRushMode;

  /// Get current effective voice style considering rush mode.
  /// Useful for UI to display what style is currently being used.
  VoiceStyle getEffectiveStyle(VoiceStyle baseStyle) =>
      _intel.getAdaptiveStyle(baseStyle);
}
