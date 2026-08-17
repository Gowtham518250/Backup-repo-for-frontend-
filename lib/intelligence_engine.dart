// =============================================================================
// intelligence_engine.dart — V9 RETAIL INTELLIGENCE
// Existing analytics/anomaly/voice behavior + deterministic fraud-risk scoring.
// =============================================================================

import 'language_engine.dart';

class TxRecord {
  final double amount;
  final String? payerName;
  final PaymentMethod method;
  final DateTime time;
  final bool isPartial;

  const TxRecord({
    required this.amount,
    this.payerName,
    required this.method,
    required this.time,
    this.isPartial = false,
  });
}

enum AnomalyType {
  largeTx,
  rapidRepeat,
  firstOfDay,
  quietPeriodBroken,
}

class AnomalyEvent {
  final AnomalyType type;
  final TxRecord tx;
  final String? detail;
  const AnomalyEvent({required this.type, required this.tx, this.detail});
}

/// Deterministic risk result. This is intentionally NOT an automatic fraud verdict.
/// It is a review signal for the owner/staff.
class FraudRiskAssessment {
  final int score; // 0-100
  final String level; // LOW, MEDIUM, HIGH
  final List<String> reasons;
  final Map<String, dynamic> signals;

  const FraudRiskAssessment({
    required this.score,
    required this.level,
    required this.reasons,
    required this.signals,
  });

  bool get requiresReview => level == 'HIGH';

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level,
        'requires_review': requiresReview,
        'reasons': reasons,
        'signals': signals,
      };
}

class DailyLedger {
  final DateTime date;
  double totalAmount = 0.0;
  int txCount = 0;
  final List<TxRecord> _records = [];
  final List<int> _hourBuckets = List.filled(24, 0);

  DailyLedger(this.date);

  void record(TxRecord tx) {
    totalAmount += tx.amount;
    txCount++;
    _records.add(tx);
    _hourBuckets[tx.time.hour]++;
  }

  int get peakHour {
    if (_hourBuckets.every((v) => v == 0)) return DateTime.now().hour;
    return _hourBuckets.indexOf(
      _hourBuckets.reduce((a, b) => a > b ? a : b),
    );
  }

  double get averageAmount => txCount == 0 ? 0.0 : totalAmount / txCount;

  List<double> lastAmounts(int n) =>
      _records.reversed.take(n).map((r) => r.amount).toList();

  List<TxRecord> recentRecords(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _records.where((r) => r.time.isAfter(cutoff)).toList();
  }

  DateTime? get lastTxTime =>
      _records.isEmpty ? null : _records.last.time;
}

class IntelligenceEngine {
  DailyLedger _ledger = DailyLedger(DateTime.now());

  double _largeTxMultiplier = 5.0;
  double _largeTxAbsolute = 5000;
  int _rapidRepeatWindow = 120;
  int _rapidRepeatMinCount = 5;

  bool isNoisyEnvironment = false;

  bool _isInRushMode = false;
  DateTime? _rushModeSetAt;
  final Duration _rushModeTimeout = const Duration(seconds: 20);
  final Duration _rushTapWindow = const Duration(seconds: 10);
  final int _rushTapThreshold = 2;

  AnomalyEvent? recordTransaction(TxRecord tx) {
    _rolloverIfNewDay();
    _updateRushMode();

    final isFirst = _ledger.txCount == 0;
    final previousLast = _ledger.lastTxTime;
    _ledger.record(tx);
    _detectRush(tx);

    if (isFirst) {
      return AnomalyEvent(type: AnomalyType.firstOfDay, tx: tx);
    }

    if (previousLast != null &&
        tx.time.difference(previousLast).inMinutes > 30) {
      return AnomalyEvent(
        type: AnomalyType.quietPeriodBroken,
        tx: tx,
        detail: '${tx.time.difference(previousLast).inMinutes} minutes gap',
      );
    }

    if (_isRapidRepeat(tx)) {
      return AnomalyEvent(type: AnomalyType.rapidRepeat, tx: tx);
    }

    if (_isLargeTx(tx)) {
      return AnomalyEvent(
        type: AnomalyType.largeTx,
        tx: tx,
        detail: 'avg ₹${_ledger.averageAmount.toStringAsFixed(0)}',
      );
    }

    return null;
  }

  bool _isLargeTx(TxRecord tx) {
    if (tx.amount >= _largeTxAbsolute) return true;
    final avg = _ledger.averageAmount;
    return avg > 0 && tx.amount >= avg * _largeTxMultiplier;
  }

  bool _isRapidRepeat(TxRecord tx) {
    final recent = _ledger.recentRecords(_rapidRepeatWindow);
    final sameAmt = recent.where((r) => r.amount == tx.amount).length;
    return sameAmt >= _rapidRepeatMinCount;
  }

  void _rolloverIfNewDay() {
    final today = DateTime.now();
    if (today.year != _ledger.date.year ||
        today.day != _ledger.date.day ||
        today.month != _ledger.date.month) {
      _ledger = DailyLedger(today);
    }
  }

  String queryDailyTotal(String language) {
    _rolloverIfNewDay();
    final lang = LanguageEngine().resolve(language);
    final total = _ledger.totalAmount.toInt().toString();
    return lang.dailySummary(total, _ledger.txCount);
  }

  String queryPeakHour() {
    final h = _ledger.peakHour;
    final amPm = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return 'Peak hour today: $hour $amPm';
  }

  double get adaptiveVolume => 1.0;

  double noiseAdjustedRate(double baseRate) =>
      isNoisyEnvironment ? (baseRate * 0.88).clamp(0.3, 1.0) : baseRate;

