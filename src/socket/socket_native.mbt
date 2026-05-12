///|
fn to_async_protocol(
  protocol : IpProtocolPreference,
) -> @async_socket.IpProtocolPreference {
  match protocol {
    OnlyV4 => @async_socket.OnlyV4
    OnlyV6 => @async_socket.OnlyV6
    FavorV4 => @async_socket.FavorV4
    FavorV6 => @async_socket.FavorV6
    NoPreference => @async_socket.NoPreference
  }
}

///|
fn Addr::to_async(self : Addr) -> @async_socket.Addr raise InvalidAddr {
  @async_socket.Addr::parse(self.to_string()) catch {
    _ => raise InvalidAddr
  }
}

///|
fn addr_from_async(addr : @async_socket.Addr) -> Addr {
  Addr::parse("\{addr}") catch {
    _ =>
      if addr.is_ipv6() {
        Addr::{ host: "::", port: addr.port(), ip: 0U, is_ipv6: true }
      } else {
        Addr::new(addr.ip(), addr.port())
      }
  }
}

///|
pub async fn Addr::resolve(
  host : String,
  port~ : Int,
  protocol? : IpProtocolPreference,
) -> Addr raise ResolveHostnameError {
  let protocol = to_async_protocol(protocol.unwrap_or(NoPreference))
  let addr = @async_socket.Addr::resolve(host, port~, protocol~) catch {
    err => raise ResolveHostnameError::ResolveHostnameError(err.to_string())
  }
  addr_from_async(addr)
}

///|
pub struct Tcp {
  addr : Addr
  priv inner : @async_socket.Tcp
}

///|
pub fn Tcp::close(self : Tcp) -> Unit {
  self.inner.close()
}

///|
pub fn Tcp::fd(self : Tcp) -> Int {
  self.inner.fd()
}

///|
pub fn Tcp::addr(self : Tcp) -> Addr {
  self.addr
}

///|
pub async fn Tcp::connect(addr : Addr) -> Tcp {
  let inner = @async_socket.Tcp::connect(
    addr.to_async() catch {
      _ => abort("@socket.Tcp::connect: invalid address")
    },
  )
  Tcp::{ addr: addr_from_async(inner.addr), inner }
}

///|
pub async fn Tcp::connect_to_host(
  host : StringView,
  port~ : Int,
  protocol? : IpProtocolPreference,
) -> Tcp {
  let inner = @async_socket.Tcp::connect_to_host(
    host,
    port~,
    protocol=to_async_protocol(protocol.unwrap_or(NoPreference)),
  )
  Tcp::{ addr: addr_from_async(inner.addr), inner }
}

///|
pub fn Tcp::enable_keepalive(
  self : Tcp,
  idle_before_keep_alive? : Int,
  keep_alive_count? : Int,
  keep_alive_interval? : Int,
) -> Unit raise {
  self.inner.enable_keepalive(
    idle_before_keep_alive?,
    keep_alive_count?,
    keep_alive_interval?,
  )
}

///|
pub impl @io.Reader for Tcp with _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @io.Reader for Tcp with _direct_read(self, buf, offset~, max_len~) {
  @io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub impl @io.Writer for Tcp with write_once(self, buf, offset~, len~) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}

///|
pub struct TcpServer {
  addr : Addr
  priv inner : @async_socket.TcpServer
}

///|
#alias(new, deprecated)
pub async fn TcpServer::TcpServer(
  addr : Addr,
  dual_stack? : Bool,
  reuse_addr? : Bool,
) -> TcpServer {
  let inner = @async_socket.TcpServer(
    addr.to_async() catch {
      _ => abort("@socket.TcpServer: invalid address")
    },
    dual_stack?,
    reuse_addr?,
  )
  TcpServer::{ addr: addr_from_async(inner.addr), inner }
}

///|
pub fn TcpServer::close(self : TcpServer) -> Unit {
  self.inner.close()
}

///|
pub fn TcpServer::fd(self : TcpServer) -> Int {
  self.inner.fd()
}

///|
#deprecated("use `.addr` instead")
pub fn TcpServer::addr(self : TcpServer) -> Addr {
  self.addr
}

///|
pub async fn TcpServer::accept(self : TcpServer) -> (Tcp, Addr) {
  let (conn, peer) = self.inner.accept()
  (
    Tcp::{ addr: addr_from_async(conn.addr), inner: conn },
    addr_from_async(peer),
  )
}

