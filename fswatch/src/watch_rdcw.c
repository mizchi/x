#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32

#include <windows.h>

/*
 * ReadDirectoryChangesW-backed watcher. One HANDLE per root opened with
 * FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED. Each root has its own
 * OVERLAPPED + manual-reset event; a single reader thread blocks on
 * WaitForMultipleObjects across all root events plus a stop event.
 *
 * Recursive watching is built-in via bWatchSubtree=TRUE; no per-subdir
 * fix-up is needed (unlike inotify).
 *
 * On non-Windows the start FFI returns 0 and the MoonBit caller falls
 * through to the next backend.
 */

#define RING_CAP 4096
#define BUF_SIZE 16384

typedef struct root_handle {
  HANDLE dir;
  OVERLAPPED ov;
  HANDLE event;
  uint8_t buf[BUF_SIZE];
  char *root_path; /* UTF-8, no trailing slash */
  struct root_handle *next;
} root_handle_t;

typedef struct {
  CRITICAL_SECTION cs;
  root_handle_t *roots;
  HANDLE thread;
  HANDLE stop_event;
  volatile LONG stop;
  char *paths[RING_CAP];
  uint32_t flags[RING_CAP];
  int head;
  int tail;
  int dropped;
  int closed;
} watcher_t;

/* Caller holds w->cs. */
static void push_event_locked(watcher_t *w, const char *path, uint32_t flags) {
  int next = (w->tail + 1) % RING_CAP;
  if (next == w->head) {
    w->dropped++;
    return;
  }
  free(w->paths[w->tail]);
  w->paths[w->tail] = _strdup(path);
  w->flags[w->tail] = flags;
  w->tail = next;
}

static wchar_t *utf8_to_utf16(const char *utf8) {
  int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
  if (wlen <= 0) return NULL;
  wchar_t *out = (wchar_t *)malloc((size_t)wlen * sizeof(wchar_t));
  if (!out) return NULL;
  if (MultiByteToWideChar(CP_UTF8, 0, utf8, -1, out, wlen) <= 0) {
    free(out);
    return NULL;
  }
  return out;
}

static int utf16_to_utf8(const wchar_t *wide, int wide_len, char *out, int out_cap) {
  /* wide_len is character count, not including a null. WideCharToMultiByte
   * with cbMultiByte=out_cap-1 leaves room for our own null. */
  int n = WideCharToMultiByte(CP_UTF8, 0, wide, wide_len, out, out_cap - 1, NULL, NULL);
  if (n < 0) return 0;
  out[n] = 0;
  return n;
}

static int issue_read(root_handle_t *r) {
  DWORD filter = FILE_NOTIFY_CHANGE_FILE_NAME |
                 FILE_NOTIFY_CHANGE_DIR_NAME |
                 FILE_NOTIFY_CHANGE_ATTRIBUTES |
                 FILE_NOTIFY_CHANGE_SIZE |
                 FILE_NOTIFY_CHANGE_LAST_WRITE |
                 FILE_NOTIFY_CHANGE_CREATION;
  ResetEvent(r->event);
  ZeroMemory(&r->ov, sizeof(OVERLAPPED));
  r->ov.hEvent = r->event;
  BOOL ok = ReadDirectoryChangesW(r->dir, r->buf, BUF_SIZE, TRUE,
                                  filter, NULL, &r->ov, NULL);
  return ok ? 1 : 0;
}

