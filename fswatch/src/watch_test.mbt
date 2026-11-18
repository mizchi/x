///|
async fn rmdir_tree_if_exists(path : String) -> Unit {
  try @xfs.rmdir(path, recursive=true) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async fn wait_for_event(
  watcher : @fswatch.Watcher,
  path : String,
  kind : @fswatch.EventKind,
) -> Array[@fswatch.Event] {
  @async.with_timeout(5000, () => {
    let observed : Array[@fswatch.Event] = []
    for ;; {
      let events = watcher.next()
      observed.append(events)
      if events.any(event => event.path == path && event.kind == kind) {
        break observed
      }
    }
  }) catch {
    @async.TimeoutError => fail("Timed out waiting for \{kind} at \{path}")
    err => raise err
  }
}

///|
// Observe a fixture event before testing mutations: macOS may coalesce the
// fixture's creation and an immediate removal into the same notification batch.
async fn ready_watcher(watcher : @fswatch.Watcher, dir : String) -> Unit {
  let marker = dir + "/watch-ready.txt"
  @xfs.write_file(marker, "ready")
  ignore(wait_for_event(watcher, marker, @fswatch.Created))
}

///|
async test "watch detects created file" {
  let dir = @xfs.tmpdir(prefix="mizchi_x_watch_create")
  defer @async.protect_from_cancel(() => rmdir_tree_if_exists(dir))
  let watcher = @fswatch.start([dir], interval_ms=50)
  defer watcher.close()
  ready_watcher(watcher, dir)
  let mut saw_create = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.write_file(dir + "/new.txt", "hello")
    })
    let events = wait_for_event(watcher, dir + "/new.txt", @fswatch.Created)
    for e in events {
      if e.path == dir + "/new.txt" && e.kind is Created {
        saw_create = true
      }
    }
  })
  watcher.close()
  assert_true(saw_create)
}

///|
async test "watch detects modified file" {
  let dir = @xfs.tmpdir(prefix="mizchi_x_watch_modify")
  defer @async.protect_from_cancel(() => rmdir_tree_if_exists(dir))
  let target = dir + "/data.txt"
  @xfs.write_file(target, "first")
  // Separate fixture creation from the mutation in the macOS event stream.
  @async.sleep(250)
  let watcher = @fswatch.start([dir], interval_ms=50)
  defer watcher.close()
  ready_watcher(watcher, dir)
  let mut saw_modify = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.write_file(target, "second-write-larger-payload")
    })
    let events = wait_for_event(watcher, target, @fswatch.Modified)
    for e in events {
      if e.path == target && e.kind is Modified {
        saw_modify = true
      }
    }
  })
  watcher.close()
  assert_true(saw_modify)
}

///|
async test "watch detects removed file" {
  let dir = @xfs.tmpdir(prefix="mizchi_x_watch_remove")
  defer @async.protect_from_cancel(() => rmdir_tree_if_exists(dir))
  let target = dir + "/doomed.txt"
  @xfs.write_file(target, "bye")
  // Separate fixture creation from the mutation in the macOS event stream.
  @async.sleep(250)
  let watcher = @fswatch.start([dir], interval_ms=50)
  defer watcher.close()
  ready_watcher(watcher, dir)
  let mut saw_remove = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.remove(target)
    })
    let events = wait_for_event(watcher, target, @fswatch.Removed)
    for e in events {
      if e.path == target && e.kind is Removed {
        saw_remove = true
      }
    }
  })
  watcher.close()
  assert_true(saw_remove)
}

///|
async test "watch exclude prunes paths" {
  let dir = @xfs.tmpdir(prefix="mizchi_x_watch_exclude")
  defer @async.protect_from_cancel(() => rmdir_tree_if_exists(dir))
  @xfs.mkdir(dir + "/keep", permission=0o755)
  @xfs.mkdir(dir + "/skip", permission=0o755)
  let watcher = @fswatch.start([dir], interval_ms=50, exclude=p => {
    p.contains("/skip")
  })
  defer watcher.close()
  ready_watcher(watcher, dir + "/keep")
  let mut skip_leaked = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.write_file(dir + "/skip/ignored.txt", "x")
      @async.sleep(60)
      @xfs.write_file(dir + "/keep/seen.txt", "x")
    })
    let events = wait_for_event(
      watcher,
      dir + "/keep/seen.txt",
      @fswatch.Created,
    )
    for e in events {
      if e.path.contains("/skip") {
        skip_leaked = true
      }
    }
  })
  watcher.close()
  assert_false(skip_leaked)
}
