///|
extern "js" fn js_fetch_internal(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
) -> @js_async.Promise[String] =
  #| async (url, method, headersJson, body) => {
  #|   const headers = JSON.parse(headersJson);
  #|   try {
  #|     const options = { method, headers };
  #|     if (body && method !== 'GET' && method !== 'HEAD') {
  #|       options.body = body;
  #|     }
  #|     const res = await fetch(url, options);
  #|     const resBody = await res.text();
  #|     const resHeaders = {};
  #|     res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|     return JSON.stringify({
  #|       code: res.status,
  #|       reason: res.statusText,
  #|       headers: resHeaders,
  #|       body: resBody,
  #|     });
  #|   } catch (e) {
  #|     throw e;
  #|   }
  #| }

///|
fn parse_response_json(json_str : String) -> (Response, &@io.Data) {
  let parsed = @json.parse(json_str) catch {
    _ => return (Response::{ code: 0, reason: "", headers: {} }, "")
  }
  let code = match parsed {
    Object(map) =>
      match map.get("code") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
    _ => 0
  }
  let reason = match parsed {
    Object(map) =>
      match map.get("reason") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let body : String = match parsed {
    Object(map) =>
      match map.get("body") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let headers : Map[String, String] = {}
  match parsed {
    Object(map) =>
      match map.get("headers") {
        Some(Object(hmap)) =>
          hmap.each(fn(k, v) {
            match v {
              String(s) => headers[k.to_lower()] = s
              _ => ()
            }
          })
        _ => ()
      }
    _ => ()
  }
  (Response::{ code, reason, headers }, body)
}

// Streaming API

///|
priv struct JsStreamResult {
  id : Int
  code : Int
  reason : String
  headers_json : String
}

///|
priv struct JsStreamChunk {
  done : Bool
  data : Bytes
}

///|
extern "js" fn js_fetch_stream(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
) -> @js_async.Promise[JsStreamResult] =
  #| async (url, method, headersJson, body) => {
  #|   if (!globalThis.__xhs) globalThis.__xhs = { streams: new Map(), nextId: 1 };
  #|   const headers = JSON.parse(headersJson);
  #|   const options = { method, headers };
  #|   if (body && method !== 'GET' && method !== 'HEAD') {
  #|     options.body = body;
  #|   }
  #|   const res = await fetch(url, options);
  #|   const reader = res.body.getReader();
  #|   const id = globalThis.__xhs.nextId++;
  #|   globalThis.__xhs.streams.set(id, { reader });
  #|   const resHeaders = {};
  #|   res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|   return { id, code: res.status, reason: res.statusText, headers_json: JSON.stringify(resHeaders) };
  #| }

///|
extern "js" fn js_stream_read(id : Int) -> @js_async.Promise[JsStreamChunk] =
  #| async (id) => {
  #|   const s = globalThis.__xhs.streams.get(id);
  #|   if (!s) throw new Error('Stream not found');
  #|   const { done, value } = await s.reader.read();
  #|   return { done, data: done ? new Uint8Array(0) : value };
  #| }

///|
extern "js" fn js_stream_close(id : Int) -> Unit =
  #| (id) => {
  #|   const s = globalThis.__xhs;
  #|   const st = s.streams.get(id);
  #|   if (st) { st.reader.cancel().catch(() => {}); s.streams.delete(id); }
  #| }

///|
pub struct Stream {
  id : Int
}

///|
fn parse_headers_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  let parsed = @json.parse(json_str) catch { _ => return headers }
  match parsed {
    Object(map) =>
      map.each(fn(k, v) {
        match v {
          String(s) => headers[k.to_lower()] = s
          _ => ()
        }
      })
    _ => ()
  }
  headers
}

// Server API

///|
priv struct JsServeStart {
  id : Int
  port : Int
}

///|
priv struct JsServerAccept {
  conn_id : Int
  req_meth : String
  req_url : String
  headers_json : String
  body : Bytes
  client_host : String
  client_port : Int
}

///|
extern "js" fn js_server_new(
  host : String,
  port : Int,
  headers_json : String,
  max_request_body_bytes : Int,
  request_timeout_ms : Int,
  keep_alive_timeout_ms : Int,
  headers_timeout_ms : Int,
  accept_queue_limit : Int,
) -> @js_async.Promise[JsServeStart] =
  #| async (host, port, headersJson, maxRequestBodyBytes, requestTimeoutMs, keepAliveTimeoutMs, headersTimeoutMs, acceptQueueLimit) => {
  #|   const http = await import('node:http');
  #|   if (!globalThis.__xhttpServer) {
  #|     globalThis.__xhttpServer = {
  #|       nextId: 1,
  #|       nextConnId: 1,
  #|       servers: new Map(),
  #|       conns: new Map(),
  #|     };
  #|   }
  #|   const state = globalThis.__xhttpServer;
  #|   const server = http.createServer();
  #|   const baseHeaders = JSON.parse(headersJson || '{}');
  #|   const normalizeClientHost = (rawHost) => {
  #|     if (!rawHost || rawHost.length === 0) return '127.0.0.1';
  #|     if (rawHost.startsWith('::ffff:')) return rawHost.slice(7);
  #|     return rawHost;
  #|   };
  #|   const id = state.nextId++;
  #|   const entry = {
  #|     server,
  #|     onRequest: null,
  #|     allowFailure: true,
  #|     maxConnections: 0,
  #|     inflight: 0,
  #|     maxRequestBodyBytes: Math.max(0, Number(maxRequestBodyBytes || 0)),
  #|     acceptQueueLimit: Math.max(1, Number(acceptQueueLimit || 128)),
  #|     baseHeaders,
  #|     mode: 'idle',
  #|     runWaiters: [],
  #|     acceptWaiters: [],
  #|     acceptQueue: [],
  #|     sockets: new Set(),
  #|     closeGracefulPromise: null,
  #|     closing: false,
  #|     closed: false,
  #|   };
  #|   state.servers.set(id, entry);
  #|   if (requestTimeoutMs > 0) {
  #|     server.requestTimeout = requestTimeoutMs;
  #|   }
  #|   if (keepAliveTimeoutMs > 0) {
  #|     server.keepAliveTimeout = keepAliveTimeoutMs;
  #|   }
  #|   if (headersTimeoutMs > 0) {
  #|     server.headersTimeout = headersTimeoutMs;
  #|   }
  #|   server.on('connection', (socket) => {
  #|     entry.sockets.add(socket);
  #|     socket.once('close', () => { entry.sockets.delete(socket); });
  #|     if (entry.closing) {
  #|       try { socket.destroy(); } catch {}
  #|     }
  #|   });
  #|   const makeConn = (req, res) => {
  #|     const connId = state.nextConnId++;
  #|     const conn = {
  #|       id: connId,
  #|       serverId: id,
  #|       req,
  #|       res,
  #|       socket: req?.socket,
  #|       passthrough: false,
  #|       socketReadQueue: [],
  #|       socketReadWaiters: [],
  #|       socketReadAttached: false,
  #|       socketReadEnded: false,
  #|       socketReadOnData: null,
  #|       socketReadOnEnd: null,
  #|       responseStarted: false,
  #|       responseEnded: false,
  #|       closed: false,
  #|       clientHost: normalizeClientHost(req?.socket?.remoteAddress || ''),
  #|       clientPort: Number(req?.socket?.remotePort || 0),
  #|     };
  #|     state.conns.set(connId, conn);
  #|     const cleanupConn = () => {
  #|       const current = state.conns.get(connId);
  #|       if (!current) return;
  #|       if (current.socketReadAttached && current.socket) {
  #|         try { current.socket.off('data', current.socketReadOnData); } catch {}
  #|         try { current.socket.off('end', current.socketReadOnEnd); } catch {}
  #|         try { current.socket.off('close', current.socketReadOnEnd); } catch {}
  #|         current.socketReadAttached = false;
  #|       }
  #|       while (current.socketReadWaiters.length > 0) {
  #|         current.socketReadWaiters.shift()(new Uint8Array(0));
  #|       }
  #|       current.closed = true;
  #|       current.responseEnded = true;
  #|       state.conns.delete(connId);
  #|     };
  #|     res.once('close', cleanupConn);
  #|     res.once('finish', cleanupConn);
  #|     return conn;
  #|   };
  #|   const readRequestBody = async (req) => {
  #|     const limit = entry.maxRequestBodyBytes;
  #|     let total = 0;
  #|     const chunks = [];
  #|     for await (const chunk of req) {
  #|       const part = chunk instanceof Uint8Array ? chunk : Buffer.from(chunk);
  #|       total += part.length;
  #|       if (limit > 0 && total > limit) {
  #|         const err = new Error('request body too large');
  #|         err.code = 'X_BODY_TOO_LARGE';
  #|         throw err;
  #|       }
  #|       chunks.push(part);
  #|     }
  #|     return chunks.length === 0
  #|       ? new Uint8Array(0)
  #|       : new Uint8Array(Buffer.concat(chunks));
  #|   };
  #|   server.on('request', async (req, res) => {
  #|     if (entry.mode !== 'run' && entry.mode !== 'accept') {
  #|       res.statusCode = 503;
  #|       res.end('server not running');
  #|       return;
  #|     }
  #|     if (entry.mode === 'run' && !entry.onRequest) {
  #|       res.statusCode = 503;
  #|       res.end('server not running');
  #|       return;
  #|     }
  #|     if (entry.mode === 'accept' && entry.acceptWaiters.length === 0 && entry.acceptQueue.length >= entry.acceptQueueLimit) {
  #|       res.statusCode = 503;
  #|       res.end('accept queue full');
  #|       return;
  #|     }
  #|     if (entry.maxConnections > 0 && entry.inflight >= entry.maxConnections) {
  #|       res.statusCode = 503;
  #|       res.end('too many connections');
  #|       return;
  #|     }
  #|     entry.inflight++;
  #|     const conn = makeConn(req, res);
  #|     try {
  #|       const body = await readRequestBody(req);
  #|       const reqHeaders = JSON.stringify(req.headers || {});
  #|       if (entry.mode === 'accept') {
  #|         const accepted = {
  #|           conn_id: conn.id,
  #|           req_meth: req.method || 'GET',
  #|           req_url: req.url || '/',
  #|           headers_json: reqHeaders,
  #|           body,
  #|           client_host: conn.clientHost,
  #|           client_port: conn.clientPort,
  #|         };
  #|         const waiter = entry.acceptWaiters.shift();
  #|         if (waiter) {
  #|           waiter.resolve(accepted);
  #|         } else {
  #|           entry.acceptQueue.push(accepted);
  #|         }
  #|       } else {
  #|         await entry.onRequest(
  #|           req.method || 'GET',
  #|           req.url || '/',
  #|           reqHeaders,
  #|           body,
  #|           conn.id,
  #|           conn.clientHost,
  #|           conn.clientPort,
  #|         );
  #|       }
  #|     } catch (err) {
  #|       if (err && err.code === 'X_BODY_TOO_LARGE') {
  #|         try {
  #|           if (!res.headersSent) {
  #|             res.writeHead(413, entry.baseHeaders || {});
  #|           }
  #|           res.end('request body too large');
  #|         } catch {}
  #|         const current = state.conns.get(conn.id);
  #|         if (current) state.conns.delete(conn.id);
  #|         return;
  #|       }
  #|       const current = state.conns.get(conn.id);
  #|       if (current && !current.responseEnded && !current.closed) {
  #|         try {
  #|           if (!current.responseStarted) {
  #|             current.res.writeHead(500, entry.baseHeaders || {});
  #|             current.responseStarted = true;
  #|           }
  #|           current.res.end(String(err));
  #|           current.responseEnded = true;
  #|         } catch {}
  #|         state.conns.delete(conn.id);
  #|       }
  #|       if (!entry.allowFailure) {
  #|         entry.server.close();
  #|       }
  #|     } finally {
  #|       entry.inflight--;
  #|     }
  #|   });
  #|   server.on('close', () => {
  #|     if (entry.closed) return;
  #|     entry.closed = true;
  #|     entry.closing = true;
  #|     for (const [connId, conn] of state.conns.entries()) {
  #|       if (conn.serverId === id) {
  #|         try { conn.req.destroy(); } catch {}
  #|         try { conn.res.destroy(); } catch {}
  #|         state.conns.delete(connId);
  #|       }
  #|     }
  #|     for (const resolve of entry.runWaiters) resolve();
  #|     entry.runWaiters = [];
  #|     for (const waiter of entry.acceptWaiters) {
  #|       waiter.reject(new Error('Server closed'));
  #|     }
  #|     entry.acceptWaiters = [];
  #|     entry.acceptQueue = [];
  #|     state.servers.delete(id);
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onError = (err) => reject(err);
  #|     server.once('error', onError);
  #|     server.listen(port, host, () => {
  #|       server.off('error', onError);
  #|       resolve();
  #|     });
  #|   });
  #|   const addr = server.address();
  #|   const listenPort = typeof addr === 'object' && addr ? addr.port : port;
  #|   return { id, port: listenPort };
  #| }

///|
extern "js" fn js_server_run(
  id : Int,
  on_request : (String, String, String, Bytes, Int, String, Int) -> @js_async.Promise[
    Unit,
  ],
  allow_failure : Bool,
  max_connections : Int,
) -> @js_async.Promise[Unit] =
  #| async (id, onRequest, allowFailure, maxConnections) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const entry = state?.servers.get(id);
  #|   if (!entry) throw new Error('Server not found');
  #|   if (entry.mode === 'accept') {
  #|     throw new Error('Server is in accept mode');
  #|   }
  #|   entry.mode = 'run';
  #|   entry.onRequest = onRequest;
  #|   entry.allowFailure = allowFailure;
  #|   entry.maxConnections = maxConnections;
  #|   if (entry.closed) return;
  #|   await new Promise((resolve) => { entry.runWaiters.push(resolve); });
  #| }

///|
extern "js" fn js_server_accept(id : Int) -> @js_async.Promise[JsServerAccept] =
  #| async (id) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const entry = state?.servers.get(id);
  #|   if (!entry) throw new Error('Server not found');
  #|   if (entry.mode === 'run') {
  #|     throw new Error('Server is in run_forever mode');
  #|   }
  #|   entry.mode = 'accept';
  #|   if (entry.closed) throw new Error('Server closed');
  #|   if (entry.acceptQueue.length > 0) {
  #|     return entry.acceptQueue.shift();
  #|   }
  #|   return await new Promise((resolve, reject) => {
  #|     entry.acceptWaiters.push({ resolve, reject });
  #|   });
  #| }

///|
extern "js" fn js_server_close(id : Int) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xhttpServer;
  #|   if (!state) return;
  #|   const entry = state.servers.get(id);
  #|   if (!entry) return;
  #|   entry.closing = true;
  #|   entry.server.close();
  #| }

///|
extern "js" fn js_server_close_graceful(
  id : Int,
  timeout_ms : Int,
) -> @js_async.Promise[Unit] =
  #| async (id, timeoutMs) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const entry = state?.servers.get(id);
  #|   if (!entry) return;
  #|   if (entry.closeGracefulPromise) {
  #|     await entry.closeGracefulPromise;
  #|     return;
  #|   }
  #|   entry.closeGracefulPromise = (async () => {
  #|     entry.closing = true;
  #|     entry.mode = 'idle';
  #|     entry.onRequest = null;
  #|     try { entry.server.closeIdleConnections?.(); } catch {}
  #|     const closePromise = new Promise((resolve) => {
  #|       try {
  #|         entry.server.close(() => resolve());
  #|       } catch {
  #|         resolve();
  #|       }
  #|     });
  #|     if (!(timeoutMs > 0)) {
  #|       await closePromise;
  #|       return;
  #|     }
  #|     let timedOut = false;
  #|     let timer = null;
  #|     const timeoutPromise = new Promise((resolve) => {
  #|       timer = setTimeout(() => {
  #|         timedOut = true;
  #|         for (const [connId, conn] of state.conns.entries()) {
  #|           if (conn.serverId !== id) continue;
  #|           if (!conn.closed && !conn.responseEnded && conn.responseStarted && !conn.passthrough) {
  #|             try { conn.res.end(); } catch {}
  #|             conn.responseEnded = true;
  #|           }
  #|           const current = state.conns.get(connId);
  #|           if (current && current.socket && !current.socket.destroyed) {
  #|             try { current.socket.destroy(); } catch {}
  #|           }
  #|         }
  #|         try { entry.server.closeAllConnections?.(); } catch {}
  #|         for (const socket of entry.sockets) {
  #|           try { socket.destroy(); } catch {}
  #|         }
  #|         resolve();
  #|       }, timeoutMs);
  #|     });
  #|     await Promise.race([closePromise, timeoutPromise]);
  #|     if (timer) {
  #|       clearTimeout(timer);
  #|     }
  #|     if (timedOut) {
  #|       await Promise.race([
  #|         closePromise,
  #|         new Promise((resolve) => setTimeout(resolve, 250)),
  #|       ]);
  #|       if (!entry.closed) {
  #|         entry.closed = true;
  #|         entry.closing = true;
  #|         for (const [connId, conn] of state.conns.entries()) {
  #|           if (conn.serverId !== id) continue;
  #|           try { conn.req.destroy(); } catch {}
  #|           try { conn.res.destroy(); } catch {}
  #|           state.conns.delete(connId);
  #|         }
  #|         for (const resolve of entry.runWaiters) resolve();
  #|         entry.runWaiters = [];
  #|         for (const waiter of entry.acceptWaiters) {
  #|           waiter.reject(new Error('Server closed'));
  #|         }
  #|         entry.acceptWaiters = [];
  #|         entry.acceptQueue = [];
  #|         state.servers.delete(id);
  #|       }
  #|     }
  #|   })();
  #|   try {
  #|     await entry.closeGracefulPromise;
  #|   } finally {
  #|     entry.closeGracefulPromise = null;
  #|   }
  #| }

///|
extern "js" fn js_conn_send_response(
  conn_id : Int,
  code : Int,
  reason : String,
  headers_json : String,
) -> Unit =
  #| (connId, code, reason, headersJson) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded || conn.responseStarted) return;
  #|   const entry = state.servers.get(conn.serverId);
  #|   const base = entry?.baseHeaders || {};
  #|   let extra = {};
  #|   if (headersJson && headersJson.length > 0) {
  #|     try { extra = JSON.parse(headersJson); } catch {}
  #|   }
  #|   const headers = { ...base, ...extra };
  #|   const status = typeof code === 'number' ? code : 200;
  #|   if (reason && reason.length > 0) {
  #|     conn.res.writeHead(status, reason, headers);
  #|   } else {
  #|     conn.res.writeHead(status, headers);
  #|   }
  #|   conn.responseStarted = true;
  #| }

///|
extern "js" fn js_conn_write(
  conn_id : Int,
  data : Bytes,
  offset : Int,
  len : Int,
) -> @js_async.Promise[Int] =
  #| async (connId, data, offset, len) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded) return 0;
  #|   const start = Math.max(0, offset | 0);
  #|   const maxLen = Math.max(0, len | 0);
  #|   const end = Math.min(data.length, start + maxLen);
  #|   if (end <= start) return 0;
  #|   const slice = data.subarray(start, end);
  #|   const target = conn.passthrough ? conn.socket : conn.res;
  #|   if (!target) return 0;
  #|   const isTargetClosed = () => {
  #|     return !!target.destroyed || !!target.closed || !!target.writableEnded;
  #|   };
  #|   if (isTargetClosed()) return 0;
  #|   if (!conn.passthrough && !conn.responseStarted) {
  #|     const entry = state.servers.get(conn.serverId);
  #|     conn.res.writeHead(200, entry?.baseHeaders || {});
  #|     conn.responseStarted = true;
  #|   }
  #|   let wrote = false;
  #|   try {
  #|     wrote = target.write(slice);
  #|   } catch {
  #|     return 0;
  #|   }
  #|   if (!wrote) {
  #|     await new Promise((resolve) => {
  #|       if (isTargetClosed()) {
  #|         resolve();
  #|         return;
  #|       }
  #|       let settled = false;
  #|       const onDrain = () => {
  #|         done();
  #|       };
  #|       const onError = () => {
  #|         done();
  #|       };
  #|       const done = () => {
  #|         if (settled) return;
  #|         settled = true;
  #|         clearTimeout(timer);
  #|         target.off?.('drain', onDrain);
  #|         target.off?.('error', onError);
  #|         target.off?.('close', onError);
  #|         target.off?.('finish', onError);
  #|         resolve();
  #|       };
  #|       const timer = setTimeout(done, 1000);
  #|       target.once?.('drain', onDrain);
  #|       target.once?.('error', onError);
  #|       target.once?.('close', onError);
  #|       target.once?.('finish', onError);
  #|     });
  #|   }
  #|   const current = state?.conns.get(connId);
  #|   if (!current || current.closed || current.responseEnded || isTargetClosed()) return 0;
  #|   return end - start;
  #| }

///|
extern "js" fn js_conn_flush(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded) return;
  #|   if (conn.passthrough) return;
  #|   if (!conn.responseStarted) {
  #|     const entry = state.servers.get(conn.serverId);
  #|     conn.res.writeHead(200, entry?.baseHeaders || {});
  #|     conn.responseStarted = true;
  #|   }
  #|   if (typeof conn.res.flushHeaders === 'function') {
  #|     conn.res.flushHeaders();
  #|   }
  #|   if (typeof conn.res.flush === 'function') {
  #|     try { conn.res.flush(); } catch {}
  #|   }
  #| }

///|
extern "js" fn js_conn_end(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || conn.responseEnded) return;
  #|   if (conn.passthrough) return;
  #|   if (!conn.responseStarted) {
  #|     const entry = state.servers.get(conn.serverId);
  #|     conn.res.writeHead(200, entry?.baseHeaders || {});
  #|     conn.responseStarted = true;
  #|   }
  #|   conn.res.end();
  #|   conn.responseEnded = true;
  #|   state.conns.delete(connId);
  #| }

///|
extern "js" fn js_conn_close(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn) return;
  #|   if (conn.socketReadAttached && conn.socket) {
  #|     try { conn.socket.off('data', conn.socketReadOnData); } catch {}
  #|     try { conn.socket.off('end', conn.socketReadOnEnd); } catch {}
  #|     try { conn.socket.off('close', conn.socketReadOnEnd); } catch {}
  #|     conn.socketReadAttached = false;
  #|   }
  #|   while (conn.socketReadWaiters.length > 0) {
  #|     conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|   }
  #|   conn.closed = true;
  #|   conn.responseEnded = true;
  #|   try { conn.req.destroy(); } catch {}
  #|   try { conn.res.destroy(); } catch {}
  #|   state.conns.delete(connId);
  #| }

///|
extern "js" fn js_conn_enter_passthrough(conn_id : Int) -> Unit =
  #| (connId) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed) return;
  #|   if (conn.responseStarted && !conn.responseEnded) {
  #|     throw new Error('cannot enter passthrough mode in middle of response');
  #|   }
  #|   if (!conn.socket || conn.socket.destroyed) {
  #|     throw new Error('socket is not available');
  #|   }
  #|   conn.passthrough = true;
  #|   conn.closed = false;
  #|   conn.responseEnded = false;
  #|   if (conn.socketReadAttached) return;
  #|   const onData = (chunk) => {
  #|     const data = chunk instanceof Uint8Array ? new Uint8Array(chunk) : new Uint8Array(Buffer.from(chunk));
  #|     const waiter = conn.socketReadWaiters.shift();
  #|     if (waiter) {
  #|       waiter(data);
  #|     } else {
  #|       conn.socketReadQueue.push(data);
  #|     }
  #|   };
  #|   const onEnd = () => {
  #|     if (conn.socketReadEnded) return;
  #|     conn.socketReadEnded = true;
  #|     while (conn.socketReadWaiters.length > 0) {
  #|       conn.socketReadWaiters.shift()(new Uint8Array(0));
  #|     }
  #|   };
  #|   conn.socketReadOnData = onData;
  #|   conn.socketReadOnEnd = onEnd;
  #|   conn.socket.on('data', onData);
  #|   conn.socket.on('end', onEnd);
  #|   conn.socket.on('close', onEnd);
  #|   conn.socketReadAttached = true;
  #| }

///|
extern "js" fn js_conn_read(
  conn_id : Int,
  max_len : Int,
) -> @js_async.Promise[Bytes] =
  #| async (connId, maxLen) => {
  #|   const state = globalThis.__xhttpServer;
  #|   const conn = state?.conns.get(connId);
  #|   if (!conn || conn.closed || !conn.passthrough) return new Uint8Array(0);
  #|   const pullChunk = () => {
  #|     if (conn.socketReadQueue.length === 0) return null;
  #|     const chunk = conn.socketReadQueue.shift();
  #|     if (!(maxLen > 0) || chunk.length <= maxLen) return chunk;
  #|     const head = chunk.subarray(0, maxLen);
  #|     const tail = chunk.subarray(maxLen);
  #|     if (tail.length > 0) conn.socketReadQueue.unshift(tail);
  #|     return head;
  #|   };
  #|   const queued = pullChunk();
  #|   if (queued) return queued;
  #|   if (conn.socketReadEnded) return new Uint8Array(0);
  #|   const chunk = await new Promise((resolve) => {
  #|     conn.socketReadWaiters.push(resolve);
  #|   });
  #|   if (!(maxLen > 0) || chunk.length <= maxLen) return chunk;
  #|   const head = chunk.subarray(0, maxLen);
  #|   const tail = chunk.subarray(maxLen);
  #|   if (tail.length > 0) conn.socketReadQueue.unshift(tail);
  #|   return head;
  #| }

///|
fn parse_request_method(meth : String) -> RequestMethod {
  match meth {
    "HEAD" => RequestMethod::Head
    "POST" => RequestMethod::Post
    "PUT" => RequestMethod::Put
    "DELETE" => RequestMethod::Delete
    "CONNECT" => RequestMethod::Connect
    "OPTIONS" => RequestMethod::Options
    "TRACE" => RequestMethod::Trace
    "PATCH" => RequestMethod::Patch
    _ => RequestMethod::Get
  }
}

///|
fn path_from_url(url : String) -> String {
  if url == "" {
    "/"
  } else {
    url
  }
}

///|
fn to_addr(host : String, port : Int) -> Addr {
  let h = if host.contains(":") && !host.has_prefix("[") {
    "[" + host + "]"
  } else {
    host
  }
  Addr::{ text: "\{h}:\{port}", port }
}

///|
pub struct ServerConnection {
  request : Request
  request_body : Bytes
  mut request_body_offset : Int
  conn_id : Int
  peer_addr : Addr
  mut passthrough_mode : Bool
  mut response_started : Bool
  mut response_ended : Bool
  mut closed : Bool
}

///|
fn new_server_connection(
  request : Request,
  request_body : Bytes,
  conn_id : Int,
  peer_addr : Addr,
) -> ServerConnection {
  ServerConnection::{
    request,
    request_body,
    request_body_offset: 0,
    conn_id,
    peer_addr,
    passthrough_mode: false,
    response_started: false,
    response_ended: false,
    closed: false,
  }
}

///|
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  if self.closed {
    return
  }
  js_conn_close(self.conn_id)
  self.response_ended = true
  self.closed = true
}