static DWORD WINAPI reader_thread(LPVOID arg) {
  watcher_t *w = (watcher_t *)arg;
  /* MAXIMUM_WAIT_OBJECTS is 64; we reserve one slot for stop_event. */
  HANDLE events[MAXIMUM_WAIT_OBJECTS];
  root_handle_t *roots_array[MAXIMUM_WAIT_OBJECTS];

  while (InterlockedCompareExchange(&w->stop, 0, 0) == 0) {
    EnterCriticalSection(&w->cs);
    int n = 0;
    for (root_handle_t *r = w->roots; r && n < MAXIMUM_WAIT_OBJECTS - 1; r = r->next) {
      events[n] = r->event;
      roots_array[n] = r;
      n++;
    }
    events[n] = w->stop_event;
    LeaveCriticalSection(&w->cs);

    DWORD ret = WaitForMultipleObjects((DWORD)(n + 1), events, FALSE, INFINITE);
    if (InterlockedCompareExchange(&w->stop, 0, 0) != 0) break;
    if (ret == (DWORD)(WAIT_OBJECT_0 + n)) break;
    if (ret < WAIT_OBJECT_0 || ret >= (DWORD)(WAIT_OBJECT_0 + n)) continue;

    int idx = (int)(ret - WAIT_OBJECT_0);
    root_handle_t *r = roots_array[idx];

    DWORD bytes = 0;
    if (!GetOverlappedResult(r->dir, &r->ov, &bytes, FALSE) || bytes == 0) {
      /* Re-arm without consuming; the buffer may have overflowed (bytes==0)
       * in which case the caller's known-file walk will pick up the truth. */
      EnterCriticalSection(&w->cs);
      issue_read(r);
      LeaveCriticalSection(&w->cs);
      continue;
    }

    EnterCriticalSection(&w->cs);
    uint8_t *p = r->buf;
    uint8_t *end = r->buf + bytes;
    while (p + sizeof(FILE_NOTIFY_INFORMATION) <= end) {
      FILE_NOTIFY_INFORMATION *fni = (FILE_NOTIFY_INFORMATION *)p;
      int wide_len = (int)(fni->FileNameLength / sizeof(WCHAR));
      char rel[1024];
      int rn = utf16_to_utf8(fni->FileName, wide_len, rel, (int)sizeof(rel));
      if (rn > 0) {
        char full[2048];
        int fn = _snprintf_s(full, sizeof(full), _TRUNCATE, "%s/%s", r->root_path, rel);
        if (fn > 0) {
          /* Normalize to forward slashes so events match the user's roots
           * regardless of the OS path separator they passed. */
          for (char *q = full; *q; q++) if (*q == '\\') *q = '/';
          push_event_locked(w, full, (uint32_t)fni->Action);
        }
      }
      if (fni->NextEntryOffset == 0) break;
      uint32_t off = fni->NextEntryOffset;
      if (off == 0 || p + off > end) break;
      p += off;
    }
    issue_read(r);
    LeaveCriticalSection(&w->cs);
  }
  return 0;
}

