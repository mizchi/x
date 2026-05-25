#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __linux__

#include <sys/inotify.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>

/*
 * inotify-backed watcher. One inotify fd per Watcher; a single reader
 * thread blocks on read(2) and pushes (path, mask) into the mutex-
 * protected ringbuffer. The MoonBit watcher polls drain() at watcher-
 * tick cadence; the kernel-side detection itself is real-time.
 *
 * Recursive watching: walk each root at start and add a watch per
 * directory. On IN_CREATE | IN_ISDIR the reader adds a new watch
 * recursively so deeply-nested new directories are caught.
 *
 * On non-Linux platforms `start` returns 0 and the MoonBit caller
 * falls through to the next backend.
 */

#define RING_CAP 4096
#define IN_EVENT_MASK (IN_CREATE | IN_MODIFY | IN_DELETE | \
                       IN_MOVED_FROM | IN_MOVED_TO | IN_ATTRIB | \
                       IN_DELETE_SELF | IN_MOVE_SELF)

typedef struct wd_entry {
  int wd;
  char *path; // absolute directory path
  struct wd_entry *next;
} wd_entry_t;

typedef struct {
  pthread_mutex_t mu;
  int fd;
  wd_entry_t *entries;
  pthread_t reader;
  int reader_running;
  int stop;
  // ringbuffer
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

// Caller holds w->mu.
static void push_event_locked(watcher_t *w, const char *path, uint32_t mask) {
  int next = (w->tail + 1) % RING_CAP;
  if (next == w->head) {
    w->dropped++;
    return;
  }
  free(w->paths[w->tail]);
  w->paths[w->tail] = strdup(path);
  w->flags[w->tail] = mask;
  w->tail = next;
}

// Caller holds w->mu.
static void add_entry_locked(watcher_t *w, int wd, const char *path) {
  wd_entry_t *e = (wd_entry_t *)calloc(1, sizeof(wd_entry_t));
  if (!e) return;
  e->wd = wd;
  e->path = strdup(path);
  e->next = w->entries;
  w->entries = e;
}

// Caller holds w->mu. Returns NULL if not found.
static const char *find_path_locked(watcher_t *w, int wd) {
  for (wd_entry_t *e = w->entries; e; e = e->next) {
    if (e->wd == wd) return e->path;
  }
  return NULL;
}

// Caller holds w->mu.
static void remove_entry_locked(watcher_t *w, int wd) {
  wd_entry_t **pp = &w->entries;
  while (*pp) {
    if ((*pp)->wd == wd) {
      wd_entry_t *dead = *pp;
      *pp = dead->next;
      free(dead->path);
      free(dead);
      return;
    }
    pp = &(*pp)->next;
  }
}

// Recursively add inotify watches for `path` and all sub-directories.
// Caller holds w->mu.
static void add_recursive_locked(watcher_t *w, const char *path) {
  int wd = inotify_add_watch(w->fd, path, IN_EVENT_MASK);
  if (wd < 0) return;
  add_entry_locked(w, wd, path);
  DIR *d = opendir(path);
  if (!d) return;
  struct dirent *de;
  while ((de = readdir(d))) {
    if (de->d_name[0] == '.' &&
        (de->d_name[1] == 0 ||
         (de->d_name[1] == '.' && de->d_name[2] == 0))) continue;
    char child[4096];
    int n = snprintf(child, sizeof(child), "%s/%s", path, de->d_name);
    if (n <= 0 || n >= (int)sizeof(child)) continue;
    int is_dir = 0;
    if (de->d_type == DT_DIR) {
      is_dir = 1;
    } else if (de->d_type == DT_UNKNOWN) {
      struct stat st;
      if (stat(child, &st) == 0 && S_ISDIR(st.st_mode)) is_dir = 1;
    }
    if (is_dir) add_recursive_locked(w, child);
  }
  closedir(d);
}

static void *reader_loop(void *arg) {
  watcher_t *w = (watcher_t *)arg;
  char buf[4096] __attribute__((aligned(__alignof__(struct inotify_event))));
  while (!w->stop) {
    ssize_t n = read(w->fd, buf, sizeof(buf));
    if (n < 0) {
      if (errno == EINTR) continue;
      break;
    }
    if (n == 0) break;
    char *p = buf;
    while (p < buf + n) {
      struct inotify_event *e = (struct inotify_event *)p;
      pthread_mutex_lock(&w->mu);
      const char *dir = find_path_locked(w, e->wd);
      if (dir) {
        char full[4096];
        if (e->len > 0) {
          snprintf(full, sizeof(full), "%s/%s", dir, e->name);
        } else {
          snprintf(full, sizeof(full), "%s", dir);
        }
        push_event_locked(w, full, (uint32_t)e->mask);
        if ((e->mask & IN_CREATE) && (e->mask & IN_ISDIR) && e->len > 0) {
          add_recursive_locked(w, full);
        }
        if (e->mask & (IN_IGNORED | IN_DELETE_SELF | IN_MOVE_SELF)) {
          remove_entry_locked(w, e->wd);
        }
      }
      pthread_mutex_unlock(&w->mu);
      p += sizeof(struct inotify_event) + e->len;
    }
  }
  return NULL;
}

MOONBIT_FFI_EXPORT int64_t mizchi_x_watch_inotify_start(
    char *paths_buf, int32_t total_len, int32_t num_paths) {
  if (num_paths <= 0) return 0;
  int fd = inotify_init1(IN_CLOEXEC);
  if (fd < 0) return 0;

  watcher_t *w = (watcher_t *)calloc(1, sizeof(watcher_t));
  if (!w) { close(fd); return 0; }
  pthread_mutex_init(&w->mu, NULL);
  w->fd = fd;

  // Decode null-separated paths and add recursive watches.
  pthread_mutex_lock(&w->mu);
  int pos = 0;
  int added = 0;
  for (int i = 0; i < num_paths && pos < total_len; i++) {
    int start = pos;
    while (pos < total_len && paths_buf[pos] != 0) pos++;
    int len = pos - start;
    char tmp[4096];
    if (len >= (int)sizeof(tmp)) len = (int)sizeof(tmp) - 1;
    memcpy(tmp, paths_buf + start, (size_t)len);
    tmp[len] = 0;
    struct stat st;
    if (stat(tmp, &st) == 0 && S_ISDIR(st.st_mode)) {
      add_recursive_locked(w, tmp);
      added++;
    }
    if (pos < total_len) pos++;
  }
  pthread_mutex_unlock(&w->mu);

  if (added == 0) {
    close(fd);
    free(w);
    return 0;
  }

  if (pthread_create(&w->reader, NULL, reader_loop, w) != 0) {
    pthread_mutex_lock(&w->mu);
    while (w->entries) {
      wd_entry_t *next = w->entries->next;
      free(w->entries->path);
      free(w->entries);
      w->entries = next;
    }
    pthread_mutex_unlock(&w->mu);
    close(fd);
    free(w);
    return 0;
  }
  w->reader_running = 1;
  return (int64_t)(intptr_t)w;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_inotify_pop(
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

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_inotify_pending(int64_t handle) {
  if (!handle) return 0;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  pthread_mutex_lock(&w->mu);
  int n = ring_count(w);
  pthread_mutex_unlock(&w->mu);
  return n;
}

MOONBIT_FFI_EXPORT void mizchi_x_watch_inotify_close(int64_t handle) {
  if (!handle) return;
  watcher_t *w = (watcher_t *)(intptr_t)handle;
  if (w->closed) return;
  w->closed = 1;
  w->stop = 1;
  // close() makes the blocking read(2) in the reader thread return 0.
  if (w->fd >= 0) {
    close(w->fd);
    w->fd = -1;
  }
  if (w->reader_running) {
    pthread_join(w->reader, NULL);
    w->reader_running = 0;
  }
  pthread_mutex_lock(&w->mu);
  while (w->entries) {
    wd_entry_t *next = w->entries->next;
    free(w->entries->path);
    free(w->entries);
    w->entries = next;
  }
  for (int i = 0; i < RING_CAP; i++) {
    free(w->paths[i]);
    w->paths[i] = NULL;
  }
  pthread_mutex_unlock(&w->mu);
  pthread_mutex_destroy(&w->mu);
  free(w);
}

#else /* !__linux__ */

MOONBIT_FFI_EXPORT int64_t mizchi_x_watch_inotify_start(
    char *paths_buf, int32_t total_len, int32_t num_paths) {
  (void)paths_buf; (void)total_len; (void)num_paths;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_inotify_pop(
    int64_t handle, char *out_buf, int32_t out_cap) {
  (void)handle; (void)out_buf; (void)out_cap;
  return -2;
}

MOONBIT_FFI_EXPORT int32_t mizchi_x_watch_inotify_pending(int64_t handle) {
  (void)handle;
  return 0;
}

MOONBIT_FFI_EXPORT void mizchi_x_watch_inotify_close(int64_t handle) {
  (void)handle;
}

#endif
