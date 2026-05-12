///|
let key_pem =
  #|-----BEGIN PRIVATE KEY-----
  #|MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDGGuA46vHS2I9u
  #|v5/N6yiyarjUGPm1/cxwWBobxB9IFcn8fXu41C5YmKh7cvRrAreiXf1NeXMNm6rC
  #|9M7JH51V9XqPCIDnJB/mZ6qhQjj7YniNWvUcNqpIHg55cbWkMSttPvub7zYJ3Vbk
  #|mah46la1N5OieCiU974YPuHqZ0qbOCEw3/+5kQQZlYuXEKUz/dLlovYluvUusl2p
  #|Oj3qUaeWfMs8slammPx3OzfoercDyETDNmyJvSXMHmtbJYSCBa5AFZZMtAcw8gWH
  #|PRw5hZy+C7GgCC+26tGKiFuReE6ge6feJ/KOYQMv5zkXH4tmM20hauwGWBY7X86Z
  #|anzARiyhAgMBAAECggEAB7t40P/qnG4zewEjvafWGNCtkim/ZWkYl7H4oujOx8OB
  #|9Mb5E0fE31RmDxt3is26WS4N+v4ojXlr+twPTi5bt8UzGW4diegRDq8xK8Yn7zfy
  #|uKG6O3Wuw83Yhsj3bAc3SLZSn82AcHYhNB8DQmTzKXOX4ZmLC/V3h/68Vqfdc511
  #|pekoNszwRe6mgEIvsmG2+7yaOmhC4GrIVsOeTQJvVCHTtHOOsChoLq9b1yC7/YXa
  #|ReUN+ta9otOgeq2tqgF+saCXIiwZwHGexXegm0jRjJHVWDymQTlpLLxHQmZzwEUe
  #|tRRnTLiF8vx+yrxmxTNGigMMk8CYNN0eLl253faz2QKBgQDqpzSDw0z7jI8XmdvP
  #|dPsAXy6tQgKUbWVBL6j/4bcqpaGtGNph1WSb49naDl2nRdSVBkXrKiRIGwakGDQe
  #|TtuTr+oJW9TjulK0SUif16+dSRYR2IQbUf3p6loaixwCpTOJBW9QCBE9FD0OpC10
  #|8jlBpcPZ+PDjKhHDFgBf/yQHIwKBgQDYIIHW1lNWhlPeyBieC7rUYaq7E+iv8vle
  #|xaGMbpwOMpd7L1OJ9lL3laDDe5ULHNd8H3vTpfrlJA5ww212PnUXpg8NXW7bwL44
  #|UFRadujt54K+MjMq0wt9ILxdlEzen7kcbLnMPqxhFAOobJ8SfWFGxo1kPIXT2O2q
  #|SfqaFVebawKBgQDR+CpqmRDCqqTEFp31RhTv4TvwNvf9/uGy8cXEqiHvnGROcsW+
  #|82big4FFuMMe0cKGUyWvZ3ctulk37px8Xk3nGmtOUojt+aTVxBmjRinTkTmZYGfd
  #|1oFhlZ1o0P+Qcmjp/B39vCpIwFpeRpSSZ8jKMF1PJ43Nh7B7I63UOIbxhwKBgCpi
  #|7bPporyEaax2h8VvPXvrj6VS+T6Qo3F/xvgYtUhfia/iDzsucQUXdkkAUrG0PVqd
  #|fhZ7JeKMmLxqx2v6QdKagbc4TMaSXXwD3RdE3NfToKOWisxqSYWHxwl/TTgYESDO
  #|/f1diUccur7sVqI0rsBHrnErIX/zumC8U4amiuDzAoGAPfeWcT+jfuAJuq9V++5b
  #|9b47IDnxWIzNvr/CWoIcmnz+HEJCX0xxpCjjzG4tbHgVQbXmDPpzPsXIsciavuZT
  #|CxzvJqtmwKhF9Q0mvfb9DHWCqyqEWu+k8UlgMOK3FOcPboaTwHTGdB66ufXexZxV
  #|yDifBJsJWuekwVcfe9tvsow=
  #|-----END PRIVATE KEY-----

