///|
async test "directory notifications reconcile file membership" {
  let dir = @xfs.tmpdir(prefix="mizchi_x_watch_directory")
  defer @async.protect_from_cancel(() => @xfs.rmdir(dir, recursive=true))
  @xfs.write_file(dir + "/keep.txt", "keep")
  @xfs.write_file(dir + "/old.txt", "old")
  let state = build_normalize_state([dir], path => path.contains("/skip"))
  @xfs.remove(dir + "/old.txt")
  @xfs.write_file(dir + "/new.txt", "new")
  @xfs.write_file(dir + "/skip.txt", "ignored")
  let events = classify_directory_changes(state, dir)
  assert_eq(events.length(), 2)
  assert_true(
    events.any(event => event.path == dir + "/new.txt" && event.kind is Created),
  )
  assert_true(
    events.any(event => event.path == dir + "/old.txt" && event.kind is Removed),
  )
  assert_true(state.known.contains(dir + "/new.txt"))
  assert_true(state.known.contains(dir + "/keep.txt"))
  assert_false(state.known.contains(dir + "/old.txt"))
  assert_false(state.known.contains(dir + "/skip.txt"))
}
