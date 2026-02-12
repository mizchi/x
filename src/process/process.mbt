///|
pub async fn run(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> Int {
  let (exit_code, _, _) = collect_output_internal(cmd, args, cwd?, extra_env~, inherit_env~)
  exit_code
}

///|
pub async fn collect_output(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  collect_output_internal(cmd, args, cwd?, extra_env~, inherit_env~)
}

///|
pub async fn collect_stdout(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data) {
  let (code, stdout, _) = collect_output_internal(cmd, args, cwd?, extra_env~, inherit_env~)
  (code, stdout)
}

///|
pub async fn collect_stderr(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data) {
  let (code, _, stderr) = collect_output_internal(cmd, args, cwd?, extra_env~, inherit_env~)
  (code, stderr)
}

///|
pub async fn collect_output_merged(
  cmd : StringView,
  args : Array[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data) {
  collect_output_merged_internal(cmd, args, cwd?, extra_env~, inherit_env~)
}
