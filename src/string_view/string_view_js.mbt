///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_find(target : StringView, needle : StringView) -> Int = "stringViewFind"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_rev_find(target : StringView, needle : StringView) -> Int = "stringViewRevFind"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_find_code_unit(target : StringView, needle : UInt16) -> Int = "stringViewFindCodeUnit"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_rev_find_code_unit(
  target : StringView,
  needle : UInt16,
) -> Int = "stringViewRevFindCodeUnit"

///|
#module("@mizchi/jsimd-moonbit-interop/string-view")
extern "js" fn js_compare(left : StringView, right : StringView) -> Int = "stringViewCompare"

///|
fn found(index : Int) -> Int? {
  if index < 0 {
    None
  } else {
    Some(index)
  }
}

///|
pub fn find(target : StringView, needle : StringView) -> Int? {
  found(js_find(target, needle))
}

///|
pub fn rev_find(target : StringView, needle : StringView) -> Int? {
  found(js_rev_find(target, needle))
}

///|
pub fn find_code_unit(target : StringView, needle : UInt16) -> Int? {
  found(js_find_code_unit(target, needle))
}

///|
pub fn rev_find_code_unit(target : StringView, needle : UInt16) -> Int? {
  found(js_rev_find_code_unit(target, needle))
}

///|
pub fn compare(left : StringView, right : StringView) -> Int {
  js_compare(left, right)
}
