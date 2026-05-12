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
async test "collect_output blocked" {
  let script = "const chunk=Buffer.alloc(1024);let i=0;function write(){while(i<1024){i++;if(!process.stderr.write(chunk)){process.stderr.once('drain',write);return}}}write()"
  let result = try? @async.with_timeout(3000, () => {
    let (code, stdout, stderr) = @process.collect_output("node", ["-e", script])
    inspect(code, content="0")
    inspect(stdout.text(), content="")
    inspect(stderr.binary().length(), content="1048576")
  })
  assert_true(result is Ok(_))
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
async test "basic_cat" {
  @async.with_task_group(group => {
    let (cat_read, we_write) = @process.write_to_process()
    let (we_read, cat_write) = @process.read_from_process()
    @process.spawn(
      group,
      "node",
      ["-e", "process.stdin.pipe(process.stdout)"],
      stdin=cat_read,
      stdout=cat_write,
    )
    |> ignore
    group.spawn_bg(() => {
      defer we_write.close()
      we_write.write("abcd")
      @async.sleep(50)
      we_write.write("efgh")
    })
    group.spawn_bg(() => {
      defer we_read.close()
      inspect(we_read.read_all().text(), content="abcdefgh")
    })
  })
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
async test "redirect to file" {
  let input = "/tmp/mizchi_x_process_redirect_exact_in.txt"
  let output = "/tmp/mizchi_x_process_redirect_exact_out.txt"
  ignore(try? @fs.remove(input))
  ignore(try? @fs.remove(output))
  @fs.write_file(input, "abcd", create_mode=CreateOrTruncate)

  let code = @process.run(
    "node",
    ["-e", "process.stdin.pipe(process.stdout)"],
    stdin=@process.redirect_from_file(input),
    stdout=@process.redirect_to_file(output, create_mode=CreateOrTruncate),
  )
  inspect(code, content="0")
  inspect(@fs.read_file(output).text(), content="abcd")

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
async test "merge multiple" {
  let output = "/tmp/mizchi_x_process_merge_multiple.txt"
  ignore(try? @fs.remove(output))
  @async.with_task_group(group => {
    @process.spawn(
      group,
      "node",
      ["-e", "setTimeout(()=>console.log('abcd'),20)"],
      stdout=@process.redirect_to_file(
        output,
        append=true,
        create_mode=CreateOrTruncate,
      ),
    )
    |> ignore
    @process.spawn(
      group,
      "node",
      ["-e", "setTimeout(()=>console.log('efgh'),100)"],
      stdout=@process.redirect_to_file(
        output,
        append=true,
        create_mode=OpenOrCreate,
      ),
    )
    |> ignore
  })
  @async.sleep(50)
  inspect(@fs.read_file(output).text(), content="abcd\nefgh\n")
  @fs.remove(output)
}

///|
async test "merge stdout and stderr" {
  @async.with_task_group(group => {
    let (r, w) = @process.read_from_process()
    defer r.close()
    @process.spawn(
      group,
      "node",
      ["-e", "process.stdout.write('abcd');process.stderr.write('efgh')"],
      stdout=w,
      stderr=w,
    )
    |> ignore
    let output = r.read_all().text()
    assert_true(output.contains("abcd"))
    assert_true(output.contains("efgh"))
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
async test "spawn_in_group wait" {
  let t0 = @async.now()
  @async.with_task_group(group => {
    @process.spawn(group, "node", ["-e", "setTimeout(()=>process.exit(0),220)"])
    |> ignore
    @async.sleep(60)
  })
  let elapsed = @async.now() - t0
  assert_true(elapsed >= 180)
}

///|
async test "spawn_in_group cancel" {
  let marker = "/tmp/mizchi_x_process_spawn_group_cancel.txt"
  ignore(try? @fs.remove(marker))
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});setInterval(()=>{},1000)"
  @async.with_task_group(group => {
    @process.spawn(group, "node", ["-e", script, marker], no_wait=true)
    |> ignore
    @async.sleep(80)
  })
  @async.sleep(150)
  inspect(@fs.read_file(marker).text(), content="term")
  @fs.remove(marker)
}

///|
async test "Process::wait" {
  @async.with_task_group(group => {
    let child = @process.spawn(group, "node", [
      "-e", "setTimeout(()=>process.exit(42),100)",
    ])
    inspect(child.wait(), content="42")
    inspect(child.wait(), content="42")
  })
}

///|
async test "Process::try_wait" {
  @async.with_task_group(group => {
    let child = @process.spawn(group, "node", [
      "-e", "setTimeout(()=>process.exit(42),150)",
    ])
    @async.sleep(50)
    debug_inspect(child.try_wait(), content="None")
    @async.sleep(180)
    debug_inspect(child.try_wait(), content="Some(42)")
  })
}

///|
async test "Process:cancel" {
  let marker = "/tmp/mizchi_x_process_method_cancel.txt"
  ignore(try? @fs.remove(marker))
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});setInterval(()=>{},1000)"
  @async.with_task_group(group => {
    let child = @process.spawn(group, "node", ["-e", script, marker])
    @async.sleep(80)
    child.cancel()
  })
  @async.sleep(100)
  inspect(@fs.read_file(marker).text(), content="term")
  @fs.remove(marker)
}

///|
async test "wait_pid" {
  let pid = @process.spawn_orphan("node", [
    "-e", "setTimeout(()=>process.exit(7),50)",
  ])
  assert_true(pid > 0)
  inspect(@process.wait_pid(pid), content="7")
}

///|
async test "orphan process" {
  let marker = "/tmp/mizchi_x_process_orphan.txt"
  ignore(try? @fs.remove(marker))
  let script = "const fs=require('fs');fs.writeFileSync(process.argv[1],'first');setTimeout(()=>{fs.writeFileSync(process.argv[1],'second');process.exit(0)},180)"
  let pid = @process.spawn_orphan("node", ["-e", script, marker])
  let result = try? @async.with_timeout(70, () => @process.wait_pid(pid))
  assert_true(result is Err(_))
  @async.sleep(220)
  inspect(@fs.read_file(marker).text(), content="second")
  ignore(try? @async.with_timeout(500, () => @process.wait_pid(pid)))
  @fs.remove(marker)
}

///|
async test "cancel process" {
  let marker = "/tmp/mizchi_x_process_cancel_signal.txt"
  ignore(try? @fs.remove(marker))
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});setInterval(()=>{},1000)"
  let result = try? @async.with_timeout(120, () => {
    @process.run(
      "node",
      ["-e", script, marker],
      cancel_handler=@process.graceful_cancel(
        timeout=200,
        signal=@signal.SIGTERM,
      ),
    )
  })
  assert_true(result is Err(_))
  @async.sleep(120)
  inspect(@fs.read_file(marker).text(), content="term")
  @fs.remove(marker)
}

