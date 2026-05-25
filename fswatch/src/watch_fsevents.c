#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <dlfcn.h>
#include <pthread.h>

/*
 * FSEvents-backed watcher. Loaded lazily via dlsym so the package
 * compiles on any OS without a -framework link flag; on non-macOS,
 * the start FFI returns 0 and the MoonBit caller falls back to the
 * polling backend.
 *
 * Event flow:
 *   FSEvents dispatch-queue thread fires the callback. We strdup
 *   the path and push (path, flags) into a mutex-protected ring
 *   buffer. The MoonBit watcher polls drain() at watcher-tick
 *   cadence; the OS-side detection itself is real-time.
 */

// ---- Opaque CF/FSEvents types (avoid pulling CoreServices.h).

typedef const void *CFAllocatorRef;
typedef const void *CFStringRef;
typedef const void *CFArrayRef;
typedef struct __FSEventStream *FSEventStreamRef;
typedef uint64_t FSEventStreamEventId;
typedef uint32_t FSEventStreamEventFlags;
typedef uint32_t FSEventStreamCreateFlags;
typedef double CFTimeInterval;
typedef long CFIndex;
typedef void *dispatch_queue_t;

typedef struct {
  CFIndex version;
  void *info;
  const void *(*retain)(const void *);
  void (*release)(const void *);
  CFStringRef (*copyDescription)(const void *);
} FSEventStreamContext;

typedef void (*FSEventStreamCallback)(
    FSEventStreamRef streamRef,
    void *clientCallBackInfo,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags *eventFlags,
    const FSEventStreamEventId *eventIds);

// FSEvents flag bits we care about. (Apple SDK constants.)
#define kFSEventStreamCreateFlagNoDefer    0x00000002
#define kFSEventStreamCreateFlagFileEvents 0x00000010
#define kFSEventStreamEventIdSinceNow      0xFFFFFFFFFFFFFFFFULL
#define kCFStringEncodingUTF8              0x08000100

// ---- Lazy library handles.

static struct {
  int loaded;
  int available;
  CFStringRef (*CFStringCreateWithCString)(CFAllocatorRef, const char *, uint32_t);
  CFArrayRef (*CFArrayCreate)(CFAllocatorRef, const void **, CFIndex, const void *);
  void (*CFRelease)(const void *);
  FSEventStreamRef (*FSEventStreamCreate)(
      CFAllocatorRef, FSEventStreamCallback, FSEventStreamContext *,
      CFArrayRef, FSEventStreamEventId, CFTimeInterval, FSEventStreamCreateFlags);
  void (*FSEventStreamSetDispatchQueue)(FSEventStreamRef, dispatch_queue_t);
  int (*FSEventStreamStart)(FSEventStreamRef);
  void (*FSEventStreamStop)(FSEventStreamRef);
  void (*FSEventStreamInvalidate)(FSEventStreamRef);
  void (*FSEventStreamRelease)(FSEventStreamRef);
  dispatch_queue_t (*dispatch_queue_create)(const char *, void *);
  void (*dispatch_release)(void *);
} L;

static void load_lib(void) {
  if (L.loaded) return;
  L.loaded = 1;
  void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY);
  void *cs = dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
  if (!cf || !cs) return;
  L.CFStringCreateWithCString = dlsym(cf, "CFStringCreateWithCString");
  L.CFArrayCreate = dlsym(cf, "CFArrayCreate");
  L.CFRelease = dlsym(cf, "CFRelease");
  L.FSEventStreamCreate = dlsym(cs, "FSEventStreamCreate");
  L.FSEventStreamSetDispatchQueue = dlsym(cs, "FSEventStreamSetDispatchQueue");
  L.FSEventStreamStart = dlsym(cs, "FSEventStreamStart");
  L.FSEventStreamStop = dlsym(cs, "FSEventStreamStop");
  L.FSEventStreamInvalidate = dlsym(cs, "FSEventStreamInvalidate");
  L.FSEventStreamRelease = dlsym(cs, "FSEventStreamRelease");
  L.dispatch_queue_create = dlsym(RTLD_DEFAULT, "dispatch_queue_create");
  L.dispatch_release = dlsym(RTLD_DEFAULT, "dispatch_release");
  L.available = (L.CFStringCreateWithCString && L.CFArrayCreate &&
                 L.CFRelease && L.FSEventStreamCreate &&
                 L.FSEventStreamSetDispatchQueue && L.FSEventStreamStart &&
                 L.FSEventStreamStop && L.FSEventStreamInvalidate &&
                 L.FSEventStreamRelease && L.dispatch_queue_create);
}

