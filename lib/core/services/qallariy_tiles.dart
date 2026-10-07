import 'package:samay/shared/services/retry_vector_tile_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// Qallariy vector basemap: Protomaps PMTiles served by Martin and fronted by
/// the token-gated Caddy gateway (`tools/<ops-tooling>` in <private-ops-repo>).
const String kQallariyTileUrl =
    'https://tiles.qallariy.lat/20260603/{z}/{x}/{y}.mvt';

/// Shared tiles token, injected at build time:
///   `--dart-define=TILES_TOKEN=...`
///
/// It is an anti-hotlink guard, not a secret: Cloudflare's cache key ignores
/// request headers, so edge-cached tiles are public anyway. Never hardcode it;
/// supply it via `.env` (local) or the release/CI dart-defines.
const String kQallariyTileToken =
    String.fromEnvironment('TILES_TOKEN', defaultValue: '');

/// Headers for every Qallariy tile request. Empty when the token is unset so a
/// tokenless build still attempts the request (and fails loudly at the gateway)
/// rather than sending a blank header.
Map<String, String> qallariyTileHeaders() => kQallariyTileToken.isEmpty
    ? const <String, String>{}
    : <String, String>{'X-Tiles-Token': kQallariyTileToken};

/// The standard Qallariy tile provider: retrying wrapper + token header.
RetryVectorTileProvider qallariyTileProvider({int maximumZoom = 15}) =>
    RetryVectorTileProvider(
      delegate: NetworkVectorTileProvider(
        urlTemplate: kQallariyTileUrl,
        maximumZoom: maximumZoom,
        httpHeaders: qallariyTileHeaders(),
      ),
    );
