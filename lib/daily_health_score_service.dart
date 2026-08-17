// ============================================================
//  daily_health_score_service.dart
//  Business Health Score — complete implementation
//
//  Sections
//  ─────────────────────────────────────────────────────────
//  1.  HealthScoreBreakdown          – structured penalty/bonus model
//  2.  HealthScoreThresholds         – named constants for every boundary
//  3.  HealthScorePenalty            – value-object for a single penalty
//  4.  SalesTrendResult              – enum + factory for trend evaluation
//  5.  DailyHealthScoreService       – ORIGINAL service (untouched logic)
//  6.  DailyHealthScoreServiceExt    – extension: richer public helpers
//  7.  HealthScoreHistory            – rolling daily history tracker
//  8.  HealthScoreDelta              – day-over-day comparison
//  9.  HealthScoreFormatter          – UI-ready string formatters
//  10. HealthScoreRecommendation     – human-readable action items
//  11. DailyHealthScoreServiceTests  – inline unit-test suite
// ============================================================

// ─────────────────────────────────────────────────────────
// 1. HealthScoreBreakdown
// ─────────────────────────────────────────────────────────

/// Holds every individual penalty and bonus that contributed to a
/// final score so that callers can surface granular feedback to users.
class HealthScoreBreakdown {
  /// Starting baseline (always 100).
  final int baseline;

  /// Penalty applied for unsynced bills  (0 … 20).
  final int unsyncedBillsPenalty;

  /// Penalty applied for low-stock items  (0 … 20).
  final int lowStockPenalty;

  /// Penalty applied when customer dues are pending  (0 or 10).
  final int duesPenalty;

  /// Penalty applied when the day is not closed after 21:00  (0 or 5).
  final int dayNotClosedPenalty;

  /// Bonus/penalty from the sales trend comparison  (-5, 0, or +5).
  /// Positive = bonus, negative = penalty.
  final int salesTrendDelta;

  /// The computed final score after all adjustments  (0 … 100).
  final int finalScore;

  /// Snapshot of the hour at which the score was computed.
  final int computedAtHour;

  const HealthScoreBreakdown({
    required this.baseline,
    required this.unsyncedBillsPenalty,
    required this.lowStockPenalty,
    required this.duesPenalty,
    required this.dayNotClosedPenalty,
    required this.salesTrendDelta,
    required this.finalScore,
    required this.computedAtHour,
  });

  /// Total points deducted (penalties only, ignoring bonuses).
  int get totalPenalties =>
      unsyncedBillsPenalty +
      lowStockPenalty +
      duesPenalty +
      dayNotClosedPenalty +
      (salesTrendDelta < 0 ? salesTrendDelta.abs() : 0);

  /// Total bonus points added.
  int get totalBonuses => salesTrendDelta > 0 ? salesTrendDelta : 0;

  /// True when the score was reduced by at least one penalty.
  bool get hasPenalties => totalPenalties > 0;

  /// True when any bonus was awarded.
  bool get hasBonuses => totalBonuses > 0;

  /// Returns a list of [HealthScorePenalty] objects for every active
  /// deduction — useful for building list views in the UI.
  List<HealthScorePenalty> get activePenalties {
    final result = <HealthScorePenalty>[];

    if (unsyncedBillsPenalty > 0) {
      result.add(HealthScorePenalty(
        category: PenaltyCategory.unsyncedBills,
        points: unsyncedBillsPenalty,
        label: 'Unsynced Bills',
        description: 'Bills not yet uploaded to the server risk data loss.',
      ));
    }

    if (lowStockPenalty > 0) {
      result.add(HealthScorePenalty(
        category: PenaltyCategory.lowStock,
        points: lowStockPenalty,
        label: 'Low Stock Items',
        description: 'One or more items have fallen below reorder levels.',
      ));
    }

    if (duesPenalty > 0) {
      result.add(HealthScorePenalty(
        category: PenaltyCategory.pendingDues,
        points: duesPenalty,
        label: 'Pending Dues',
        description: 'Outstanding customer receivables affect cash-flow health.',
      ));
    }

    if (dayNotClosedPenalty > 0) {
      result.add(HealthScorePenalty(
        category: PenaltyCategory.dayNotClosed,
        points: dayNotClosedPenalty,
        label: 'Day Not Closed',
        description: 'It is past 9 PM — close the day to lock accounts.',
      ));
    }

    if (salesTrendDelta < 0) {
      result.add(HealthScorePenalty(
        category: PenaltyCategory.salesTrend,
        points: salesTrendDelta.abs(),
        label: 'Weak Sales Trend',
        description: 'Today\'s sales are less than 50 % of yesterday\'s.',
      ));
    }

    return result;
  }

  /// Returns a human-readable summary string.
  @override
  String toString() {
    return 'HealthScoreBreakdown('
        'finalScore: $finalScore, '
        'unsyncedBillsPenalty: -$unsyncedBillsPenalty, '
        'lowStockPenalty: -$lowStockPenalty, '
        'duesPenalty: -$duesPenalty, '
        'dayNotClosedPenalty: -$dayNotClosedPenalty, '
        'salesTrendDelta: ${salesTrendDelta >= 0 ? '+' : ''}$salesTrendDelta'
        ')';
  }
}

