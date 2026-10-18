/*
 * Minimal glib replacement for building MLT's LADSPA host (modules/jackrack) on Android.
 * Only the handful of functions that module uses.  SPDX-License-Identifier: LGPL-2.1-or-later
 */
#ifndef GLIB_SHIM_H
#define GLIB_SHIM_H

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int gboolean;
typedef int gint;
typedef unsigned int guint;
typedef uint32_t guint32;
typedef void *gpointer;
typedef const void *gconstpointer;
typedef char gchar;
typedef int (*GCompareFunc)(gconstpointer a, gconstpointer b);

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#define g_malloc(n) malloc(n)
#define g_malloc0(n) calloc(1, (n))
#define g_realloc(p, n) realloc((p), (n))
#define g_free(p) free(p)

#define g_return_if_fail(expr) \
    do { \
        if (!(expr)) \
            return; \
    } while (0)
#define g_return_val_if_fail(expr, val) \
    do { \
        if (!(expr)) \
            return (val); \
    } while (0)

static inline char *g_strdup(const char *s)
{
    return s ? strdup(s) : NULL;
}

static inline char *g_strndup(const char *s, size_t n)
{
    if (!s)
        return NULL;
    size_t len = strnlen(s, n);
    char *r = malloc(len + 1);
    if (r) {
        memcpy(r, s, len);
        r[len] = '\0';
    }
    return r;
}

static inline char *g_strdup_printf(const char *fmt, ...)
{
    va_list ap, ap2;
    va_start(ap, fmt);
    va_copy(ap2, ap);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *r = n >= 0 ? malloc((size_t) n + 1) : NULL;
    if (r)
        vsnprintf(r, (size_t) n + 1, fmt, ap2);
    va_end(ap2);
    return r;
}

typedef struct _GSList GSList;
struct _GSList
{
    gpointer data;
    GSList *next;
};
#define g_slist_next(l) ((l) ? (l)->next : NULL)

static inline GSList *g_slist_append(GSList *list, gpointer data)
{
    GSList *node = malloc(sizeof(GSList));
    node->data = data;
    node->next = NULL;
    if (!list)
        return node;
    GSList *last = list;
    while (last->next)
        last = last->next;
    last->next = node;
    return list;
}

static inline void g_slist_free(GSList *list)
{
    while (list) {
        GSList *next = list->next;
        free(list);
        list = next;
    }
}

static inline GSList *g_slist_remove(GSList *list, gconstpointer data)
{
    GSList *prev = NULL, *cur = list;
    while (cur) {
        if (cur->data == data) {
            if (prev)
                prev->next = cur->next;
            else
                list = cur->next;
            free(cur);
            break;
        }
        prev = cur;
        cur = cur->next;
    }
    return list;
}

/* stable insertion-free merge sort via array */
static inline GSList *g_slist_sort(GSList *list, GCompareFunc cmp)
{
    size_t n = 0;
    for (GSList *l = list; l; l = l->next)
        n++;
    if (n < 2)
        return list;
    GSList **arr = malloc(n * sizeof(GSList *));
    size_t i = 0;
    for (GSList *l = list; l; l = l->next)
        arr[i++] = l;
    /* insertion sort: lists here hold at most a few hundred plugins and the sort is stable */
    for (i = 1; i < n; i++) {
        GSList *key = arr[i];
        size_t j = i;
        while (j > 0 && cmp(arr[j - 1]->data, key->data) > 0) {
            arr[j] = arr[j - 1];
            j--;
        }
        arr[j] = key;
    }
    for (i = 0; i + 1 < n; i++)
        arr[i]->next = arr[i + 1];
    arr[n - 1]->next = NULL;
    GSList *head = arr[0];
    free(arr);
    return head;
}

typedef struct _GList GList;
struct _GList
{
    gpointer data;
    GList *next;
    GList *prev;
};
#define g_list_next(l) ((l) ? (l)->next : NULL)

#endif