  String? smartBurstSummary({
    required int count,
    required double total,
    required String language,
  }) {
    if (count < 3) return null;

    final lang = LanguageEngine().resolve(language);
    final peakHour = _ledger.peakHour;
    final nowHour = DateTime.now().hour;
    final isPeak = nowHour == peakHour;
    final totalStr = total.toInt().toString();

    if (isPeak) {
      switch (lang.langKey) {
        case 'hi':
          return '$count भुगतान एक साथ, ${nHi(totalStr)} रुपये';
        case 'ta':
          return '$count பேமெண்ட் ஒரே நேரத்தில், ${nTa(totalStr)} மொத்தம்';
        case 'te':
          return '$count పేమెంట్లు ఒకేసారి, ${nTe(totalStr)} మొత్తం';
        default:
          return '$count payments together, $totalStr rupees total';
      }
    }

    return lang.burst(count, totalStr, VoiceStyle.normal);
  }

  void updateThresholds({
    double? largeTxMultiplier,
    double? largeTxAbsolute,
    int? rapidRepeatWindow,
    int? rapidRepeatMinCount,
  }) {
    if (largeTxMultiplier != null && largeTxMultiplier > 0) {
      _largeTxMultiplier = largeTxMultiplier;
    }
    if (largeTxAbsolute != null && largeTxAbsolute > 0) {
      _largeTxAbsolute = largeTxAbsolute;
    }
    if (rapidRepeatWindow != null && rapidRepeatWindow > 0) {
      _rapidRepeatWindow = rapidRepeatWindow;
    }
    if (rapidRepeatMinCount != null && rapidRepeatMinCount > 0) {
      _rapidRepeatMinCount = rapidRepeatMinCount;
    }
  }

  Map<String, dynamic> todaySnapshot() => {
        'date': _ledger.date.toIso8601String().substring(0, 10),
        'totalAmount': _ledger.totalAmount,
        'txCount': _ledger.txCount,
        'averageAmount': _ledger.averageAmount,
        'peakHour': _ledger.peakHour,
      };

  // ---------------------------------------------------------------------------
  // FRAUD / ANOMALY RISK
  // ---------------------------------------------------------------------------

  /// Calculates a review score from explicit signals supplied by the caller.
  /// No signal alone is treated as proof of fraud.
  FraudRiskAssessment assessFraudRisk({
    required double amount,
    double? normalAmount,
    int duplicateCount = 0,
    int refundCountToday = 0,
    int discountCountToday = 0,
    double discountPercent = 0,
    int stockAdjustmentCountToday = 0,
    bool invoiceVoided = false,
    bool afterHours = false,
  }) {
    var score = 0;
    final reasons = <String>[];
    final signals = <String, dynamic>{};

    if (normalAmount != null &&
        normalAmount > 0 &&
        amount >= normalAmount * _largeTxMultiplier) {
      score += 20;
      reasons.add('Transaction is much larger than the normal amount');
      signals['large_amount'] = true;
    }

    if (amount >= _largeTxAbsolute) {
      score += 15;
      reasons.add('High-value transaction requires review');
      signals['high_value'] = true;
    }

    if (duplicateCount > 0) {
      score += (duplicateCount * 15).clamp(0, 30);
      reasons.add('Repeated transaction/payment signal detected');
      signals['duplicate_count'] = duplicateCount;
    }

    if (refundCountToday >= 3) {
      score += 15;
      reasons.add('Unusually high number of refunds today');
      signals['refund_count_today'] = refundCountToday;
    }

    if (discountPercent >= 30) {
      score += 20;
      reasons.add('Large discount requires review');
      signals['discount_percent'] = discountPercent;
    } else if (discountPercent >= 15) {
      score += 10;
      reasons.add('Discount is above normal review threshold');
      signals['discount_percent'] = discountPercent;
    }

    if (discountCountToday >= 8) {
      score += 10;
      reasons.add('High number of discounted invoices today');
      signals['discount_count_today'] = discountCountToday;
    }

    if (stockAdjustmentCountToday >= 5) {
      score += 15;
      reasons.add('Frequent stock adjustments detected');
      signals['stock_adjustments_today'] = stockAdjustmentCountToday;
    }

    if (invoiceVoided) {
      score += 15;
      reasons.add('Voided invoice requires audit review');
      signals['invoice_voided'] = true;
    }

    if (afterHours) {
      score += 5;
      reasons.add('Operation occurred outside configured business hours');
      signals['after_hours'] = true;
    }

    score = score.clamp(0, 100);
    final level = score >= 60
        ? 'HIGH'
        : score >= 30
            ? 'MEDIUM'
            : 'LOW';

    return FraudRiskAssessment(
      score: score,
      level: level,
      reasons: reasons,
      signals: signals,
    );
  }

  void _detectRush(TxRecord tx) {
    final recentTxs = _ledger.recentRecords(_rushTapWindow.inSeconds);
    if (recentTxs.length >= _rushTapThreshold) {
      _enterRushMode();
    }
  }

  void _enterRushMode() {
    _isInRushMode = true;
    _rushModeSetAt = DateTime.now();
  }

  void _updateRushMode() {
    if (!_isInRushMode || _rushModeSetAt == null) return;
    if (DateTime.now().difference(_rushModeSetAt!) > _rushModeTimeout) {
      _isInRushMode = false;
      _rushModeSetAt = null;
    }
  }

  bool get isRushMode {
    _updateRushMode();
    return _isInRushMode;
  }

  VoiceStyle getAdaptiveStyle(VoiceStyle baseStyle) {
    if (isRushMode && baseStyle != VoiceStyle.alert) {
      return VoiceStyle.fastShop;
    }
    return baseStyle;
  }
}
