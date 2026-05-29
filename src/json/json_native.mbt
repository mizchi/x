// Native implementation: delegate to `moonbitlang/core/json`.
//
// simdjson's native path is a scalar fallback (SIMD only kicks in on
// wasm / wasm-gc), so there is nothing to gain from routing native parsing
// through it — `moonbitlang/core/json`'s tuned scalar parser is the better
// choice here.

///|
/// Parses a JSON document into a `Json` value. `max_nesting_depth` defaults to
/// 1024, matching `moonbitlang/core/json`.
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  fallback_parse(input, max_nesting_depth)
}
