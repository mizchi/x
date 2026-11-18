///|
async test "write and read file" {
  let path = "/tmp/mizchi_x_fs_test.txt"
  let content : String = "hello world"
  @fs.write_file(path, content)
  let data = @fs.read_file(path)
  assert_eq(data.text(), "hello world")
  @fs.remove(path)
}

///|
async test "exists" {
  let path = "/tmp/mizchi_x_fs_exist_test.txt"
  let content : String = "test"
  @fs.write_file(path, content)
  assert_true(@fs.exists(path))
  @fs.remove(path)
  assert_false(@fs.exists(path))
}

///|
async test "readdir" {
  let entries = @fs.readdir("/tmp")
  assert_true(entries.length() > 0)
}

///|
async test "mkdir" {
  let dir = "/tmp/mizchi_x_fs_mkdir_test"
  @fs.mkdir(dir, permission=0o755, recursive=true)
  assert_true(@fs.exists(dir))
  @fs.rmdir(dir)
}

///|
async test "rmdir refuses a regular file" {
  let path = "/tmp/mizchi_x_fs_rmdir_file_test"
  @fs.write_file(path, "keep")
  let result = try @fs.rmdir(path) catch {
    _ => false
  } noraise {
    _ => true
  }
  assert_false(result)
  assert_true(@fs.exists(path))
  @fs.remove(path)
}
