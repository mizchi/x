// Native-only ports from `moonbitlang/core/json`.
//
// These assert an exact source position for an error that occurs where a JSON
// *value* is expected (a stray token, or a form-feed control char inside an
// array). The native delegate reports those positions exactly (it runs the
// pure-MoonBit parser), but the JS host `JSON.parse` phrases such failures as
// "Unexpected token X ... is not valid JSON" with no position, so the exact
// `{ line, column }` cannot be recovered on JS. The variant-level behavior is
// still covered cross-target in `json_upstream_test.mbt`.

///|
test "parse multi-lines json error" {
  let result = try? @json.parse(
    (
      #|{
      #|  "a":2,
      #|  "b":a
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 3, column: 6 }, 'a'))
    ),
  )
}

///|
test "parse error" {
  debug_inspect(
    try? @json.parse("[1, 2, ]"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 7 }, '\u{0c}'))
    ),
  )
}

///|
test "parse whitespace error" {
  debug_inspect(
    try? @json.parse("[1, 2,3   ,4  ]"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 9 }, '\u{0c}'))
    ),
  )
}