///|
pub async fn TcpServer::run_forever(
  self : TcpServer,
  f : async (Tcp, Addr) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit {
  self.inner.run_forever(
    (conn, peer) => {
      f(
        Tcp::{ addr: addr_from_async(conn.addr), inner: conn },
        addr_from_async(peer),
      )
    },
    allow_failure?,
    max_connections?,
  )
}

///|
pub struct UdpClient {
  addr : Addr
  priv inner : @async_socket.UdpClient
}

///|
#alias(new, deprecated)
pub async fn UdpClient::UdpClient(addr : Addr) -> UdpClient {
  let inner = @async_socket.UdpClient(
    addr.to_async() catch {
      _ => abort("@socket.UdpClient: invalid address")
    },
  )
  UdpClient::{ addr: addr_from_async(inner.addr), inner }
}

///|
pub fn UdpClient::close(self : UdpClient) -> Unit {
  self.inner.close()
}

///|
pub fn UdpClient::fd(self : UdpClient) -> Int {
  self.inner.fd()
}

///|
#deprecated("use `.addr` instead")
pub fn UdpClient::addr(self : UdpClient) -> Addr {
  self.addr
}

///|
pub fn UdpClient::connect(self : UdpClient, addr : Addr) -> Unit raise {
  self.inner.connect(addr.to_async())
}

///|
pub async fn UdpClient::recv(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int,
  max_len? : Int,
) -> Int {
  self.inner.recv(buf, offset?, max_len?)
}

///|
pub async fn UdpClient::recvfrom(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int,
  max_len? : Int,
) -> (Int, Addr) {
  let (n, addr) = self.inner.recvfrom(buf, offset?, max_len?)
  (n, addr_from_async(addr))
}

///|
pub async fn UdpClient::send(
  self : UdpClient,
  buf : Bytes,
  offset? : Int,
  len? : Int,
) -> Unit {
  self.inner.send(buf, offset?, len?)
}

///|
pub fn UdpClient::set_multicast_interface(
  self : UdpClient,
  addr : Addr,
) -> Unit raise {
  self.inner.set_multicast_interface(addr.to_async())
}

///|
pub fn UdpClient::set_multicast_interface_v6(
  self : UdpClient,
  interface : String,
) -> Unit raise {
  self.inner.set_multicast_interface_v6(interface)
}

///|
pub fn UdpClient::set_multicast_loopback(
  self : UdpClient,
  loopback : Bool,
) -> Unit raise {
  self.inner.set_multicast_loopback(loopback)
}

///|
pub fn UdpClient::set_multicast_ttl(self : UdpClient, ttl : Int) -> Unit raise {
  self.inner.set_multicast_ttl(ttl)
}

///|
pub struct UdpServer {
  addr : Addr
  priv inner : @async_socket.UdpServer
}

///|
#alias(new, deprecated)
pub async fn UdpServer::UdpServer(addr : Addr, dual_stack? : Bool) -> UdpServer {
  let inner = @async_socket.UdpServer(
    addr.to_async() catch {
      _ => abort("@socket.UdpServer: invalid address")
    },
    dual_stack?,
  )
  UdpServer::{ addr: addr_from_async(inner.addr), inner }
}

///|
pub async fn UdpServer::multicast(
  multi_addr : Addr,
  interface_addr? : Addr,
) -> UdpServer {
  let inner = @async_socket.UdpServer::multicast(
    multi_addr.to_async() catch {
      _ => abort("@socket.UdpServer::multicast: invalid address")
    },
    interface_addr=match interface_addr {
      Some(addr) =>
        addr.to_async() catch {
          _ => abort("@socket.UdpServer::multicast: invalid interface address")
        }
      None => @async_socket.Addr::new(0U, 0)
    },
  )
  UdpServer::{ addr: addr_from_async(inner.addr), inner }
}

///|
pub fn UdpServer::close(self : UdpServer) -> Unit {
  self.inner.close()
}

///|
pub fn UdpServer::fd(self : UdpServer) -> Int {
  self.inner.fd()
}

///|
#deprecated("use `.addr` instead")
pub fn UdpServer::addr(self : UdpServer) -> Addr {
  self.addr
}

///|
pub async fn UdpServer::recvfrom(
  self : UdpServer,
  buf : FixedArray[Byte],
  offset? : Int,
  max_len? : Int,
) -> (Int, Addr) {
  let (n, addr) = self.inner.recvfrom(buf, offset?, max_len?)
  (n, addr_from_async(addr))
}

///|
pub async fn UdpServer::sendto(
  self : UdpServer,
  buf : Bytes,
  addr : Addr,
  offset? : Int,
  len? : Int,
) -> Unit {
  self.inner.sendto(
    buf,
    addr.to_async() catch {
      _ => abort("@socket.UdpServer::sendto: invalid address")
    },
    offset?,
    len?,
  )
}

///|
pub fn UdpServer::join_multicast_group(
  self : UdpServer,
  multi_addr : Addr,
  interface_addr? : Addr,
) -> Unit raise {
  self.inner.join_multicast_group(
    multi_addr.to_async(),
    interface_addr=match interface_addr {
      Some(addr) => addr.to_async()
      None => @async_socket.Addr::new(0U, 0)
    },
  )
}

///|
pub fn UdpServer::join_multicast_group_v6(
  self : UdpServer,
  multi_addr : Addr,
  interface? : String,
) -> Unit raise {
  self.inner.join_multicast_group_v6(multi_addr.to_async(), interface?)
}

///|
pub fn UdpServer::set_multicast_interface(
  self : UdpServer,
  addr : Addr,
) -> Unit raise {
  self.inner.set_multicast_interface(addr.to_async())
}

///|
pub fn UdpServer::set_multicast_interface_v6(
  self : UdpServer,
  interface : String,
) -> Unit raise {
  self.inner.set_multicast_interface_v6(interface)
}

///|
pub fn UdpServer::set_multicast_loopback(
  self : UdpServer,
  loopback : Bool,
) -> Unit raise {
  self.inner.set_multicast_loopback(loopback)
}

///|
pub fn UdpServer::set_multicast_ttl(self : UdpServer, ttl : Int) -> Unit raise {
  self.inner.set_multicast_ttl(ttl)
}
