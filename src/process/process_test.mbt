///|
async test "run exit code 0" {
  let code = @process.run("node", ["-e", "process.exit(0)"])
  inspect(code, content="0")
}

///|
async test "run exit code 42" {
  let code = @process.run("node", ["-e", "process.exit(42)"])
  inspect(code, content="42")
}

///|
async test "collect_stdout" {
  let (code, stdout) = @process.collect_stdout("node", [
    "-e", "console.log('hello')",
  ])
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="hello")
}

///|
async test "collect_error" {
  let (code, stderr) = @process.collect_stderr("node", [
    "-e", "console.error('oops')",
  ])
  inspect(code, content="0")
  inspect(stderr.text().trim_end(), content="oops")
}

///|
async test "collect_output" {
  let (code, stdout, stderr) = @process.collect_output("node", [
    "-e", "console.log('out'); console.error('err')",
  ])
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="out")
  inspect(stderr.text().trim_end(), content="err")
}

///|
async test "collect_output_merged" {
  let (code, output) = @process.collect_output_merged("node", [
    "-e", "console.log('merged_out')",
  ])
  inspect(code, content="0")
  inspect(output.text().trim_end(), content="merged_out")
}

///|
async test "basic_ls" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "require('fs').readdirSync('.').sort().forEach(f=>console.log(f))"],
    cwd="/tmp",
  )
  inspect(code, content="0")
  inspect(stdout.text().length() > 0, content="true")
}

///|
async test "basic wait" {
  let code = @process.run("node", ["-e", "setTimeout(()=>process.exit(0),100)"])
  inspect(code, content="0")
}

///|
async test "wait exitcode" {
  let code = @process.run("node", ["-e", "process.exit(42)"])
  inspect(code, content="42")
}

///|
async test "set cwd" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "console.log(require('path').basename(process.cwd()))"],
    cwd="/tmp",
  )
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="tmp")
}

///|
async test "set_env" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "console.log(process.env.MAGIC_VAR)"],
    extra_env={ "MAGIC_VAR": "MAGIC_VALUE" },
  )
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="MAGIC_VALUE")
}

///|
async test "set_env no inherit" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    [
      "-e", "const e=process.env;const ks=Object.keys(e).filter(k=>k.startsWith('MAGIC_')).sort();ks.forEach(k=>console.log(k+'='+e[k]))",
    ],
    extra_env={ "MAGIC_VAR_1": "MAGIC_VALUE_1", "MAGIC_VAR_2": "MAGIC_VALUE_2" },
    inherit_env=false,
  )
  inspect(code, content="0")
  inspect(
    stdout.text().trim_end(),
    content="MAGIC_VAR_1=MAGIC_VALUE_1\nMAGIC_VAR_2=MAGIC_VALUE_2",
  )
}

///|
async test "redirect stdin and stdout files" {
  let input = "/tmp/mizchi_x_process_redirect_in.txt"
  let output = "/tmp/mizchi_x_process_redirect_out.txt"
  ignore(try? @fs.remove(input))
  ignore(try? @fs.remove(output))
  @fs.write_file(input, "redirected", create_mode=CreateOrTruncate)

  let code = @process.run(
    "node",
    ["-e", "process.stdin.pipe(process.stdout)"],
    stdin=@process.redirect_from_file(input),
    stdout=@process.redirect_to_file(output, create_mode=CreateOrTruncate),
  )
  inspect(code, content="0")
  inspect(@fs.read_file(output).text(), content="redirected")

  @fs.remove(input)
  @fs.remove(output)
}

///|
async test "write_to_process feeds stdin" {
  let (stdin, writer) = @process.write_to_process()
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @process.collect_stdout(
        "node",
        [
          "-e", "let s=''; process.stdin.on('data', c=>s+=c); process.stdin.on('end',()=>console.log(s.toUpperCase()))",
        ],
        stdin~,
      )
    })
    writer.write("abc")
    writer.close()
    let (code, stdout) = task.wait()
    inspect(code, content="0")
    inspect(stdout.text().trim_end(), content="ABC")
  })
}

///|
async test "spawn wait and try_wait" {
  @async.with_task_group(group => {
    let proc = @process.spawn(group, "node", [
      "-e", "setTimeout(()=>process.exit(7),100)",
    ])
    assert_true(proc.pid > 0)
    assert_true(proc.try_wait() is None)
    inspect(proc.wait(), content="7")
  })
}

///|
test "graceful_cancel accepts signal" {
  let handler = @process.graceful_cancel(timeout=5000, signal=@signal.SIGTERM)
  ignore(handler)
}