///|
async test "cancel process timeout" {
  let marker = "/tmp/mizchi_x_process_cancel_timeout_signal.txt"
  ignore(try? @fs.remove(marker))
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term')});setInterval(()=>{},1000)"
  let t0 = @async.now()
  let result = try? @async.with_timeout(80, () => {
    @process.run(
      "node",
      ["-e", script, marker],
      cancel_handler=@process.graceful_cancel(
        timeout=140,
        signal=@signal.SIGTERM,
      ),
    )
  })
  let elapsed = @async.now() - t0
  assert_true(result is Err(_))
  assert_true(elapsed >= 160)
  inspect(@fs.read_file(marker).text(), content="term")
  @fs.remove(marker)
}

///|
async test "cancel process hard" {
  let marker = "/tmp/mizchi_x_process_hard_cancel_signal.txt"
  ignore(try? @fs.remove(marker))
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});setInterval(()=>{},1000)"
  let result = try? @async.with_timeout(120, () => {
    @process.run(
      "node",
      ["-e", script, marker],
      cancel_handler=@process.hard_cancel(),
    )
  })
  assert_true(result is Err(_))
  @async.sleep(120)
  assert_false(@fs.exists(marker))
}

///|
async test "do not kill orphan children on hard cancel" {
  let marker = "/tmp/mizchi_x_process_orphan_child.txt"
  ignore(try? @fs.remove(marker))
  let child_script = "const fs=require('fs');setTimeout(()=>{fs.writeFileSync(process.argv[1],'after sleep');process.exit(0)},180)"
  let parent_script = "const {spawn}=require('node:child_process');const child=spawn(process.execPath,['-e',process.argv[1],process.argv[2]],{detached:true,stdio:'ignore'});child.unref();setInterval(()=>{},1000)"
  let result = try? @async.with_timeout(80, () => {
    @process.run(
      "node",
      ["-e", parent_script, child_script, marker],
      cancel_handler=@process.hard_cancel(),
    )
  })
  assert_true(result is Err(_))
  @async.sleep(260)
  inspect(@fs.read_file(marker).text(), content="after sleep")
  @fs.remove(marker)
}

///|
test "graceful_cancel accepts signal" {
  let handler = @process.graceful_cancel(timeout=5000, signal=@signal.SIGTERM)
  ignore(handler)
}
