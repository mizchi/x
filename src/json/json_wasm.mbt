// wasm / wasm-gc implementation: a simdjson-driven parser.
//
// Stage 1 is `mizchi/simd/src/simdjson.find_structural_indices`, which on these
// targets uses inline-WAT v128 to locate every `{ } [ ] , :` that is outside a
// string literal. Stage 2 (below) is a recursive-descent walk over the raw
// UTF-8 bytes that uses that structural-index stream as its spine: every
// punctuation byte the walk consumes must line up with the next structural
// index, and all indices must be consumed by the end.
//
// The walk is strict — on anything it is not certain about (malformed input,
// lone surrogates, depth overflow, a punctuation/index mismatch, …) it raises
// `FastFail` and `parse` falls back to `moonbitlang/core/json`. That keeps the
// exact error positions/messages from the pure parser while letting valid
// documents take the SIMD structural-scan path.

///|
priv suberror FastFail

///|
// Reused stage-1 scratch. `mizchi/simd`'s allocating `find_structural_indices`
// does a `memory.grow` per call (hundreds of µs), so we keep the bitmap /
// index buffers around and only grow them, as its docs recommend for hot
// paths. Single-threaded wasm, so a module-level instance is safe.
priv struct Scratch {
  mut inbuf : @simd_buffer.SimdBufferBytes
  mut structural : @simd_buffer.SimdBuffer
  mut quote : @simd_buffer.SimdBuffer
  mut indices : @simd_buffer.SimdBuffer
  mut byte_len : Int
  mut word_cap : Int
  mut idx_cap : Int
}

///|
let scratch : Scratch = Scratch::{
  inbuf: @simd_buffer.SimdBufferBytes::make(1),
  structural: @simd_buffer.SimdBuffer::make(1),
  quote: @simd_buffer.SimdBuffer::make(1),
  indices: @simd_buffer.SimdBuffer::make(1),
  byte_len: 1,
  word_cap: 1,
  idx_cap: 1,
}

///|
fn is_digit(b : Int) -> Bool {
  b >= 0x30 && b <= 0x39
}

///|
fn hex_val(b : Int) -> Int {
  if b >= 0x30 && b <= 0x39 {
    b - 0x30
  } else if b >= 0x61 && b <= 0x66 {
    b - 0x61 + 10
  } else if b >= 0x41 && b <= 0x46 {
    b - 0x41 + 10
  } else {
    -1
  }
}

///|
priv struct Stage2 {
  buf : FixedArray[Byte]
  n : Int
  tok : FixedArray[Int]
  count : Int
  max_depth : Int
  mut tc : Int
}

///|
fn Stage2::byte(self : Stage2, i : Int) -> Int {
  self.buf[i].to_int()
}

///|
fn Stage2::skip_ws(self : Stage2, p : Int) -> Int {
  let mut i = p
  while i < self.n {
    let c = self.byte(i)
    if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
      i = i + 1
    } else {
      break
    }
  }
  i
}

///|
// Consume the structural token the SIMD stage expects at byte position `p`.
fn Stage2::expect_token(self : Stage2, p : Int) -> Unit raise FastFail {
  guard self.tc < self.count && self.tok[self.tc] == p else { raise FastFail }
  self.tc = self.tc + 1
}

///|
fn Stage2::read_hex4(self : Stage2, pos : Int) -> Int raise FastFail {
  guard pos + 3 < self.n else { raise FastFail }
  let mut v = 0
  for k in 0..<4 {
    let d = hex_val(self.byte(pos + k))
    guard d >= 0 else { raise FastFail }
    v = v * 16 + d
  }
  v
}

///|
// Decode one UTF-8 scalar starting at `i`; returns (codepoint, byte length).
fn Stage2::decode_utf8(self : Stage2, i : Int) -> (Int, Int) raise FastFail {
  let n = self.n
  let b0 = self.byte(i)
  fn cont(j : Int) -> Bool {
    j < n && self.byte(j) >= 0x80 && self.byte(j) < 0xC0
  }

  if b0 < 0xE0 {
    guard b0 >= 0xC2 && cont(i + 1) else { raise FastFail }
    (((b0 & 0x1F) << 6) | (self.byte(i + 1) & 0x3F), 2)
  } else if b0 < 0xF0 {
    guard cont(i + 1) && cont(i + 2) else { raise FastFail }
    (
      ((b0 & 0x0F) << 12) |
      ((self.byte(i + 1) & 0x3F) << 6) |
      (self.byte(i + 2) & 0x3F),
      3,
    )
  } else if b0 < 0xF5 {
    guard cont(i + 1) && cont(i + 2) && cont(i + 3) else { raise FastFail }
    (
      ((b0 & 0x07) << 18) |
      ((self.byte(i + 1) & 0x3F) << 12) |
      ((self.byte(i + 2) & 0x3F) << 6) |
      (self.byte(i + 3) & 0x3F),
      4,
    )
  } else {
    raise FastFail
  }
}