// ---- Per-watcher state.

#define RING_CAP 4096

typedef struct {
  pthread_mutex_t mu;
  FSEventStreamRef stream;
  dispatch_queue_t queue;
  char *paths[RING_CAP];
  uint32_t flags[RING_CAP];
  int head;
  int tail;
  int dropped;
  int closed;
} watcher_t;

static int ring_count(watcher_t *w) {
  return (w->tail - w->head + RING_CAP) % RING_CAP;
}

static void push_event(watcher_t *w, const char *path, uint32_t flags) {
  pthread_mutex_lock(&w->mu);
  int next = (w->tail + 1) % RING_CAP;
  if (next == w->head) {
    w->dropped++;
  } else {
    free(w->paths[w->tail]);
    w->paths[w->tail] = strdup(path);
    w->flags[w->tail] = flags;
    w->tail = next;
  }
  pthread_mutex_unlock(&w->mu);
}

static void on_fs_events(
    FSEventStreamRef streamRef, void *info,
    size_t n, void *paths,
    const FSEventStreamEventFlags *flags,
    const FSEventStreamEventId *ids) {
  (void)streamRef;
  (void)ids;
  watcher_t *w = (watcher_t *)info;
  const char **path_arr = (const char **)paths;
  for (size_t i = 0; i < n; i++) {
    push_event(w, path_arr[i], (uint32_t)flags[i]);
  }
}

// ---- FFI entry points.

// Start an FSEvents watcher.
// `paths_buf` is a null-byte-separated, UTF-8 buffer of `num_paths` absolute
// paths. `total_len` is the byte length of the buffer.
// `latency_ms` is the FSEvents coalescing latency in milliseconds.
// Returns an opaque handle (cast to int64_t) or 0 on failure / non-macOS.
MOONBIT_FFI_EXPORT int64_t mizchi_x_watch_fsevents_start(
    char *paths_buf, int32_t total_len, int32_t num_paths, double latency_ms) {
  load_lib();
  if (!L.available || num_paths <= 0) return 0;

  watcher_t *w = (watcher_t *)calloc(1, sizeof(watcher_t));
  if (!w) return 0;
  pthread_mutex_init(&w->mu, NULL);

  CFStringRef *strs = (CFStringRef *)calloc((size_t)num_paths, sizeof(CFStringRef));
  if (!strs) { free(w); return 0; }
  int pos = 0;
  int created = 0;
  for (int i = 0; i < num_paths && pos < total_len; i++) {
    int start = pos;
    while (pos < total_len && paths_buf[pos] != 0) pos++;
    int len = pos - start;
    char tmp[4096];
    if (len >= (int)sizeof(tmp)) len = (int)sizeof(tmp) - 1;
    memcpy(tmp, paths_buf + start, (size_t)len);
    tmp[len] = 0;
    strs[i] = L.CFStringCreateWithCString(NULL, tmp, kCFStringEncodingUTF8);
    if (strs[i]) created++;
    if (pos < total_len) pos++; // skip the null separator
  }
  if (created != num_paths) {
    for (int i = 0; i < num_paths; i++) if (strs[i]) L.CFRelease(strs[i]);
    free(strs); free(w); return 0;
  }

  // CFArrayCreate with NULL callbacks does not retain elements; FSEventStreamCreate
  // takes its own reference, so we delay releasing `strs` and `paths_arr` until
  // *after* the stream is created.
  CFArrayRef paths_arr = L.CFArrayCreate(NULL, (const void **)strs, num_paths, NULL);
  if (!paths_arr) {
    for (int i = 0; i < num_paths; i++) L.CFRelease(strs[i]);
    free(strs); free(w); return 0;
  }

  FSEventStreamContext ctx = { 0, w, NULL, NULL, NULL };
  uint32_t create_flags =
      kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents;
  w->stream = L.FSEventStreamCreate(
      NULL, on_fs_events, &ctx, paths_arr,
      kFSEventStreamEventIdSinceNow, latency_ms / 1000.0, create_flags);
  L.CFRelease(paths_arr);
  for (int i = 0; i < num_paths; i++) L.CFRelease(strs[i]);
  free(strs);
  if (!w->stream) { free(w); return 0; }

  w->queue = L.dispatch_queue_create("mizchi.x.fs.watch.fsevents", NULL);
  if (!w->queue) {
    L.FSEventStreamRelease(w->stream);
    free(w);
    return 0;
  }
  L.FSEventStreamSetDispatchQueue(w->stream, w->queue);
  if (!L.FSEventStreamStart(w->stream)) {
    if (L.dispatch_release) L.dispatch_release(w->queue);
    L.FSEventStreamInvalidate(w->stream);
    L.FSEventStreamRelease(w->stream);
    free(w);
    return 0;
  }
  return (int64_t)(intptr_t)w;
}

