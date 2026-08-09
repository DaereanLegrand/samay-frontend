/// Rank-bracket policy (I-46, TST-06/M-13).
///
/// [rankBracketForPercentile] mirrors the `recalculate_ranks` SQL CASE
/// (`supabase/migrations/20260520000001_admin_rpc_and_rls.sql:187`):
/// ≥90 → b90_100, ≥80 → b80_90, ≥60 → b60_80, ≥40 → b40_60, ≥20 → b20_40,
/// else b0_20.
///
/// Labels are Spanish constants by design (BuildContext-free, same rationale
/// as error strings in `lib/core/errors/**` — M-15); the app is es-first and
/// [RankBadge] renders them uppercased. They are allowlisted in
/// `test/l10n/l10n_extraction_test.dart`.
const _bracketLabels = <String, String>{
  'b90_100': 'Full Vibe',
  'b80_90': 'Leyendas de la Vibra',
  'b60_80': 'Creadores de la Vibra',
  'b40_60': 'Seguidores de la Vibra',
  'b20_40': 'Buscadores de la Vibra',
  'b0_20': 'En la Búsqueda',
};

/// The display label for a rank bracket, falling back to the raw bracket key
/// for unknown values (previously the inline switch in `RankBadge`).
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
