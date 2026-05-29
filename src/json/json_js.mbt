// JS implementation: drive the host `JSON` through FFI and convert to/from the
// builtin `Json` value type, presenting the same surface as the native engine.

///|
#external
priv type JsValue

///|
priv struct JsParseResult {
  ok : Bool
  is_eof : Bool
  line : Int
  column : Int
  ch_code : Int
  value : JsValue
}

///|
// Parses `input` with the host `JSON.parse`. On failure the error message is
// scraped for a position so the same `ParseError` shape can be reported.
extern "js" fn js_parse(input : String) -> JsParseResult =
  #| (input) => {
  #|   try {
  #|     return { ok: true, is_eof: false, line: 0, column: 0, ch_code: -1, value: JSON.parse(input) };
  #|   } catch (err) {
  #|     const msg = String((err && err.message) || err);
  #|     if (/end of (JSON|data|input)/i.test(msg)) {
  #|       return { ok: false, is_eof: true, line: 0, column: 0, ch_code: -1, value: null };
  #|     }
  #|     let line = 1, column = 0, pos = -1;
  #|     const lc = msg.match(/line (\d+) column (\d+)/i);
  #|     if (lc) { line = lc[1] | 0; column = (lc[2] | 0) - 1; }
  #|     const pm = msg.match(/position (\d+)/i);
  #|     if (pm) pos = pm[1] | 0;
  #|     if (pos < 0 && lc) {
  #|       const lines = input.split('\n');
  #|       pos = 0;
  #|       for (let i = 0; i < line - 1 && i < lines.length; i++) pos += lines[i].length + 1;
  #|       pos += column;
  #|     } else if (pos >= 0 && !lc) {
  #|       line = 1; column = 0;
  #|       for (let i = 0; i < pos && i < input.length; i++) {
  #|         if (input[i] === '\n') { line++; column = 0; } else { column++; }
  #|       }
  #|     }
  #|     const ch_code = (pos >= 0 && pos < input.length) ? input.charCodeAt(pos) : -1;
  #|     return { ok: false, is_eof: false, line, column, ch_code, value: null };
  #|   }
  #| }

///|
extern "js" fn js_typeof(v : JsValue) -> Int =
  #| (v) => {
  #|   if (v === null || v === undefined) return 0;
  #|   const t = typeof v;
  #|   if (t === 'boolean') return 1;
  #|   if (t === 'number') return 2;
  #|   if (t === 'string') return 3;
  #|   if (Array.isArray(v)) return 4;
  #|   if (t === 'object') return 5;
  #|   return 0;
  #| }

///|
extern "js" fn js_to_bool(v : JsValue) -> Bool =
  #| (v) => v

///|
extern "js" fn js_to_number(v : JsValue) -> Double =
  #| (v) => v

///|
extern "js" fn js_to_string(v : JsValue) -> String =
  #| (v) => v

///|
extern "js" fn js_array_len(v : JsValue) -> Int =
  #| (v) => v.length | 0

///|
extern "js" fn js_array_get(v : JsValue, i : Int) -> JsValue =
  #| (v, i) => v[i]

///|
extern "js" fn js_object_keys(v : JsValue) -> Array[String] =
  #| (v) => Object.keys(v)

///|
extern "js" fn js_object_get(v : JsValue, k : String) -> JsValue =
  #| (v, k) => v[k]

///|
fn convert(v : JsValue, depth : Int, max_depth : Int) -> Json raise ParseError {
  match js_typeof(v) {
    1 => js_to_bool(v).to_json()
    2 => js_to_number(v).to_json()
    3 => js_to_string(v).to_json()
    4 => {
      guard depth < max_depth else { raise DepthLimitExceeded }
      let len = js_array_len(v)
      let arr : Array[Json] = []
      for i in 0..<len {
        arr.push(convert(js_array_get(v, i), depth + 1, max_depth))
      }
      arr.to_json()
    }
    5 => {
      guard depth < max_depth else { raise DepthLimitExceeded }
      let obj : Map[String, Json] = {}
      for k in js_object_keys(v) {
        obj[k] = convert(js_object_get(v, k), depth + 1, max_depth)
      }
      obj.to_json()
    }
    _ => Json::null()
  }
}

///|
/// Parses a JSON document into a `Json` value. `max_nesting_depth` defaults to
/// 1024, matching `moonbitlang/core/json`.
pub fn parse(
  input : StringView,
  max_nesting_depth? : Int = 1024,
) -> Json raise ParseError {
  let result = js_parse(input.to_owned())
  guard result.ok else {
    if result.is_eof {
      raise InvalidEof
    }
    let pos = { line: result.line, column: result.column }
    let c = if result.ch_code >= 0 {
      Char::from_int(result.ch_code)
    } else {
      ' '
    }
    raise InvalidChar(pos, c)
  }
  convert(result.value, 0, max_nesting_depth)
}

///|
/// Returns whether `input` is a well-formed JSON document.
pub fn valid(input : StringView) -> Bool {
  js_parse(input.to_owned()).ok
}

///|
extern "js" fn js_null() -> JsValue =
  #| () => null

///|
extern "js" fn js_bool(b : Bool) -> JsValue =
  #| (b) => b

///|
extern "js" fn js_number(n : Double) -> JsValue =
  #| (n) => n

///|
extern "js" fn js_str(s : String) -> JsValue =
  #| (s) => s

///|
extern "js" fn js_new_array() -> JsValue =
  #| () => []

///|
extern "js" fn js_array_push(a : JsValue, v : JsValue) -> Unit =
  #| (a, v) => { a.push(v); }

///|
extern "js" fn js_new_object() -> JsValue =
  #| () => ({})

///|
extern "js" fn js_object_set(o : JsValue, k : String, v : JsValue) -> Unit =
  #| (o, k, v) => { o[k] = v; }

///|
extern "js" fn js_stringify(v : JsValue, indent : Int) -> String =
  #| (v, indent) => JSON.stringify(v, null, indent > 0 ? indent : undefined)

///|
fn to_js(json : Json) -> JsValue {
  match json {
    Null => js_null()
    True => js_bool(true)
    False => js_bool(false)
    Number(n, ..) => js_number(n)
    String(s) => js_str(s)
    Array(arr) => {
      let a = js_new_array()
      for item in arr {
        js_array_push(a, to_js(item))
      }
      a
    }
    Object(obj) => {
      let o = js_new_object()
      for k, v in obj {
        js_object_set(o, k, to_js(v))
      }
      o
    }
  }
}

///|
/// Serializes a `Json` value. `escape_slash` (default false) escapes `/` as
/// `\/`; `indent` (default 0) pretty-prints with that many spaces per level.
pub fn stringify(
  json : Json,
  escape_slash? : Bool = false,
  indent? : Int = 0,
) -> String {
  let serialized = js_stringify(to_js(json), indent)
  if escape_slash {
    serialized.replace_all(old="/", new="\\/")
  } else {
    serialized
  }
}