///|
// Parse a JSON string body (including the surrounding quotes); `start` is the
// opening quote. Returns (decoded text, index just past the closing quote).
fn Stage2::parse_string_raw(
  self : Stage2,
  start : Int,
) -> (String, Int) raise FastFail {
  let n = self.n
  let sb = StringBuilder::new()
  let mut i = start + 1
  while i < n {
    let c = self.byte(i)
    if c == 0x22 {
      return (sb.to_string(), i + 1)
    } else if c == 0x5C {
      guard i + 1 < n else { raise FastFail }
      let e = self.byte(i + 1)
      if e == 0x75 {
        let cu = self.read_hex4(i + 2)
        if cu >= 0xD800 && cu <= 0xDBFF {
          guard i + 7 < n &&
            self.byte(i + 6) == 0x5C &&
            self.byte(i + 7) == 0x75 else {
            raise FastFail
          }
          let lo = self.read_hex4(i + 8)
          guard lo >= 0xDC00 && lo <= 0xDFFF else { raise FastFail }
          let cp = 0x10000 + ((cu - 0xD800) << 10) + (lo - 0xDC00)
          sb.write_char(Char::from_int(cp))
          i = i + 12
        } else if cu >= 0xDC00 && cu <= 0xDFFF {
          raise FastFail
        } else {
          sb.write_char(Char::from_int(cu))
          i = i + 6
        }
      } else {
        let ch = match e {
          0x22 => '"'
          0x5C => '\\'
          0x2F => '/'
          0x62 => '\u{08}'
          0x66 => '\u{0C}'
          0x6E => '\n'
          0x72 => '\r'
          0x74 => '\t'
          _ => raise FastFail
        }
        sb.write_char(ch)
        i = i + 2
      }
    } else if c < 0x20 {
      raise FastFail
    } else if c < 0x80 {
      sb.write_char(Char::from_int(c))
      i = i + 1
    } else {
      let (cp, len) = self.decode_utf8(i)
      sb.write_char(Char::from_int(cp))
      i = i + len
    }
  }
  raise FastFail
}

///|
// Parse a JSON number per the strict grammar; returns (Json, end index).
fn Stage2::parse_number(
  self : Stage2,
  start : Int,
) -> (Json, Int) raise FastFail {
  let n = self.n
  let mut p = start
  if p < n && self.byte(p) == 0x2D {
    p = p + 1
  }
  guard p < n && is_digit(self.byte(p)) else { raise FastFail }
  if self.byte(p) == 0x30 {
    p = p + 1
  } else {
    while p < n && is_digit(self.byte(p)) {
      p = p + 1
    }
  }
  if p < n && self.byte(p) == 0x2E {
    p = p + 1
    guard p < n && is_digit(self.byte(p)) else { raise FastFail }
    while p < n && is_digit(self.byte(p)) {
      p = p + 1
    }
  }
  if p < n && (self.byte(p) == 0x65 || self.byte(p) == 0x45) {
    p = p + 1
    if p < n && (self.byte(p) == 0x2B || self.byte(p) == 0x2D) {
      p = p + 1
    }
    guard p < n && is_digit(self.byte(p)) else { raise FastFail }
    while p < n && is_digit(self.byte(p)) {
      p = p + 1
    }
  }
  let sb = StringBuilder::new()
  for i in start..<p {
    sb.write_char(Char::from_int(self.byte(i)))
  }
  let d = @strconv.parse_double(sb.to_string()) catch { _ => raise FastFail }
  (Json::number(d), p)
}

///|
fn Stage2::match_literal(
  self : Stage2,
  p : Int,
  lit : String,
  value : Json,
) -> (Json, Int) raise FastFail {
  let len = lit.length()
  guard p + len <= self.n else { raise FastFail }
  for k in 0..<len {
    guard self.byte(p + k) == lit.unsafe_get(k).to_int() else { raise FastFail }
  }
  (value, p + len)
}

///|
fn Stage2::parse_value(
  self : Stage2,
  p : Int,
  depth : Int,
) -> (Json, Int) raise FastFail {
  guard p < self.n else { raise FastFail }
  let c = self.byte(p)
  if c == 0x7B {
    self.parse_object(p, depth)
  } else if c == 0x5B {
    self.parse_array(p, depth)
  } else if c == 0x22 {
    let (s, e) = self.parse_string_raw(p)
    (Json::string(s), e)
  } else if c == 0x74 {
    self.match_literal(p, "true", Json::boolean(true))
  } else if c == 0x66 {
    self.match_literal(p, "false", Json::boolean(false))
  } else if c == 0x6E {
    self.match_literal(p, "null", Json::null())
  } else if c == 0x2D || is_digit(c) {
    self.parse_number(p)
  } else {
    raise FastFail
  }
}