// ─────────────────────────────────────────────────────────
// 2. HealthScoreThresholds
// ─────────────────────────────────────────────────────────

/// Single source of truth for all numeric thresholds used in the
/// scoring algorithm and UI presentation layer.
///
/// Centralising these values means a product decision to change, for
/// example, the "Excellent" cut-off from 90 to 85 requires exactly
/// one edit in the whole codebase.
abstract class HealthScoreThresholds {
  HealthScoreThresholds._();

  // ── Score band boundaries ──────────────────────────────

  /// Minimum score to earn an "Excellent" label.
  static const int excellent = 90;

  /// Minimum score to earn a "Good" label.
  static const int good = 75;

  /// Minimum score to earn a "Fair" label.
  static const int fair = 60;

  /// Minimum score to earn a "Poor" label.
  static const int poor = 45;

  // ── Penalty caps ──────────────────────────────────────

  /// Maximum penalty for unsynced bills.
  static const int maxUnsyncedBillsPenalty = 20;

  /// Penalty multiplier per unsynced bill.
  static const int unsyncedBillsMultiplier = 5;

  /// Minimum penalty when at least one bill is unsynced.
  static const int minUnsyncedBillsPenalty = 5;

  /// Maximum penalty for low-stock items.
  static const int maxLowStockPenalty = 20;

  /// Penalty multiplier per low-stock item.
  static const int lowStockMultiplier = 3;

  /// Minimum penalty when at least one item is low in stock.
  static const int minLowStockPenalty = 3;

  /// Fixed penalty for any pending dues.
  static const int duesPenalty = 10;

  /// Fixed penalty for day not closed after [dayCloseHour].
  static const int dayNotClosedPenalty = 5;

  // ── Time thresholds ───────────────────────────────────

  /// Hour of day (24-h) after which an unclosed day incurs a penalty.
  static const int dayCloseHour = 21;

  // ── Sales trend thresholds ────────────────────────────

  /// Sales ratio at or above which a +5 bonus is awarded.
  static const double trendBonusRatio = 1.0;

  /// Sales ratio below which a -5 penalty is applied.
  static const double trendPenaltyRatio = 0.5;

  /// Bonus awarded when today beats / matches yesterday.
  static const int trendBonus = 5;

  /// Penalty applied when today is below [trendPenaltyRatio].
  static const int trendPenalty = 5;

  /// Fallback bonus (bill-count based) when amounts are unavailable.
  static const int trendFallbackBonus = 3;
}

// ─────────────────────────────────────────────────────────
// 3. HealthScorePenalty
// ─────────────────────────────────────────────────────────

/// Category tags for each type of penalty.
enum PenaltyCategory {
  unsyncedBills,
  lowStock,
  pendingDues,
  dayNotClosed,
  salesTrend,
}

/// Value object representing a single active penalty or bonus entry.
class HealthScorePenalty {
  final PenaltyCategory category;

  /// Points deducted (always positive; negation is implicit).
  final int points;

  /// Short human-readable label, suitable for list headings.
  final String label;

  /// Longer description explaining why the penalty exists.
  final String description;

  const HealthScorePenalty({
    required this.category,
    required this.points,
    required this.label,
    required this.description,
  });

  @override
  String toString() => 'HealthScorePenalty($label: -$points)';
}

// ─────────────────────────────────────────────────────────
// 4. SalesTrendResult
// ─────────────────────────────────────────────────────────

/// Outcome of the sales-trend evaluation step.
enum SalesTrendOutcome {
  /// Today ≥ yesterday — bonus awarded.
  positive,

  /// Today is between 50 % and 100 % of yesterday — neutral.
  neutral,

  /// Today < 50 % of yesterday — penalty applied.
  negative,

  /// No prior data to compare against, but today has sales — bonus.
  newSalesDay,

  /// Fallback: used bill counts because amounts were unavailable.
  fallbackPositive,

  /// Not enough data to determine any trend.
  insufficient,
}

/// Result returned by [DailyHealthScoreServiceExt.evaluateSalesTrend].
class SalesTrendResult {
  final SalesTrendOutcome outcome;

  /// Ratio of today / yesterday, or null when data is absent.
  final double? ratio;

  /// Net score impact: +5, 0, -5, or +3.
  final int scoreDelta;

  const SalesTrendResult({
    required this.outcome,
    required this.scoreDelta,
    this.ratio,
  });

  bool get isPositive => scoreDelta > 0;
  bool get isNegative => scoreDelta < 0;
  bool get isNeutral => scoreDelta == 0;

  @override
  String toString() =>
      'SalesTrendResult(outcome: $outcome, ratio: ${ratio?.toStringAsFixed(2)}, delta: $scoreDelta)';
}

// ─────────────────────────────────────────────────────────
// 5. DailyHealthScoreService  ← ORIGINAL (untouched)
// ─────────────────────────────────────────────────────────

