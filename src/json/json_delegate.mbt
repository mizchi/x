// Shared non-JS surface (native / wasm / wasm-gc).
//
// `valid` and `stringify` delegate to the pure-MoonBit `moonbitlang/core/json`
// on every non-JS target (simdjson has no serializer, and its native path is
// scalar). `fallback_parse` is the exact-error source of truth: the native
// `parse` delegates straight to it, and the wasm/wasm-gc `parse` falls back to
// it whenever the simdjson fast path bails, so error positions/messages stay
// identical to `moonbitlang/core/json`.

///|
fn map_position(p : @upstream.Position) -> Position {
  { line: p.line, column: p.column }
}

///|
fn map_parse_error(e : @upstream.ParseError) -> ParseError {
  match e {
    InvalidChar(pos, c) => InvalidChar(map_position(pos), c)
    InvalidEof => InvalidEof
    InvalidNumber(pos, s) => InvalidNumber(map_position(pos), s)
    InvalidIdentEscape(pos) => InvalidIdentEscape(map_position(pos))
    DepthLimitExceeded => DepthLimitExceeded
  }
}

///|
/// Parses via `moonbitlang/core/json`, translating its error type to ours.
fn fallback_parse(
  input : StringView,
  max_nesting_depth : Int,
) -> Json raise ParseError {
  @upstream.parse(input, max_nesting_depth~) catch {
    e => raise map_parse_error(e)
  }
}

///|
/// Returns whether `input` is a well-formed JSON document.
pub fn valid(input : StringView) -> Bool {
  @upstream.valid(input)
}

///|
/// Serializes a `Json` value. `escape_slash` (default false) escapes `/` as
/// `\/`; `indent` (default 0) pretty-prints with that many spaces per level.
pub fn stringify(
  json : Json,
  escape_slash? : Bool = false,
  indent? : Int = 0,
) -> String {
  json.stringify(escape_slash~, indent~)
}