MOONBIT_FFI_EXPORT int64_t mizchi_x_watch_rdcw_start(
    char *paths_buf, int32_t total_len, int32_t num_paths) {
  if (num_paths <= 0) return 0;
  if (num_paths > MAXIMUM_WAIT_OBJECTS - 1) return 0;

  watcher_t *w = (watcher_t *)calloc(1, sizeof(watcher_t));
  if (!w) return 0;
  InitializeCriticalSection(&w->cs);
  w->stop_event = CreateEventW(NULL, TRUE, FALSE, NULL);
  if (!w->stop_event) {
    DeleteCriticalSection(&w->cs);
    free(w);
    return 0;
  }

  int pos = 0;
  int added = 0;
  for (int i = 0; i < num_paths && pos < total_len; i++) {
    int start = pos;
    while (pos < total_len && paths_buf[pos] != 0) pos++;
    int len = pos - start;
    char tmp[1024];
    if (len >= (int)sizeof(tmp)) len = (int)sizeof(tmp) - 1;
    memcpy(tmp, paths_buf + start, (size_t)len);
    tmp[len] = 0;
    if (pos < total_len) pos++;

    wchar_t *wpath = utf8_to_utf16(tmp);
    if (!wpath) continue;
    HANDLE dir = CreateFileW(
        wpath, FILE_LIST_DIRECTORY,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED, NULL);
    free(wpath);
    if (dir == INVALID_HANDLE_VALUE) continue;

    root_handle_t *r = (root_handle_t *)calloc(1, sizeof(root_handle_t));
    if (!r) { CloseHandle(dir); continue; }
    r->dir = dir;
    r->event = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!r->event) { CloseHandle(dir); free(r); continue; }
    r->root_path = _strdup(tmp);
    /* Strip a trailing slash or backslash so we don't emit "<root>//file". */
    if (r->root_path) {
      size_t rl = strlen(r->root_path);
      while (rl > 1 && (r->root_path[rl - 1] == '/' || r->root_path[rl - 1] == '\\')) {
        r->root_path[--rl] = 0;
      }
    }
    if (!issue_read(r)) {
      CloseHandle(r->event);
      CloseHandle(r->dir);
      free(r->root_path);
      free(r);
      continue;
    }

    EnterCriticalSection(&w->cs);
    r->next = w->roots;
    w->roots = r;
    LeaveCriticalSection(&w->cs);
    added++;
  }

  if (added == 0) {
    CloseHandle(w->stop_event);
    DeleteCriticalSection(&w->cs);
    free(w);
    return 0;
  }

  w->thread = CreateThread(NULL, 0, reader_thread, w, 0, NULL);
  if (!w->thread) {
    /* Tear down what we built. */
    EnterCriticalSection(&w->cs);
    while (w->roots) {
      root_handle_t *next = w->roots->next;
      CancelIoEx(w->roots->dir, &w->roots->ov);
      CloseHandle(w->roots->event);
      CloseHandle(w->roots->dir);
      free(w->roots->root_path);
      free(w->roots);
      w->roots = next;
    }
    LeaveCriticalSection(&w->cs);
    CloseHandle(w->stop_event);
    DeleteCriticalSection(&w->cs);
    free(w);
    return 0;
  }
  return (int64_t)(intptr_t)w;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_rdcw_pop(
    int64_t handle, char *out_buf, int32_t out_cap) {
  if (!handle) return -2;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  EnterCriticalSection(&w->cs);
  if (w->head == w->tail) {
    LeaveCriticalSection(&w->cs);
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
    LeaveCriticalSection(&w->cs);
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
  LeaveCriticalSection(&w->cs);
  return plen;
}

MOONBIT_FFI_EXPORT void mizchi_x_watch_rdcw_close(int64_t handle) {
  if (!handle) return;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  if (w->closed) return;
  w->closed = 1;
  InterlockedExchange(&w->stop, 1);
  SetEvent(w->stop_event);
  if (w->thread) {
    WaitForSingleObject(w->thread, INFINITE);
    CloseHandle(w->thread);
    w->thread = NULL;
  }
  EnterCriticalSection(&w->cs);
  while (w->roots) {
    root_handle_t *next = w->roots->next;
    CancelIoEx(w->roots->dir, &w->roots->ov);
    CloseHandle(w->roots->event);
    CloseHandle(w->roots->dir);
    free(w->roots->root_path);
    free(w->roots);
    w->roots = next;
  }
  for (int i = 0; i < RING_CAP; i++) {
    free(w->paths[i]);
    w->paths[i] = NULL;
  }
  LeaveCriticalSection(&w->cs);
  CloseHandle(w->stop_event);
  DeleteCriticalSection(&w->cs);
  free(w);
}

#else /* !_WIN32 */

MOONBIT_FFI_EXPORT int64_t mizchi_x_watch_rdcw_start(
    char *paths_buf, int32_t total_len, int32_t num_paths) {
  (void)paths_buf; (void)total_len; (void)num_paths;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_rdcw_pop(
    int64_t handle, char *out_buf, int32_t out_cap) {
  (void)handle; (void)out_buf; (void)out_cap;
  return -2;
}

MOONBIT_FFI_EXPORT void mizchi_x_watch_rdcw_close(int64_t handle) {
  (void)handle;
}

#endif