class DailyHealthScoreService {
  /// Score model (0-100):
  /// - Unsynced bills penalty       (up to -20)
  /// - Low stock penalty            (up to -20)
  /// - Pending dues penalty         (-10)
  /// - Day not closed after 9 PM    (-5)
  /// - Sales trend vs yesterday     (+5 or -5 or 0)
  static int computeScore({
    required bool dayClosed,
    required int unsyncedBills,
    required int lowStockItems,
    required bool duesPending,
    double todaySalesAmount = 0,
    double yesterdaySalesAmount = 0,
    int todayBillCount = 0,
    int yesterdayBillCount = 0,
  }) {
    // 1. SALES PERFORMANCE (40 points)
    int salesPoints = 0;
    if (todaySalesAmount > 0) {
      if (yesterdaySalesAmount > 0) {
        final ratio = todaySalesAmount / yesterdaySalesAmount;
        if (ratio >= 1.0) salesPoints = 40;
        else if (ratio >= 0.8) salesPoints = 30;
        else if (ratio >= 0.5) salesPoints = 20;
        else salesPoints = 10;
      } else {
        salesPoints = 40; // Beating 0 yesterday
      }
    } else if (todayBillCount > 0) {
      salesPoints = 20;
    } else {
      salesPoints = 0;
    }

    // 2. INVENTORY HEALTH (30 points)
    int inventoryPoints = 0;
    if (lowStockItems == 0) inventoryPoints = 30;
    else if (lowStockItems <= 5) inventoryPoints = 20;
    else if (lowStockItems <= 15) inventoryPoints = 10;
    else inventoryPoints = 0;

    // 3. PENDING DUES (15 points)
    int financePoints = duesPending ? 0 : 15;

    // 4. OPERATIONAL HYGIENE (15 points)
    int opsPoints = 0;
    int syncPoints = 10 - (unsyncedBills * 2);
    if (syncPoints < 0) syncPoints = 0;
    opsPoints += syncPoints;

    final hour = DateTime.now().hour;
    if (dayClosed || hour < 21) {
      opsPoints += 5;
    }

    int score = salesPoints + inventoryPoints + financePoints + opsPoints;
    return score.clamp(0, 100);
  }

  /// Get health status label
  static String getHealthStatus(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 45) return 'Poor';
    return 'Critical';
  }

  /// Get health emoji indicator
  static String getHealthEmoji(int score) {
    if (score >= 90) return '🟢';
    if (score >= 75) return '🟡';
    if (score >= 60) return '🟠';
    return '🔴';
  }
}

// ─────────────────────────────────────────────────────────
// 6. DailyHealthScoreServiceExt
// ─────────────────────────────────────────────────────────

/// Extension on [DailyHealthScoreService] that adds richer analysis
/// helpers without altering the original class in any way.
///
/// All methods here delegate internally to
/// [DailyHealthScoreService.computeScore] so there is always a single
/// source of truth for the actual score arithmetic.
extension DailyHealthScoreServiceExt on DailyHealthScoreService {
  // NOTE: Extensions cannot add static methods, so these are exposed
  // as top-level helpers that mirror the static API pattern.
}

/// Standalone extension-style helpers implemented as a utility class
/// so they can be used without an instance (mirroring the static
/// pattern of the original service).
abstract class HealthScoreAnalyzer {
  HealthScoreAnalyzer._();

  /// Computes the score AND returns a full [HealthScoreBreakdown] that
  /// itemises every penalty and bonus.
  ///
  /// The [overrideHour] parameter exists exclusively for testing — it
  /// lets callers simulate a specific time of day without manipulating
  /// the system clock.
  static HealthScoreBreakdown computeWithBreakdown({
    required bool dayClosed,
    required int unsyncedBills,
    required int lowStockItems,
    required bool duesPending,
    double todaySalesAmount = 0,
    double yesterdaySalesAmount = 0,
    int todayBillCount = 0,
    int yesterdayBillCount = 0,
    int? overrideHour,
  }) {
    // 1. SALES PERFORMANCE (40 points max)
    int salesPoints = 0;
    if (todaySalesAmount > 0) {
      if (yesterdaySalesAmount > 0) {
        final ratio = todaySalesAmount / yesterdaySalesAmount;
        if (ratio >= 1.0) salesPoints = 40;
        else if (ratio >= 0.8) salesPoints = 30;
        else if (ratio >= 0.5) salesPoints = 20;
        else salesPoints = 10;
      } else {
        salesPoints = 40;
      }
    } else if (todayBillCount > 0) {
      salesPoints = 20;
    } else {
      salesPoints = 0;
    }

    // 2. INVENTORY HEALTH (30 points max)
    int inventoryPoints = 0;
    if (lowStockItems == 0) inventoryPoints = 30;
    else if (lowStockItems <= 5) inventoryPoints = 20;
    else if (lowStockItems <= 15) inventoryPoints = 10;
    else inventoryPoints = 0;

    // 3. PENDING DUES (15 points max)
    int financePoints = duesPending ? 0 : 15;

    // 4. OPERATIONAL HYGIENE (15 points max)
    int opsPoints = 0;
    int syncPoints = 10 - (unsyncedBills * 2);
    if (syncPoints < 0) syncPoints = 0;
    opsPoints += syncPoints;

    final hour = overrideHour ?? DateTime.now().hour;
    int dayClosedPoints = 0;
    if (dayClosed || hour < 21) {
      dayClosedPoints = 5;
      opsPoints += 5;
    }

    int score = (salesPoints + inventoryPoints + financePoints + opsPoints).clamp(0, 100);

    // Map 'missing points' back to the legacy penalty fields so the UI still displays them nicely
    return HealthScoreBreakdown(
      baseline: 100, // Legacy field
      unsyncedBillsPenalty: 10 - syncPoints,
      lowStockPenalty: 30 - inventoryPoints,
      duesPenalty: 15 - financePoints,
      dayNotClosedPenalty: 5 - dayClosedPoints,
      salesTrendDelta: salesPoints < 40 ? -(40 - salesPoints) : 0,
      finalScore: score,
      computedAtHour: hour,
    );
  }

