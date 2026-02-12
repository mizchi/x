///|
pub async fn run(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
) -> Int {
  let (exit_code, _, _) = collect_output_internal(cmd, args, cwd?)
  exit_code
}

///|
pub async fn collect_output(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  collect_output_internal(cmd, args, cwd?)
}