///|
pub fn ServerConnection::read_request(self : ServerConnection) -> Request {
  self.request
}

///|
pub fn ServerConnection::client_addr(self : ServerConnection) -> Addr {
  self.peer_addr
}

///|
pub fn ServerConnection::skip_request_body(self : ServerConnection) -> Unit {
  self.request_body_offset = self.request_body.length()
}

///|
pub fn ServerConnection::send_response(
  self : ServerConnection,
  code : Int,
  reason : String,
  extra_headers? : Map[String, String],
) -> Unit {
  if self.passthrough_mode {
    return
  }
  if self.closed || self.response_ended || self.response_started {
    return
  }
  js_conn_send_response(
    self.conn_id,
    code,
    reason,
    headers_to_json(extra_headers.unwrap_or({})),
  )
  self.response_started = true
}

///|
pub fn ServerConnection::flush(self : ServerConnection) -> Unit {
  if self.passthrough_mode {
    return
  }
  if self.closed || self.response_ended {
    return
  }
  self.response_started = true
  js_conn_flush(self.conn_id)
}

///|
pub fn ServerConnection::end_response(self : ServerConnection) -> Unit {
  if self.passthrough_mode {
    return
  }
  if self.closed || self.response_ended {
    return
  }
  self.response_started = true
  js_conn_end(self.conn_id)
  self.response_ended = true
  self.closed = true
}