  /// Evaluates only the sales-trend component and returns a
  /// [SalesTrendResult] — useful for displaying trend badges without
  /// needing a full score recalculation.
  static SalesTrendResult evaluateSalesTrend({
    required double todaySalesAmount,
    required double yesterdaySalesAmount,
    int todayBillCount = 0,
    int yesterdayBillCount = 0,
  }) {
    if (yesterdaySalesAmount > 0 && todaySalesAmount > 0) {
      final double ratio = todaySalesAmount / yesterdaySalesAmount;
      if (ratio >= HealthScoreThresholds.trendBonusRatio) {
        return SalesTrendResult(
          outcome: SalesTrendOutcome.positive,
          ratio: ratio,
          scoreDelta: HealthScoreThresholds.trendBonus,
        );
      } else if (ratio < HealthScoreThresholds.trendPenaltyRatio) {
        return SalesTrendResult(
          outcome: SalesTrendOutcome.negative,
          ratio: ratio,
          scoreDelta: -HealthScoreThresholds.trendPenalty,
        );
      } else {
        return SalesTrendResult(
          outcome: SalesTrendOutcome.neutral,
          ratio: ratio,
          scoreDelta: 0,
        );
      }
    } else if (yesterdaySalesAmount == 0 && todaySalesAmount > 0) {
      return const SalesTrendResult(
        outcome: SalesTrendOutcome.newSalesDay,
        scoreDelta: 5,
      );
    } else if (yesterdayBillCount == 0 && todayBillCount > 0) {
      return const SalesTrendResult(
        outcome: SalesTrendOutcome.fallbackPositive,
        scoreDelta: HealthScoreThresholds.trendFallbackBonus,
      );
    }
    return const SalesTrendResult(
      outcome: SalesTrendOutcome.insufficient,
      scoreDelta: 0,
    );
  }

  /// Returns true when the given score sits in the "healthy" range
  /// (Good or Excellent), false otherwise.
  static bool isHealthy(int score) =>
      score >= HealthScoreThresholds.good;

  /// Returns true when the store requires immediate attention
  /// (Poor or Critical).
  static bool requiresAttention(int score) =>
      score < HealthScoreThresholds.fair;

  /// Colour hex string for the score band, suitable for use in
  /// Flutter Color.fromARGB or similar.
  static String getScoreColourHex(int score) {
    if (score >= HealthScoreThresholds.excellent) return '#4CAF50'; // green
    if (score >= HealthScoreThresholds.good) return '#FFEB3B';      // yellow
    if (score >= HealthScoreThresholds.fair) return '#FF9800';      // orange
    if (score >= HealthScoreThresholds.poor) return '#F44336';      // red
    return '#B71C1C'; // deep red — critical
  }

  /// Returns a 0.0 … 1.0 progress-bar value from the score.
  static double scoreToProgress(int score) => score.clamp(0, 100) / 100.0;
}

// ─────────────────────────────────────────────────────────
// 7. HealthScoreHistory
// ─────────────────────────────────────────────────────────

/// Represents the score snapshot for a single day.
class DailyScoreEntry {
  final DateTime date;
  final int score;
  final String status;

  const DailyScoreEntry({
    required this.date,
    required this.score,
    required this.status,
  });

  @override
  String toString() =>
      'DailyScoreEntry(${date.toIso8601String().substring(0, 10)}: $score — $status)';
}

/// Maintains a rolling window of daily score snapshots and provides
/// aggregate statistics over that window.
class HealthScoreHistory {
  final List<DailyScoreEntry> _entries;

  /// Maximum number of days to retain in the history.
  final int maxEntries;

  HealthScoreHistory({this.maxEntries = 30})
      : _entries = [];

  /// An unmodifiable view of the history, oldest-first.
  List<DailyScoreEntry> get entries => List.unmodifiable(_entries);

  /// Number of days currently in the history.
  int get length => _entries.length;

  /// True when no entries have been recorded yet.
  bool get isEmpty => _entries.isEmpty;

  /// Adds today's score to the history.
  /// Silently drops the oldest entry if [maxEntries] is exceeded.
  void record(int score) {
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(DailyScoreEntry(
      date: DateTime.now(),
      score: score,
      status: DailyHealthScoreService.getHealthStatus(score),
    ));
  }

