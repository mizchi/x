// Cross-platform JSON.
//
// Mirrors the `parse` / `valid` / `stringify` surface of
// `moonbitlang/core/json`, reusing the builtin `Json` value type. On native,
// wasm and wasm-gc the pure-MoonBit parser/serializer is delegated to. On the
// JS target the host `JSON.parse` / `JSON.stringify` are driven through FFI and
// the result is converted to/from the builtin `Json`, so the same code behaves
// identically on every target.

///|
/// A position in the source text. `line` is 1-based, `column` is 0-based, the
/// same convention as `moonbitlang/core/json.Position`.
pub(all) struct Position {
  line : Int
  column : Int
} derive(Eq)

///|
pub impl Show for Position with fn output(self, logger) {
  logger.write_string("Position(line=")
  logger.write_object(self.line)
  logger.write_string(", column=")
  logger.write_object(self.column)
  logger.write_string(")")
}

///|
/// Parsing error raised by `parse`.
///
/// Same variants as `moonbitlang/core/json.ParseError`. The JS backend can only
/// report what the host parser exposes, so it produces `InvalidChar` (with the
/// reported position and offending character when recoverable) or `InvalidEof`
/// for premature end of input.
pub(all) suberror ParseError {
  InvalidChar(Position, Char)
  InvalidEof
  InvalidNumber(Position, String)
  InvalidIdentEscape(Position)
  DepthLimitExceeded
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    InvalidChar(pos, c) => {
      logger.write_string("InvalidChar(")
      logger.write_object(pos)
      logger.write_string(", ")
      logger.write_object(c)
      logger.write_string(")")
    }
    InvalidEof => logger.write_string("InvalidEof")
    InvalidNumber(pos, s) => {
      logger.write_string("InvalidNumber(")
      logger.write_object(pos)
      logger.write_string(", ")
      logger.write_object(s)
      logger.write_string(")")
    }
    InvalidIdentEscape(pos) => {
      logger.write_string("InvalidIdentEscape(")
      logger.write_object(pos)
      logger.write_string(")")
    }
    DepthLimitExceeded => logger.write_string("DepthLimitExceeded")
  }
}
