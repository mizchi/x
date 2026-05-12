///|
async test "encode decode roundtrip" {
  @async.with_task_group(root => {
    let (compressed_r, compressed_w) = @io.pipe()
    root.spawn_bg(() => {
      defer compressed_w.close()
      let encoder = @gzip.Encoder(
        compressed_w,
        mtime=123456789U,
        operating_system=b'\x03',
      )
      encoder.write("hello ")
      encoder.write("gzip ")
      encoder.write("world")
      encoder.end()
    })

    let decoder = @gzip.Decoder(compressed_r)
    inspect(decoder.read_all().text(), content="hello gzip world")
    compressed_r.close()
  })
}

///|
async test "encoder flush emits chunks" {
  let log : Array[String] = []
  @async.with_task_group(root => {
    let (compressed_r, compressed_w) = @io.pipe()
    root.spawn_bg(() => {
      defer compressed_w.close()
      let encoder = @gzip.Encoder(compressed_w)
      encoder.write("ab")
      encoder.flush()
      @async.sleep(60)
      encoder.write("cd")
      encoder.flush()
      @async.sleep(60)
      encoder.end()
    })
    root.spawn_bg(() => {
      defer compressed_r.close()
      while compressed_r.read_some() is Some(chunk) {
        log.push("chunk \{chunk.length()}")
      }
    })
  })
  inspect(log.length() >= 3, content="true")
}

///|
async test "large payload roundtrip" {
  @async.with_task_group(root => {
    let payload = Bytes::makei(70000, i => (i % 251).to_byte())
    let (compressed_r, compressed_w) = @io.pipe()
    root.spawn_bg(() => {
      defer compressed_w.close()
      let encoder = @gzip.Encoder(compressed_w)
      encoder.write(payload)
      encoder.end()
    })

    let decoder = @gzip.Decoder(compressed_r)
    inspect(decoder.read_all().binary() == payload, content="true")
    compressed_r.close()
  })
}