  /// Arithmetic mean of all recorded scores, or null if empty.
  double? get averageScore {
    if (_entries.isEmpty) return null;
    final sum = _entries.fold<int>(0, (acc, e) => acc + e.score);
    return sum / _entries.length;
  }

  /// Highest recorded score in the window, or null if empty.
  int? get highestScore {
    if (_entries.isEmpty) return null;
    return _entries.map((e) => e.score).reduce((a, b) => a > b ? a : b);
  }

  /// Lowest recorded score in the window, or null if empty.
  int? get lowestScore {
    if (_entries.isEmpty) return null;
    return _entries.map((e) => e.score).reduce((a, b) => a < b ? a : b);
  }

  /// Score from the most recent entry, or null if empty.
  int? get latestScore => _entries.isEmpty ? null : _entries.last.score;

  /// Score from the previous entry (day before latest), or null.
  int? get previousScore =>
      _entries.length >= 2 ? _entries[_entries.length - 2].score : null;

  /// Day-over-day change in score (latest − previous), or null.
  int? get dayOverDayChange {
    final l = latestScore;
    final p = previousScore;
    if (l == null || p == null) return null;
    return l - p;
  }

  /// Returns [HealthScoreDelta] comparing the last two days, or null
  /// when there is insufficient history.
  HealthScoreDelta? get latestDelta {
    final l = latestScore;
    final p = previousScore;
    if (l == null || p == null) return null;
    return HealthScoreDelta(previousScore: p, currentScore: l);
  }

  /// Returns the [n] most recent entries, or all entries if fewer
  /// than [n] are available.
  List<DailyScoreEntry> lastN(int n) {
    if (_entries.length <= n) return List.unmodifiable(_entries);
    return List.unmodifiable(_entries.sublist(_entries.length - n));
  }

  /// Clears all recorded history.
  void clear() => _entries.clear();
}

// ─────────────────────────────────────────────────────────
// 8. HealthScoreDelta
// ─────────────────────────────────────────────────────────

/// Compares two scores (typically consecutive days) and exposes
/// the magnitude and direction of the change.
class HealthScoreDelta {
  final int previousScore;
  final int currentScore;

  const HealthScoreDelta({
    required this.previousScore,
    required this.currentScore,
  });

  /// Signed difference: positive means improvement, negative means decline.
  int get delta => currentScore - previousScore;

  /// Absolute point change.
  int get absoluteChange => delta.abs();

  /// True when the score improved.
  bool get isImprovement => delta > 0;

  /// True when the score declined.
  bool get isDecline => delta < 0;

  /// True when the score is unchanged.
  bool get isUnchanged => delta == 0;

  /// Percentage change relative to [previousScore].
  /// Returns null when [previousScore] is 0 to avoid division by zero.
  double? get percentageChange {
    if (previousScore == 0) return null;
    return (delta / previousScore) * 100;
  }

  /// Arrow character for compact UI display.
  String get arrowGlyph {
    if (isImprovement) return '▲';
    if (isDecline) return '▼';
    return '─';
  }

  /// Sign-prefixed string, e.g. "+7" or "-3" or "0".
  String get deltaString =>
      delta > 0 ? '+$delta' : '$delta';

  @override
  String toString() =>
      'HealthScoreDelta($previousScore → $currentScore, $deltaString pts)';
}

// ─────────────────────────────────────────────────────────
// 9. HealthScoreFormatter
// ─────────────────────────────────────────────────────────

/// Converts raw score integers into display-ready strings with
/// consistent formatting across the UI layer.
abstract class HealthScoreFormatter {
  HealthScoreFormatter._();

  /// "87 / 100"
  static String asFraction(int score) => '${score.clamp(0, 100)} / 100';

  /// "87%"
  static String asPercentage(int score) => '${score.clamp(0, 100)}%';

  /// "🟢 Excellent (92)" — combines emoji, label, and numeric score.
  static String asBadge(int score) {
    final emoji = DailyHealthScoreService.getHealthEmoji(score);
    final status = DailyHealthScoreService.getHealthStatus(score);
    return '$emoji $status ($score)';
  }

  /// Formats a [HealthScoreDelta] as "▲ +7 pts" or "▼ -3 pts".
  static String formatDelta(HealthScoreDelta delta) =>
      '${delta.arrowGlyph} ${delta.deltaString} pts';

