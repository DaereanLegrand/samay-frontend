/// Rank-bracket policy.
///
/// [rankBracketForPercentile] mirrors the `recalculate_ranks` SQL CASE
/// (`supabase/migrations/120_views_ranking/02_ranking.sql`):
/// ≥90 → b90_100, ≥80 → b80_90, ≥60 → b60_80, ≥40 → b40_60, ≥20 → b20_40,
/// else b0_20.
///
/// Labels are single ranking letters: S is the
/// top bracket, E the bottom. BuildContext-free constants by design (same
/// rationale as error strings in `lib/core/errors/**`); the app is
/// es-first and [RankBadge] renders them uppercased.
const _bracketLabels = <String, String>{
  'b90_100': 'S',
  'b80_90': 'A',
  'b60_80': 'B',
  'b40_60': 'C',
  'b20_40': 'D',
  'b0_20': 'E',
};

/// The display label for a rank bracket, falling back to the raw bracket key
/// for unknown values.
String rankBracketLabel(String bracket) => _bracketLabels[bracket] ?? bracket;

/// The rank bracket a percentile (0–100) falls into.
String rankBracketForPercentile(double percentile) {
  if (percentile >= 90) return 'b90_100';
  if (percentile >= 80) return 'b80_90';
  if (percentile >= 60) return 'b60_80';
  if (percentile >= 40) return 'b40_60';
  if (percentile >= 20) return 'b20_40';
  return 'b0_20';
}