///|
let cert_pem =
  #|-----BEGIN CERTIFICATE-----
  #|MIICpDCCAYwCCQDY75kUA6AxsTANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
  #|b2NhbGhvc3QwHhcNMjYwNTEyMTIzMjQ1WhcNMjcwNTEyMTIzMjQ1WjAUMRIwEAYD
  #|VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDG
  #|GuA46vHS2I9uv5/N6yiyarjUGPm1/cxwWBobxB9IFcn8fXu41C5YmKh7cvRrArei
  #|Xf1NeXMNm6rC9M7JH51V9XqPCIDnJB/mZ6qhQjj7YniNWvUcNqpIHg55cbWkMStt
  #|Pvub7zYJ3Vbkmah46la1N5OieCiU974YPuHqZ0qbOCEw3/+5kQQZlYuXEKUz/dLl
  #|ovYluvUusl2pOj3qUaeWfMs8slammPx3OzfoercDyETDNmyJvSXMHmtbJYSCBa5A
  #|FZZMtAcw8gWHPRw5hZy+C7GgCC+26tGKiFuReE6ge6feJ/KOYQMv5zkXH4tmM20h
  #|auwGWBY7X86ZanzARiyhAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAKzPXMrQrdYj
  #|2ziE6hzDy5+p9xuZYC7kso1lOYsPqtylBBrQtNkIwe0+1FIUHB5Jg9c6hpD+Ta+Q
  #|Q5LFTUXsaSAYSNcKRi4+yA2sCllyT0b4temgsjG/1145ZTmezWH5zPuWNmOWGgRa
  #|No+B2SFH4uKZF8Em4XwlK9xWJar9udAUbptZO2WJNmN0Pd7siP+Cm5iJTprIwegw
  #|hLCu6HeRobP4ATdu4MIKK2OQwEZBrCOGP2UV8HSqzTwGdjv6qqxB2g3yqo/WouZi
  #|5H7UHRztzdIjLhTRK2zX4O+0f4x6SENtTu8JYyxxbeCNEKUF9nbLEzTs93RU5cR9
  #|ABeu8O5K8jo=
  #|-----END CERTIFICATE-----

///|
async fn write_test_keys() -> (String, String) {
  let key = "/tmp/mizchi_x_tls_key.pem"
  let cert = "/tmp/mizchi_x_tls_cert.pem"
  @fs.write_file(key, key_pem)
  @fs.write_file(cert, cert_pem)
  (key, cert)
}

///|
test "sha1" {
  inspect(
    @crypto.bytes_to_hex_string(@tls.sha1(b"abc")),
    content="a9993e364706816aba3e25717850c26c9cd0d89d",
  )
}

///|
test "rand_bytes length" {
  inspect(@tls.rand_bytes(12).length(), content="12")
}

///|
test "echo" {
  @async.run_async_main(() => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = @pipe.pipe()
      let (server_read_from_client, client_write_to_server) = @pipe.pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        match server.read_some() {
          Some(data) => {
            inspect(@utf8.decode(data), content="ping")
            server.write(b"pong")
          }
          None => fail("expected tls request")
        }
        server.shutdown()
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        assert_true(client.get_peer_certificate() is Some(_))
        client.write(b"ping")
        inspect(@utf8.decode(client.read_exactly(4)), content="pong")
        client.shutdown()
      })
    })
    ignore(try? @fs.remove(key))
    ignore(try? @fs.remove(cert))
  })
}

///|
test "get_peer_certificate" {
  @async.run_async_main(() => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = @pipe.pipe()
      let (server_read_from_client, client_write_to_server) = @pipe.pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        debug_inspect(
          server.get_peer_certificate().map(cert => cert.length()),
          content="None",
        )
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        assert_true(client.get_peer_certificate() is Some(_))
        client.shutdown()
      })
    })
    ignore(try? @fs.remove(key))
    ignore(try? @fs.remove(cert))
  })
}

///|
test "channel binding" {
  @async.run_async_main(() => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = @pipe.pipe()
      let (server_read_from_client, client_write_to_server) = @pipe.pipe()
      let server_task = root.spawn(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        (
          server.unique_channel_binding(),
          server.server_endpoint_channel_binding(),
        )
      })
      let client_task = root.spawn(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        let binding = (
          client.unique_channel_binding(),
          client.server_endpoint_channel_binding(),
        )
        client.shutdown()
        binding
      })
      let (server_unique, server_endpoint) = server_task.wait()
      let (client_unique, client_endpoint) = client_task.wait()
      assert_eq(client_unique, server_unique)
      assert_true(client_unique.length() > 0)
      assert_eq(client_endpoint, server_endpoint)
      assert_true(client_endpoint.length() > 0)
    })
    ignore(try? @fs.remove(key))
    ignore(try? @fs.remove(cert))
  })
}