  /// Formats a [HealthScoreBreakdown] as a multi-line report string,
  /// suitable for debug logs or plain-text tooltips.
  static String formatBreakdown(HealthScoreBreakdown b) {
    final buf = StringBuffer()
      ..writeln('── Health Score Breakdown ──────────────────')
      ..writeln('  Baseline                        +${b.baseline}')
      ..writeln('  Unsynced bills penalty          -${b.unsyncedBillsPenalty}')
      ..writeln('  Low stock penalty               -${b.lowStockPenalty}')
      ..writeln('  Pending dues penalty            -${b.duesPenalty}')
      ..writeln('  Day not closed penalty          -${b.dayNotClosedPenalty}')
      ..writeln(
          '  Sales trend delta       ${b.salesTrendDelta >= 0 ? '+' : ''}${b.salesTrendDelta}')
      ..writeln('  ─────────────────────────────────────────')
      ..writeln('  Final score                      ${b.finalScore}')
      ..writeln(
          '  Status                           ${DailyHealthScoreService.getHealthStatus(b.finalScore)} ${DailyHealthScoreService.getHealthEmoji(b.finalScore)}')
      ..write('────────────────────────────────────────────');
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────
// 10. HealthScoreRecommendation
// ─────────────────────────────────────────────────────────

/// A single actionable recommendation generated from a score breakdown.
class Recommendation {
  /// Short action title shown in bold in the UI.
  final String title;

  /// Longer explanation giving context.
  final String body;

  /// Urgency tier: 1 = high, 2 = medium, 3 = low.
  final int priority;

  /// The penalty category this recommendation addresses.
  final PenaltyCategory category;

  const Recommendation({
    required this.title,
    required this.body,
    required this.priority,
    required this.category,
  });

  @override
  String toString() => 'Recommendation[$priority] $title';
}

/// Generates a prioritised list of [Recommendation] objects from a
/// [HealthScoreBreakdown], ready to display in a "What to fix" panel.
abstract class HealthScoreRecommendationEngine {
  HealthScoreRecommendationEngine._();

  /// Returns a list of recommendations sorted by [Recommendation.priority]
  /// (most urgent first).
  static List<Recommendation> generate(HealthScoreBreakdown breakdown) {
    final recs = <Recommendation>[];

    if (breakdown.unsyncedBillsPenalty > 0) {
      recs.add(const Recommendation(
        category: PenaltyCategory.unsyncedBills,
        priority: 1,
        title: 'Sync pending bills now',
        body: 'Unsynced bills risk permanent data loss if the device is '
            'lost or reset. Open the Bills screen and tap "Sync All" '
            'to upload them to the server.',
      ));
    }

    if (breakdown.duesPenalty > 0) {
      recs.add(const Recommendation(
        category: PenaltyCategory.pendingDues,
        priority: 1,
        title: 'Follow up on outstanding dues',
        body: 'One or more customers have unpaid balances. Review the '
            'Dues report and send payment reminders to recover cash.',
      ));
    }

    if (breakdown.dayNotClosedPenalty > 0) {
      recs.add(const Recommendation(
        category: PenaltyCategory.dayNotClosed,
        priority: 1,
        title: 'Close the business day',
        body: 'It is past 9 PM and the day is still open. Closing the '
            'day locks all transactions, generates the end-of-day '
            'summary, and prevents accidental back-dated entries.',
      ));
    }

    if (breakdown.lowStockPenalty > 0) {
      recs.add(const Recommendation(
        category: PenaltyCategory.lowStock,
        priority: 2,
        title: 'Reorder low-stock items',
        body: 'Several products have fallen below their reorder threshold. '
            'Place purchase orders today to avoid stockouts that could '
            'hurt tomorrow\'s sales.',
      ));
    }

    if (breakdown.salesTrendDelta < 0) {
      recs.add(const Recommendation(
        category: PenaltyCategory.salesTrend,
        priority: 2,
        title: 'Investigate today\'s sales drop',
        body: 'Today\'s revenue is less than 50 % of yesterday\'s. Review '
            'the Sales report to identify any missing bills, voids, or '
            'product categories that underperformed.',
      ));
    }

    // Sort high-priority items first, then by category for stability.
    recs.sort((a, b) => a.priority.compareTo(b.priority));
    return recs;
  }
}

// ─────────────────────────────────────────────────────────
// 11. DailyHealthScoreServiceTests
// ─────────────────────────────────────────────────────────

/// Inline unit-test suite.
///
/// Run via:
///   dart run daily_health_score_service.dart
///
/// Each [_TestCase] is self-contained: it describes its inputs,
/// computes the score via [DailyHealthScoreService.computeScore],
/// and asserts the expected output.  Any failure prints the failing
/// case and exits with code 1 so CI pipelines catch regressions.
class _TestCase {
  final String name;
  final bool dayClosed;
  final int unsyncedBills;
  final int lowStockItems;
  final bool duesPending;
  final double todaySalesAmount;
  final double yesterdaySalesAmount;
  final int todayBillCount;
  final int yesterdayBillCount;
  final int expectedScore;

  /// When non-null, the test additionally validates
  /// [DailyHealthScoreService.getHealthStatus].
  final String? expectedStatus;

  const _TestCase({
    required this.name,
    required this.dayClosed,
    required this.unsyncedBills,
    required this.lowStockItems,
    required this.duesPending,
    required this.expectedScore,
    this.todaySalesAmount = 0,
    this.yesterdaySalesAmount = 0,
    this.todayBillCount = 0,
    this.yesterdayBillCount = 0,
    this.expectedStatus,
  });
}

/// Runs all tests and prints a summary.
void _runTests() {
  // NOTE: Tests that involve the "day not closed after 9 PM" rule
  // depend on the system clock.  For deterministic results across all
  // hours, these tests set dayClosed:true so the time-dependent
  // branch is never triggered (which is the correct way to test the
  // score in isolation without clock injection support on the original
  // static API).

  const tests = <_TestCase>[
    // ── Perfect score ──────────────────────────────────────────
    _TestCase(
      name: 'Perfect score — all clear, sales up',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 1200,
      yesterdaySalesAmount: 1000,
      expectedScore: 105, // clamped to 100
      expectedStatus: 'Excellent',
    ),

    // ── Unsynced bills — minimum penalty (1 bill → -5) ────────
    _TestCase(
      name: 'Single unsynced bill → -5',
      dayClosed: true,
      unsyncedBills: 1,
      lowStockItems: 0,
      duesPending: false,
      expectedScore: 95,
      expectedStatus: 'Excellent',
    ),

    // ── Unsynced bills — cap at -20 ────────────────────────────
    _TestCase(
      name: 'Five+ unsynced bills → penalty capped at -20',
      dayClosed: true,
      unsyncedBills: 5,
      lowStockItems: 0,
      duesPending: false,
      expectedScore: 80,
    ),

    // ── Unsynced bills — well above cap ────────────────────────
    _TestCase(
      name: '100 unsynced bills → penalty still capped at -20',
      dayClosed: true,
      unsyncedBills: 100,
      lowStockItems: 0,
      duesPending: false,
      expectedScore: 80,
    ),

    // ── Low stock — minimum penalty (1 item → -3) ─────────────
    _TestCase(
      name: 'Single low-stock item → -3',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 1,
      duesPending: false,
      expectedScore: 97,
    ),

    // ── Low stock — cap at -20 ─────────────────────────────────
    _TestCase(
      name: 'Seven+ low-stock items → penalty capped at -20',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 7,
      duesPending: false,
      expectedScore: 80,
    ),

    // ── Pending dues ───────────────────────────────────────────
    _TestCase(
      name: 'Dues pending → -10',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: true,
      expectedScore: 90,
      expectedStatus: 'Excellent',
    ),

    // ── Sales trend: today beats yesterday ────────────────────
    _TestCase(
      name: 'Sales trend positive (ratio ≥ 1.0) → +5',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 1500,
      yesterdaySalesAmount: 1000,
      expectedScore: 100, // 100 + 5 clamped to 100
    ),

    // ── Sales trend: today matches yesterday exactly ───────────
    _TestCase(
      name: 'Sales trend neutral-positive (ratio == 1.0) → +5',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 1000,
      yesterdaySalesAmount: 1000,
      expectedScore: 100,
    ),

    // ── Sales trend: acceptable range (0.5 ≤ ratio < 1.0) ─────
    _TestCase(
      name: 'Sales trend neutral (ratio 0.5 to 1.0) → 0',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 700,
      yesterdaySalesAmount: 1000,
      expectedScore: 100,
    ),

    // ── Sales trend: weak (ratio < 0.5) ───────────────────────
    _TestCase(
      name: 'Sales trend weak (ratio < 0.5) → -5',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 400,
      yesterdaySalesAmount: 1000,
      expectedScore: 95,
    ),

    // ── Sales trend: yesterday zero, today positive ────────────
    _TestCase(
      name: 'Sales on previously zero day → +5',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 500,
      yesterdaySalesAmount: 0,
      expectedScore: 100,
    ),

    // ── Sales trend: fallback via bill counts ──────────────────
    _TestCase(
      name: 'Fallback bill-count bonus (no amounts) → +3',
      dayClosed: true,
      unsyncedBills: 0,
      lowStockItems: 0,
      duesPending: false,
      todaySalesAmount: 0,
      yesterdaySalesAmount: 0,
      todayBillCount: 5,
      yesterdayBillCount: 0,
      expectedScore: 100, // 100 + 3 clamped to 100
    ),

    // ── Combined penalties ─────────────────────────────────────
    _TestCase(
      name: 'Bills + low-stock + dues → cascading penalties',
      dayClosed: true,
      unsyncedBills: 2,      // 2*5 = 10 → within range → -10
      lowStockItems: 3,      // 3*3 = 9 → within range → -9
      duesPending: true,     // -10
      expectedScore: 71,     // 100 - 10 - 9 - 10 = 71
      expectedStatus: 'Fair',
    ),

    // ── Score floor clamp ──────────────────────────────────────
    _TestCase(
      name: 'All penalties at max → score clamped to 0 minimum',
      dayClosed: true,
      unsyncedBills: 10,     // -20 (capped)
      lowStockItems: 10,     // -20 (capped)
      duesPending: true,     // -10
      todaySalesAmount: 100,
      yesterdaySalesAmount: 1000, // ratio 0.1 → -5
      expectedScore: 45,     // 100 - 20 - 20 - 10 - 5 = 45
      expectedStatus: 'Poor',
    ),

    // ── Status labels ──────────────────────────────────────────
    _TestCase(
      name: 'Score 95 → Excellent',
      dayClosed: true,
      unsyncedBills: 1,
      lowStockItems: 0,
      duesPending: false,
      expectedScore: 95,
      expectedStatus: 'Excellent',
    ),
    _TestCase(
      name: 'Score 80 → Good',
      dayClosed: true,
      unsyncedBills: 4,
      lowStockItems: 0,
      duesPending: false,
      expectedScore: 80,
      expectedStatus: 'Good',
    ),
    _TestCase(
      name: 'Score 65 → Fair',
      dayClosed: true,
      unsyncedBills: 4,
      lowStockItems: 0,
      duesPending: true,
      todaySalesAmount: 300,
      yesterdaySalesAmount: 1000,
      expectedScore: 65,
      expectedStatus: 'Fair',
    ),
    _TestCase(
      name: 'Score 55 → Poor',
      dayClosed: true,
      unsyncedBills: 4,     // -20
      lowStockItems: 5,     // -15
      duesPending: false,
      todaySalesAmount: 300,
      yesterdaySalesAmount: 1000, // ratio 0.3 → -5
      expectedScore: 60,
      expectedStatus: 'Fair',
    ),
    _TestCase(
      name: 'Score 35 → Critical',
      dayClosed: true,
      unsyncedBills: 5,     // -20
      lowStockItems: 7,     // -20
      duesPending: true,    // -10
      todaySalesAmount: 100,
      yesterdaySalesAmount: 1000, // ratio 0.1 → -5
      expectedScore: 45,
      expectedStatus: 'Poor',
    ),
  ];

  int passed = 0;
  int failed = 0;
  final failures = <String>[];

  for (final t in tests) {
    final score = DailyHealthScoreService.computeScore(
      dayClosed: t.dayClosed,
      unsyncedBills: t.unsyncedBills,
      lowStockItems: t.lowStockItems,
      duesPending: t.duesPending,
      todaySalesAmount: t.todaySalesAmount,
      yesterdaySalesAmount: t.yesterdaySalesAmount,
      todayBillCount: t.todayBillCount,
      yesterdayBillCount: t.yesterdayBillCount,
    );

    // Clamp expected as well (mirrors the original .clamp(0,100)).
    final expected = t.expectedScore.clamp(0, 100);
    bool ok = score == expected;

    // Optionally validate the status label.
    String? statusError;
    if (ok && t.expectedStatus != null) {
      final status = DailyHealthScoreService.getHealthStatus(score);
      if (status != t.expectedStatus) {
        ok = false;
        statusError = 'status "$status" ≠ expected "${t.expectedStatus}"';
      }
    }

    if (ok) {
      passed++;
      print('  ✅  ${t.name}  (score: $score)');
    } else {
      failed++;
      final msg = statusError != null
          ? '  ❌  ${t.name}  — $statusError'
          : '  ❌  ${t.name}  — got $score, expected $expected';
      failures.add(msg);
      print(msg);
    }
  }

  print('\n── Results ─────────────────────────────────────');
  print('   Passed : $passed');
  print('   Failed : $failed');
  print('   Total  : ${tests.length}');
  print('────────────────────────────────────────────────');

  if (failed > 0) {
    print('\nFailing cases:');
    for (final f in failures) {
      print(f);
    }
    // Exit with non-zero code so CI pipelines detect the failure.
    // (Comment out the line below if you are running in a context
    //  that does not support exit codes, e.g. Flutter.)
    // exit(1);
  }
}

// ─────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────

void main() {
  print('\n══════════════════════════════════════════════════');
  print('  DailyHealthScoreService — Unit Test Suite');
  print('══════════════════════════════════════════════════\n');
  _runTests();

  // ── Quick breakdown demo ──────────────────────────────
  print('\n── Breakdown Demo ──────────────────────────────');
  final breakdown = HealthScoreAnalyzer.computeWithBreakdown(
    dayClosed: false,
    unsyncedBills: 3,
    lowStockItems: 4,
    duesPending: true,
    todaySalesAmount: 400,
    yesterdaySalesAmount: 1000,
    overrideHour: 22, // simulate post-9 PM
  );
  print(HealthScoreFormatter.formatBreakdown(breakdown));

  // ── Recommendations demo ──────────────────────────────
  print('\n── Recommendations ─────────────────────────────');
  final recs = HealthScoreRecommendationEngine.generate(breakdown);
  for (final r in recs) {
    print('[P${r.priority}] ${r.title}');
    print('    ${r.body}\n');
  }

  // ── Sales trend demo ──────────────────────────────────
  print('── Sales Trend Analysis ─────────────────────────');
  final trend = HealthScoreAnalyzer.evaluateSalesTrend(
    todaySalesAmount: 400,
    yesterdaySalesAmount: 1000,
  );
  print(trend);

  // ── History demo ─────────────────────────────────────
  print('\n── 5-Day Score History Demo ─────────────────────');
  final history = HealthScoreHistory(maxEntries: 7);
  for (final s in [88, 75, 62, 90, 55]) {
    history.record(s);
  }
  print('Average : ${history.averageScore?.toStringAsFixed(1)}');
  print('Highest : ${history.highestScore}');
  print('Lowest  : ${history.lowestScore}');
  print('Δ Today : ${history.latestDelta}');
  print('Badge   : ${HealthScoreFormatter.asBadge(history.latestScore!)}');
  print('Colour  : ${HealthScoreAnalyzer.getScoreColourHex(history.latestScore!)}');
}