///|
pub fn ServerConnection::enter_passthrough_mode(
  self : ServerConnection,
) -> Unit raise HttpError {
  if self.closed {
    raise HttpError::NetworkError("connection closed")
  }
  if self.response_started && !self.response_ended {
    raise HttpError::NetworkError(
      "cannot enter passthrough mode in middle of response",
    )
  }
  js_conn_enter_passthrough(self.conn_id)
  self.passthrough_mode = true
  self.closed = false
  self.response_ended = false
}

///|
pub impl @io.Reader for ServerConnection with _get_internal_buffer(self) {
  ignore(self)
  @io.ReaderBuffer::new()
}

///|
pub impl @io.Reader for ServerConnection with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  if self.passthrough_mode {
    let remaining = self.request_body.length() - self.request_body_offset
    if remaining > 0 {
      let n = @cmp.minimum(max_len, remaining)
      buf.blit_from_bytes(
        offset,
        self.request_body,
        self.request_body_offset,
        n,
      )
      self.request_body_offset = self.request_body_offset + n
      return n
    }
    let controller = @js_async.AbortController::new()
    let promise = js_conn_read(self.conn_id, max_len)
    let data = @js_async.Promise::wait(promise, abort_controller=controller) catch {
      _ => return 0
    }
    let len = data.length()
    if len <= 0 {
      0
    } else {
      let n = @cmp.minimum(max_len, len)
      buf.blit_from_bytes(offset, data, 0, n)
      n
    }
  } else {
    let remaining = self.request_body.length() - self.request_body_offset
    if remaining <= 0 {
      0
    } else {
      let n = @cmp.minimum(max_len, remaining)
      buf.blit_from_bytes(
        offset,
        self.request_body,
        self.request_body_offset,
        n,
      )
      self.request_body_offset = self.request_body_offset + n
      n
    }
  }
}