///|
fn Stage2::parse_object(
  self : Stage2,
  open : Int,
  depth : Int,
) -> (Json, Int) raise FastFail {
  guard depth < self.max_depth else { raise FastFail }
  self.expect_token(open)
  let obj : Map[String, Json] = {}
  let mut p = self.skip_ws(open + 1)
  guard p < self.n else { raise FastFail }
  if self.byte(p) == 0x7D {
    self.expect_token(p)
    return (Json::object(obj), p + 1)
  }
  for ;; {
    guard p < self.n && self.byte(p) == 0x22 else { raise FastFail }
    let (key, p2) = self.parse_string_raw(p)
    p = self.skip_ws(p2)
    guard p < self.n && self.byte(p) == 0x3A else { raise FastFail }
    self.expect_token(p)
    let pv = self.skip_ws(p + 1)
    let (val, p3) = self.parse_value(pv, depth + 1)
    obj[key] = val
    p = self.skip_ws(p3)
    guard p < self.n else { raise FastFail }
    let d = self.byte(p)
    if d == 0x2C {
      self.expect_token(p)
      p = self.skip_ws(p + 1)
    } else if d == 0x7D {
      self.expect_token(p)
      return (Json::object(obj), p + 1)
    } else {
      raise FastFail
    }
  }
}

///|
fn Stage2::parse_array(
  self : Stage2,
  open : Int,
  depth : Int,
) -> (Json, Int) raise FastFail {
  guard depth < self.max_depth else { raise FastFail }
  self.expect_token(open)
  let arr : Array[Json] = []
  let mut p = self.skip_ws(open + 1)
  guard p < self.n else { raise FastFail }
  if self.byte(p) == 0x5D {
    self.expect_token(p)
    return (Json::array(arr), p + 1)
  }
  for ;; {
    let (val, p2) = self.parse_value(p, depth + 1)
    arr.push(val)
    p = self.skip_ws(p2)
    guard p < self.n else { raise FastFail }
    let d = self.byte(p)
    if d == 0x2C {
      self.expect_token(p)
      p = self.skip_ws(p + 1)
    } else if d == 0x5D {
      self.expect_token(p)
      return (Json::array(arr), p + 1)
    } else {
      raise FastFail
    }
  }
}

///|
// The simdjson fast path. Raises `FastFail` for anything it cannot parse
// cleanly, so the caller can fall back to the reference parser.
fn simd_parse(input : String, max_depth : Int) -> Json raise FastFail {
  let bytes = input.to_bytes()
  let n = bytes.length()
  guard n > 0 else { raise FastFail }
  let buf : FixedArray[Byte] = FixedArray::make(n, b'\x00')
  for i in 0..<n {
    buf[i] = bytes[i]
  }
  // Grow the reused scratch only when the current input needs more room.
  let words = (n + 31) / 32
  if scratch.byte_len != n {
    scratch.inbuf = @simd_buffer.SimdBufferBytes::make(n)
    scratch.byte_len = n
  }
  if scratch.word_cap < words {
    scratch.structural = @simd_buffer.SimdBuffer::make(words)
    scratch.quote = @simd_buffer.SimdBuffer::make(words)
    scratch.word_cap = words
  }
  if scratch.idx_cap < n {
    scratch.indices = @simd_buffer.SimdBuffer::make(n)
    scratch.idx_cap = n
  }
  let sbuf = scratch.inbuf
  sbuf.copy_from_array(buf)
  let indices = scratch.indices
  let count = @simdjson.find_structural_indices_with_scratch(
    sbuf,
    scratch.structural,
    scratch.quote,
    indices,
  )
  let tok : FixedArray[Int] = FixedArray::make(count, 0)
  for i in 0..<count {
    tok[i] = indices.get(i)
  }
  let st = Stage2::{ buf, n, tok, count, max_depth, tc: 0 }
  let start = st.skip_ws(0)
  guard start < n else { raise FastFail }
  let (json, e) = st.parse_value(start, 0)
  let after = st.skip_ws(e)
  guard after == n && st.tc == st.count else { raise FastFail }
  json
}

///|
/// Parses a JSON document into a `Json` value. `max_nesting_depth` defaults to
/// 1024, matching `moonbitlang/core/json`. Valid documents take the
/// simdjson-driven fast path; anything else falls back to the reference parser.
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  simd_parse(input.to_owned(), max_nesting_depth) catch {
    FastFail => fallback_parse(input, max_nesting_depth)
  }
}
