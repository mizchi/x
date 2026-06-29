///|
async fn rmdir_tree_if_exists(path : String) -> Unit {
  try @xfs.rmdir(path, recursive=true) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async test "watch detects created file" {
  let dir = "/tmp/mizchi_x_watch_create"
  rmdir_tree_if_exists(dir)
  @xfs.mkdir(dir, permission=0o755, recursive=true)
  let watcher = @fswatch.start([dir], interval_ms=50)
  let mut saw_create = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.write_file(dir + "/new.txt", "hello")
    })
    let events = watcher.next()
    for e in events {
      if e.path == dir + "/new.txt" && e.kind is Created {
        saw_create = true
      }
    }
  })
  watcher.close()
  assert_true(saw_create)
  @xfs.rmdir(dir, recursive=true)
}

///|
async test "watch detects modified file" {
  let dir = "/tmp/mizchi_x_watch_modify"
  rmdir_tree_if_exists(dir)
  @xfs.mkdir(dir, permission=0o755, recursive=true)
  let target = dir + "/data.txt"
  @xfs.write_file(target, "first")
  let watcher = @fswatch.start([dir], interval_ms=50)
  let mut saw_modify = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.write_file(target, "second-write-larger-payload")
    })
    let events = watcher.next()
    for e in events {
      if e.path == target && e.kind is Modified {
        saw_modify = true
      }
    }
  })
  watcher.close()
  assert_true(saw_modify)
  @xfs.rmdir(dir, recursive=true)
}

///|
async test "watch detects removed file" {
  let dir = "/tmp/mizchi_x_watch_remove"
  rmdir_tree_if_exists(dir)
  @xfs.mkdir(dir, permission=0o755, recursive=true)
  let target = dir + "/doomed.txt"
  @xfs.write_file(target, "bye")
  let watcher = @fswatch.start([dir], interval_ms=50)
  let mut saw_remove = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.remove(target)
    })
    let events = watcher.next()
    for e in events {
      if e.path == target && e.kind is Removed {
        saw_remove = true
      }
    }
  })
  watcher.close()
  assert_true(saw_remove)
  @xfs.rmdir(dir, recursive=true)
}

///|
async test "watch exclude prunes paths" {
  let dir = "/tmp/mizchi_x_watch_exclude"
  rmdir_tree_if_exists(dir)
  @xfs.mkdir(dir, permission=0o755, recursive=true)
  @xfs.mkdir(dir + "/keep", permission=0o755)
  @xfs.mkdir(dir + "/skip", permission=0o755)
  let watcher = @fswatch.start([dir], interval_ms=50, exclude=p => {
    p.contains("/skip")
  })
  let mut skip_leaked = false
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      @async.sleep(20)
      @xfs.write_file(dir + "/skip/ignored.txt", "x")
      @async.sleep(60)
      @xfs.write_file(dir + "/keep/seen.txt", "x")
    })
    let events = watcher.next()
    for e in events {
      if e.path.contains("/skip") {
        skip_leaked = true
      }
    }
  })
  watcher.close()
  assert_false(skip_leaked)
  @xfs.rmdir(dir, recursive=true)
}