///|
pub impl @io.Writer for ServerConnection with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  if self.closed || self.response_ended || offset >= buf.length() {
    0
  } else {
    let n = @cmp.minimum(len, buf.length() - offset)
    if n <= 0 {
      0
    } else {
      let controller = @js_async.AbortController::new()
      let promise = js_conn_write(self.conn_id, buf, offset, n)
      let wrote = @js_async.Promise::wait(promise, abort_controller=controller) catch {
        _ => return 0
      }
      self.response_started = !self.passthrough_mode
      wrote
    }
  }
}

///|
pub struct Server {
  id : Int
  port : Int
  addr : Addr
}

///|
pub async fn Server::new(
  host? : String,
  port? : Int,
  headers? : Map[String, String],
  dual_stack? : Bool,
  reuse_addr? : Bool,
  max_request_body_bytes? : Int,
  request_timeout_ms? : Int,
  keep_alive_timeout_ms? : Int,
  headers_timeout_ms? : Int,
  accept_queue_limit? : Int,
) -> Server raise HttpError {
  ignore(dual_stack)
  ignore(reuse_addr)
  let h = host.unwrap_or("127.0.0.1")
  let controller = @js_async.AbortController::new()
  let promise = js_server_new(
    h,
    port.unwrap_or(3000),
    headers_to_json(headers.unwrap_or({})),
    max_request_body_bytes.unwrap_or(0),
    request_timeout_ms.unwrap_or(0),
    keep_alive_timeout_ms.unwrap_or(0),
    headers_timeout_ms.unwrap_or(0),
    accept_queue_limit.unwrap_or(128),
  )
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  Server::{ id: result.id, port: result.port, addr: to_addr(h, result.port) }
}

