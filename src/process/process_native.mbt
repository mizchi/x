///|
async fn collect_output_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  @async_process.collect_output(cmd, args, cwd?)
}
