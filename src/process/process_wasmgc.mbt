///|
fn collect_output_internal(
  _cmd : StringView,
  _args : ArrayView[String],
  cwd? : StringView,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  ignore(cwd)
  abort("process is not supported on wasm-gc target")
}
