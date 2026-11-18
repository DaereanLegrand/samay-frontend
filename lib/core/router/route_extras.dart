import 'dart:convert';

/// Passthrough codec for go_router's typed `extra`.
///
/// The slim build navigates with plain route paths only (no typed payloads are
/// pushed), but the delegate still round-trips `state.extra` through a codec
/// whenever the auth state refreshes the router. Keeping an explicit identity
/// codec prevents that re-parse from nulling an extra on a screen that does
/// carry one.
class RouteExtraCodec extends Codec<Object?, Object?> {
  const RouteExtraCodec();

  @override
  Converter<Object?, Object?> get encoder => const _Identity();

  @override
  Converter<Object?, Object?> get decoder => const _Identity();
}

class _Identity extends Converter<Object?, Object?> {
  const _Identity();

  @override
  Object? convert(Object? input) => input;
}