// Pop one event into the caller's buffer.
// Layout written to `out_buf` (size `out_cap`):
//   [0..4)     flags bitmask (uint32 little-endian)
//   [4..4+N)   UTF-8 path bytes (no null terminator)
// Returns N (number of path bytes, may be 0). Returns -1 when the buffer
// can't fit flags + path (caller widens and retries). Returns -2 when no
// events are pending.
MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_fsevents_pop(
    int64_t handle, char *out_buf, int32_t out_cap) {
  if (!handle) return -2;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  pthread_mutex_lock(&w->mu);
  if (w->head == w->tail) {
    pthread_mutex_unlock(&w->mu);
    return -2;
  }
  char *p = w->paths[w->head];
  uint32_t f = w->flags[w->head];
  int plen = p ? (int)strlen(p) : 0;
  if (plen + 4 > out_cap) {
    // Drop the oversize entry so the caller doesn't loop on it forever.
    free(w->paths[w->head]);
    w->paths[w->head] = NULL;
    w->head = (w->head + 1) % RING_CAP;
    pthread_mutex_unlock(&w->mu);
    return -1;
  }
  out_buf[0] = (char)(f & 0xff);
  out_buf[1] = (char)((f >> 8) & 0xff);
  out_buf[2] = (char)((f >> 16) & 0xff);
  out_buf[3] = (char)((f >> 24) & 0xff);
  if (plen > 0) memcpy(out_buf + 4, p, (size_t)plen);
  free(w->paths[w->head]);
  w->paths[w->head] = NULL;
  w->head = (w->head + 1) % RING_CAP;
  pthread_mutex_unlock(&w->mu);
  return plen;
}

// Returns the number of pending events.
MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_fsevents_pending(int64_t handle) {
  if (!handle) return 0;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  pthread_mutex_lock(&w->mu);
  int n = ring_count(w);
  pthread_mutex_unlock(&w->mu);
  return n;
}

MOONBIT_FFI_EXPORT void mizchi_x_watch_fsevents_close(int64_t handle) {
  if (!handle) return;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  if (w->closed) return;
  w->closed = 1;
  if (w->stream && L.FSEventStreamStop) {
    L.FSEventStreamStop(w->stream);
    L.FSEventStreamInvalidate(w->stream);
    L.FSEventStreamRelease(w->stream);
  }
  if (w->queue && L.dispatch_release) {
    L.dispatch_release(w->queue);
  }
  pthread_mutex_lock(&w->mu);
  for (int i = 0; i < RING_CAP; i++) {
    free(w->paths[i]);
    w->paths[i] = NULL;
  }
  pthread_mutex_unlock(&w->mu);
  pthread_mutex_destroy(&w->mu);
  free(w);
}

#else /* !__APPLE__ */

MOONBIT_FFI_EXPORT int64_t mizchi_x_watch_fsevents_start(
    char *paths_buf, int32_t total_len, int32_t num_paths, double latency_ms) {
  (void)paths_buf; (void)total_len; (void)num_paths; (void)latency_ms;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_fsevents_pop(
    int64_t handle, char *out_buf, int32_t out_cap) {
  (void)handle; (void)out_buf; (void)out_cap;
  return -2;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_fsevents_pending(int64_t handle) {
  (void)handle;
  return 0;
}

MOONBIT_FFI_EXPORT void mizchi_x_watch_fsevents_close(int64_t handle) {
  (void)handle;
}

#endif
