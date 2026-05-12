///|
pub async fn Addr::resolve(
  _host : String,
  port~ : Int,
  protocol? : IpProtocolPreference,
) -> Addr raise ResolveHostnameError {
  ignore((port, protocol))
  raise ResolveHostnameError::ResolveHostnameError(
    "socket is not supported on wasm-gc target",
  )
}

///|
pub struct Tcp {}

///|
pub fn Tcp::close(_self : Tcp) -> Unit {

}

///|
pub fn Tcp::fd(_self : Tcp) -> Int {
  -1
}

///|
pub fn Tcp::addr(_self : Tcp) -> Addr {
  abort("tcp is not supported on wasm-gc target")
}

///|
pub async fn Tcp::connect(_addr : Addr) -> Tcp {
  abort("tcp is not supported on wasm-gc target")
}

///|
pub async fn Tcp::connect_to_host(
  _host : StringView,
  port~ : Int,
  protocol? : IpProtocolPreference,
) -> Tcp {
  ignore((port, protocol))
  abort("tcp is not supported on wasm-gc target")
}

///|
pub fn Tcp::enable_keepalive(
  _self : Tcp,
  idle_before_keep_alive? : Int,
  keep_alive_count? : Int,
  keep_alive_interval? : Int,
) -> Unit raise {
  ignore((idle_before_keep_alive, keep_alive_count, keep_alive_interval))
  raise Failure::Failure("tcp is not supported on wasm-gc target")
}

///|
pub impl @io.Reader for Tcp with _get_internal_buffer(self) {
  ignore(self)
  @io.ReaderBuffer::new()
}

///|
pub impl @io.Reader for Tcp with _direct_read(self, _buf, offset~, max_len~) {
  ignore((self, offset, max_len))
  abort("tcp is not supported on wasm-gc target")
}

///|
pub impl @io.Writer for Tcp with write_once(self, _buf, offset~, len~) {
  ignore((self, offset, len))
  abort("tcp is not supported on wasm-gc target")
}

///|
pub struct TcpServer {}

///|
#alias(new, deprecated)
pub async fn TcpServer::TcpServer(
  _addr : Addr,
  dual_stack? : Bool,
  reuse_addr? : Bool,
) -> TcpServer {
  ignore((dual_stack, reuse_addr))
  abort("tcp is not supported on wasm-gc target")
}

///|
pub fn TcpServer::close(_self : TcpServer) -> Unit {

}

///|
pub fn TcpServer::fd(_self : TcpServer) -> Int {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn TcpServer::addr(_self : TcpServer) -> Addr {
  abort("tcp is not supported on wasm-gc target")
}

///|
pub async fn TcpServer::accept(_self : TcpServer) -> (Tcp, Addr) {
  abort("tcp is not supported on wasm-gc target")
}

///|
pub async fn TcpServer::run_forever(
  _self : TcpServer,
  _f : async (Tcp, Addr) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit {
  ignore((allow_failure, max_connections))
  abort("tcp is not supported on wasm-gc target")
}

///|
pub struct UdpClient {}

///|
#alias(new, deprecated)
pub async fn UdpClient::UdpClient(_addr : Addr) -> UdpClient {
  abort("udp is not supported on wasm-gc target")
}

///|
pub fn UdpClient::close(_self : UdpClient) -> Unit {

}

///|
pub fn UdpClient::fd(_self : UdpClient) -> Int {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn UdpClient::addr(_self : UdpClient) -> Addr {
  abort("udp is not supported on wasm-gc target")
}

///|
pub fn UdpClient::connect(_self : UdpClient, _addr : Addr) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub async fn UdpClient::recv(
  _self : UdpClient,
  _buf : FixedArray[Byte],
  offset? : Int,
  max_len? : Int,
) -> Int {
  ignore((offset, max_len))
  abort("udp is not supported on wasm-gc target")
}

///|
pub async fn UdpClient::recvfrom(
  _self : UdpClient,
  _buf : FixedArray[Byte],
  offset? : Int,
  max_len? : Int,
) -> (Int, Addr) {
  ignore((offset, max_len))
  abort("udp is not supported on wasm-gc target")
}

///|
pub async fn UdpClient::send(
  _self : UdpClient,
  _buf : Bytes,
  offset? : Int,
  len? : Int,
) -> Unit {
  ignore((offset, len))
  abort("udp is not supported on wasm-gc target")
}

///|
pub fn UdpClient::set_multicast_interface(
  _self : UdpClient,
  _addr : Addr,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpClient::set_multicast_interface_v6(
  _self : UdpClient,
  _interface : String,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpClient::set_multicast_loopback(
  _self : UdpClient,
  _loopback : Bool,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpClient::set_multicast_ttl(
  _self : UdpClient,
  _ttl : Int,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub struct UdpServer {}

///|
#alias(new, deprecated)
pub async fn UdpServer::UdpServer(
  _addr : Addr,
  dual_stack? : Bool,
) -> UdpServer {
  ignore(dual_stack)
  abort("udp is not supported on wasm-gc target")
}

///|
pub async fn UdpServer::multicast(
  _multi_addr : Addr,
  interface_addr? : Addr,
) -> UdpServer {
  ignore(interface_addr)
  abort("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::close(_self : UdpServer) -> Unit {

}

///|
pub fn UdpServer::fd(_self : UdpServer) -> Int {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn UdpServer::addr(_self : UdpServer) -> Addr {
  abort("udp is not supported on wasm-gc target")
}

///|
pub async fn UdpServer::recvfrom(
  _self : UdpServer,
  _buf : FixedArray[Byte],
  offset? : Int,
  max_len? : Int,
) -> (Int, Addr) {
  ignore((offset, max_len))
  abort("udp is not supported on wasm-gc target")
}

///|
pub async fn UdpServer::sendto(
  _self : UdpServer,
  _buf : Bytes,
  _addr : Addr,
  offset? : Int,
  len? : Int,
) -> Unit {
  ignore((offset, len))
  abort("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::join_multicast_group(
  _self : UdpServer,
  _multi_addr : Addr,
  interface_addr? : Addr,
) -> Unit raise {
  ignore(interface_addr)
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::join_multicast_group_v6(
  _self : UdpServer,
  _multi_addr : Addr,
  interface? : String,
) -> Unit raise {
  ignore(interface)
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::set_multicast_interface(
  _self : UdpServer,
  _addr : Addr,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::set_multicast_interface_v6(
  _self : UdpServer,
  _interface : String,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::set_multicast_loopback(
  _self : UdpServer,
  _loopback : Bool,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}

///|
pub fn UdpServer::set_multicast_ttl(
  _self : UdpServer,
  _ttl : Int,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm-gc target")
}