///|
pub fn Server::port(self : Server) -> Int {
  self.port
}

///|
pub fn Server::addr(self : Server) -> Addr {
  self.addr
}

///|
pub async fn Server::accept(
  self : Server,
) -> (ServerConnection, Addr) raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_server_accept(self.id)
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  let request = Request::{
    meth: parse_request_method(result.req_meth),
    path: path_from_url(result.req_url),
    headers: parse_headers_json(result.headers_json),
  }
  let peer_addr = to_addr(result.client_host, result.client_port)
  let conn = new_server_connection(
    request,
    result.body,
    result.conn_id,
    peer_addr,
  )
  (conn, peer_addr)
}

///|
pub async fn Server::run_forever(
  self : Server,
  f : async (Request, &@io.Reader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit raise HttpError {
  fn on_request(
    req_meth : String,
    req_url : String,
    headers_json : String,
    body : Bytes,
    conn_id : Int,
    client_host : String,
    client_port : Int,
  ) -> @js_async.Promise[Unit] {
    @js_async.Promise::from_async(() => {
      let request = Request::{
        meth: parse_request_method(req_meth),
        path: path_from_url(req_url),
        headers: parse_headers_json(headers_json),
      }
      let conn = new_server_connection(
        request,
        body,
        conn_id,
        to_addr(client_host, client_port),
      )
      f(request, conn, conn)
      if !conn.response_ended {
        conn.end_response()
      }
    })
  }
  let controller = @js_async.AbortController::new()
  let promise = js_server_run(
    self.id,
    on_request,
    allow_failure.unwrap_or(true),
    max_connections.unwrap_or(0),
  )
  @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
}

///|
pub fn Server::close(self : Server) -> Unit {
  js_server_close(self.id)
}

///|
pub async fn Server::close_graceful(
  self : Server,
  timeout_ms? : Int,
) -> Unit raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_server_close_graceful(self.id, timeout_ms.unwrap_or(30000))
  @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
}

///|
async fn stream_request_internal_js(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, Stream) raise HttpError {
  let hjson = headers_to_json(headers)
  let body_str = body.text() catch { _ => "" }
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_stream(url, meth, hjson, body_str)
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  let resp = Response::{
    code: result.code,
    reason: result.reason,
    headers: parse_headers_json(result.headers_json),
  }
  (resp, Stream::{ id: result.id })
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  let empty : String = ""
  stream_request_internal_js(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal_js(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal_js(url, "PUT", headers.unwrap_or({}), body)
}

///|
pub async fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_stream_read(self.id)
  let chunk = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  if chunk.done {
    None
  } else {
    Some(chunk.data)
  }
}

///|
pub async fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  let chunks : Array[Bytes] = []
  let mut total = 0
  for {
    match self.read_some() {
      Some(chunk) => {
        chunks.push(chunk)
        total = total + chunk.length()
      }
      None => break
    }
  }
  if chunks.length() == 1 {
    return chunks[0]
  }
  let flat : Array[Byte] = Array::new(capacity=total)
  for chunk in chunks {
    for i = 0; i < chunk.length(); i = i + 1 {
      flat.push(chunk[i])
    }
  }
  Bytes::makei(flat.length(), fn(i) { flat[i] })
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  js_stream_close(self.id)
}

// Non-streaming API

///|
async fn request_internal_js(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, &@io.Data) raise HttpError {
  let hjson = headers_to_json(headers)
  let body_str = body.text() catch { _ => "" }
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_internal(url, meth, hjson, body_str)
  let result_json = @js_async.Promise::wait(
    promise,
    abort_controller=controller,
  ) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  parse_response_json(result_json)
}

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  let empty : String = ""
  request_internal_js(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal_js(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal_js(url, "PUT", headers.unwrap_or({}), body)
}
