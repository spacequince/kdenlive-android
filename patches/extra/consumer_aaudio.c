/*
 * consumer_aaudio.c -- Android AAudio audio/video-timing consumer for MLT
 *
 * Derived from MLT's consumer_sdl2_audio.c (Copyright (C) 2009-2026 Meltytech, LLC),
 * with the SDL audio device replaced by an AAudio output stream.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 */

#include <aaudio/AAudio.h>
#include <framework/mlt_consumer.h>
#include <framework/mlt_deque.h>
#include <framework/mlt_factory.h>
#include <framework/mlt_filter.h>
#include <framework/mlt_frame.h>
#include <framework/mlt_log.h>
#include <framework/mlt_repository.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

typedef struct consumer_aaudio_s *consumer_aaudio;

struct consumer_aaudio_s
{
    struct mlt_consumer_s parent;
    mlt_properties properties;
    mlt_deque queue;
    pthread_t thread;
    int joined;
    atomic_int running;
    uint8_t *audio_buffer;
    int audio_buffer_size;
    int audio_avail;
    pthread_mutex_t audio_mutex;
    pthread_cond_t audio_cond;
    pthread_mutex_t video_mutex;
    pthread_cond_t video_cond;
    int out_channels;
    AAudioStream *stream;

    pthread_cond_t refresh_cond;
    pthread_mutex_t refresh_mutex;
    int refresh_count;
    int is_purge;
};

static int consumer_start(mlt_consumer parent);
static int consumer_stop(mlt_consumer parent);
static int consumer_is_stopped(mlt_consumer parent);
static void consumer_purge(mlt_consumer parent);
static void consumer_close(mlt_consumer parent);
static void *consumer_thread(void *);
static void consumer_refresh_cb(mlt_consumer self, mlt_consumer parent, mlt_event_data);

mlt_consumer consumer_aaudio_init(mlt_profile profile, mlt_service_type type, const char *id, char *arg)
{
    consumer_aaudio self = calloc(1, sizeof(struct consumer_aaudio_s));

    if (self != NULL && mlt_consumer_init(&self->parent, self, profile) == 0) {
        self->queue = mlt_deque_init();
        mlt_consumer parent = &self->parent;
        parent->close = consumer_close;

        mlt_service service = MLT_CONSUMER_SERVICE(parent);
        self->properties = MLT_SERVICE_PROPERTIES(service);

        mlt_properties_set_double(self->properties, "volume", 1.0);

        pthread_mutex_init(&self->audio_mutex, NULL);
        pthread_cond_init(&self->audio_cond, NULL);
        pthread_mutex_init(&self->video_mutex, NULL);
        pthread_cond_init(&self->video_cond, NULL);

        mlt_properties_set(self->properties, "rescale", "nearest");
        mlt_properties_set(self->properties, "consumer.deinterlacer", "onefield");
        mlt_properties_set_int(self->properties, "top_field_first", -1);
        mlt_properties_set_int(self->properties, "buffer", 1);
        mlt_properties_set_int(self->properties, "audio_buffer", 4096);

        self->joined = 1;

        parent->start = consumer_start;
        parent->stop = consumer_stop;
        parent->is_stopped = consumer_is_stopped;
        parent->purge = consumer_purge;

        pthread_cond_init(&self->refresh_cond, NULL);
        pthread_mutex_init(&self->refresh_mutex, NULL);
        mlt_events_listen(MLT_CONSUMER_PROPERTIES(parent),
                          self,
                          "property-changed",
                          (mlt_listener) consumer_refresh_cb);
        return parent;
    }

    free(self);
    return NULL;
}

static void consumer_refresh_cb(mlt_consumer unused, mlt_consumer parent, mlt_event_data event_data)
{
    const char *name = mlt_event_data_to_string(event_data);
    if (name && !strcmp(name, "refresh")) {
        consumer_aaudio self = parent->child;
        pthread_mutex_lock(&self->refresh_mutex);
        if (self->refresh_count < 2)
            self->refresh_count = self->refresh_count <= 0 ? 1 : self->refresh_count + 1;
        pthread_cond_broadcast(&self->refresh_cond);
        pthread_mutex_unlock(&self->refresh_mutex);
    }
}

static int consumer_start(mlt_consumer parent)
{
    consumer_aaudio self = parent->child;

    if (!self->running) {
        consumer_stop(parent);
        self->running = 1;
        self->joined = 0;
        pthread_create(&self->thread, NULL, consumer_thread, self);
    }
    return 0;
}

static void close_stream(consumer_aaudio self)
{
    if (self->stream) {
        AAudioStream_requestStop(self->stream);
        AAudioStream_close(self->stream);
        self->stream = NULL;
    }
}

static int consumer_stop(mlt_consumer parent)
{
    consumer_aaudio self = parent->child;

    if (self->running && !self->joined) {
        self->joined = 1;
        self->running = 0;

        pthread_mutex_lock(&self->refresh_mutex);
        pthread_cond_broadcast(&self->refresh_cond);
        pthread_mutex_unlock(&self->refresh_mutex);

        if (self->thread)
            pthread_join(self->thread, NULL);

        pthread_mutex_lock(&self->video_mutex);
        pthread_cond_broadcast(&self->video_cond);
        pthread_mutex_unlock(&self->video_mutex);

        pthread_mutex_lock(&self->audio_mutex);
        pthread_cond_broadcast(&self->audio_cond);
        pthread_mutex_unlock(&self->audio_mutex);

        close_stream(self);
    }
    return 0;
}

static int consumer_is_stopped(mlt_consumer parent)
{
    consumer_aaudio self = parent->child;
    return !self->running;
}

static void consumer_purge(mlt_consumer parent)
{
    consumer_aaudio self = parent->child;
    if (self->running) {
        pthread_mutex_lock(&self->video_mutex);
        mlt_frame frame = MLT_FRAME(mlt_deque_peek_back(self->queue));
        double speed = frame ? mlt_properties_get_double(MLT_FRAME_PROPERTIES(frame), "_speed") : 0;
        int n = (speed == 0.0 || speed == 1.0) ? 0 : 1;
        while (mlt_deque_count(self->queue) > n)
            mlt_frame_close(mlt_deque_pop_back(self->queue));
        self->is_purge = 1;
        pthread_cond_broadcast(&self->video_cond);
        pthread_mutex_unlock(&self->video_mutex);
    }
}

/* AAudio real-time callback: hand over queued samples, pad with silence */
static aaudio_data_callback_result_t aaudio_fill(AAudioStream *stream,
                                                 void *userdata,
                                                 void *audio_data,
                                                 int32_t num_frames)
{
    consumer_aaudio self = userdata;
    uint8_t *out = audio_data;
    int len = num_frames * self->out_channels * (int) sizeof(float);
    double volume = mlt_properties_get_double(self->properties, "volume");

    memset(out, 0, len);

    pthread_mutex_lock(&self->audio_mutex);
    int bytes = MIN(len, self->audio_avail);
    if (volume != 1.0) {
        float *src = (float *) self->audio_buffer;
        float *dst = (float *) out;
        int n = bytes / (int) sizeof(float);
        for (int i = 0; i < n; i++)
            dst[i] = (float) volume * src[i];
    } else {
        memcpy(out, self->audio_buffer, bytes);
    }
    self->audio_avail -= bytes;
    memmove(self->audio_buffer, self->audio_buffer + bytes, self->audio_avail);
    pthread_cond_broadcast(&self->audio_cond);
    pthread_mutex_unlock(&self->audio_mutex);

    return AAUDIO_CALLBACK_RESULT_CONTINUE;
}

static int open_stream(consumer_aaudio self, int channels, int frequency)
{
    AAudioStreamBuilder *builder = NULL;
    if (AAudio_createStreamBuilder(&builder) != AAUDIO_OK)
        return -1;
    AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_OUTPUT);
    AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
    AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_SHARED);
    AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_FLOAT);
    AAudioStreamBuilder_setChannelCount(builder, channels);
    AAudioStreamBuilder_setSampleRate(builder, frequency);
    AAudioStreamBuilder_setUsage(builder, AAUDIO_USAGE_MEDIA);
    AAudioStreamBuilder_setContentType(builder, AAUDIO_CONTENT_TYPE_MOVIE);
    AAudioStreamBuilder_setDataCallback(builder, aaudio_fill, self);

    aaudio_result_t r = AAudioStreamBuilder_openStream(builder, &self->stream);
    AAudioStreamBuilder_delete(builder);
    if (r != AAUDIO_OK) {
        mlt_log_error(MLT_CONSUMER_SERVICE(&self->parent), "AAudio open failed: %s\n", AAudio_convertResultToText(r));
        self->stream = NULL;
        return -1;
    }
    self->out_channels = AAudioStream_getChannelCount(self->stream);
    mlt_log_info(MLT_CONSUMER_SERVICE(&self->parent),
                 "AAudio opened: channels=%d frequency=%d burst=%d\n",
                 self->out_channels,
                 AAudioStream_getSampleRate(self->stream),
                 AAudioStream_getFramesPerBurst(self->stream));
    return 0;
}

static int consumer_play_audio(consumer_aaudio self, mlt_frame frame, int init_audio, int64_t *duration)
{
    mlt_properties properties = self->properties;
    mlt_audio_format afmt = mlt_audio_f32le;

    int channels = mlt_properties_get_int(properties, "channels");
    int frequency = mlt_properties_get_int(properties, "frequency");
    int scrub = mlt_properties_get_int(properties, "scrub_audio");
    static int counter = 0;

    int samples = mlt_audio_calculate_frame_samples(mlt_properties_get_double(self->properties, "fps"),
                                                    frequency,
                                                    counter++);
    float *pcm;
    mlt_frame_get_audio(frame, (void **) &pcm, &afmt, &frequency, &channels, &samples);
    *duration = 1000000LL * samples / frequency;
    pcm += mlt_properties_get_int(properties, "audio_offset");

    if (mlt_properties_get_int(properties, "audio_off")) {
        init_audio = 1;
        return init_audio;
    }

    if (init_audio == 1) {
        int audio_buffer = mlt_properties_get_int(properties, "audio_buffer");
        if (open_stream(self, mlt_properties_get_int(properties, "channels"), frequency) != 0) {
            init_audio = 2;
        } else {
            int queue_size = audio_buffer * self->out_channels * (int) sizeof(float);
            if (queue_size < 8192)
                queue_size = 8192;
            uint8_t *buf = realloc(self->audio_buffer, queue_size);
            if (!buf) {
                mlt_log_error(MLT_CONSUMER_SERVICE(self), "Failed to allocate audio queue\n");
                close_stream(self);
                return 2;
            }
            self->audio_buffer = buf;
            self->audio_buffer_size = queue_size;
            self->audio_avail = 0;
            AAudioStream_requestStart(self->stream);
            init_audio = 0;
        }
    }

    if (init_audio == 0) {
        mlt_properties fprops = MLT_FRAME_PROPERTIES(frame);
        int samples_copied = 0;
        int dst_stride = self->out_channels * sizeof(*pcm);

        pthread_mutex_lock(&self->audio_mutex);

        while (self->running && samples_copied < samples) {
            int sample_space = (self->audio_buffer_size - self->audio_avail) / dst_stride;
            while (self->running && sample_space == 0) {
                struct timeval now;
                struct timespec tm;

                gettimeofday(&now, NULL);
                tm.tv_sec = now.tv_sec + 1;
                tm.tv_nsec = now.tv_usec * 1000;
                pthread_cond_timedwait(&self->audio_cond, &self->audio_mutex, &tm);
                sample_space = (self->audio_buffer_size - self->audio_avail) / dst_stride;

                if (sample_space == 0) {
                    mlt_log_warning(MLT_CONSUMER_SERVICE(&self->parent), "audio timed out\n");
                    pthread_mutex_unlock(&self->audio_mutex);
                    return 1;
                }
            }
            if (self->running) {
                int samples_to_copy = samples - samples_copied;
                if (samples_to_copy > sample_space)
                    samples_to_copy = sample_space;
                int dst_bytes = samples_to_copy * dst_stride;

                if (scrub || mlt_properties_get_double(fprops, "_speed") == 1) {
                    if (channels == self->out_channels) {
                        memcpy(&self->audio_buffer[self->audio_avail], pcm, dst_bytes);
                        pcm += samples_to_copy * channels;
                    } else {
                        float *dest = (float *) &self->audio_buffer[self->audio_avail];
                        int i = samples_to_copy + 1;
                        while (--i) {
                            memcpy(dest, pcm, dst_stride);
                            pcm += channels;
                            dest += self->out_channels;
                        }
                    }
                } else {
                    memset(&self->audio_buffer[self->audio_avail], 0, dst_bytes);
                    pcm += samples_to_copy * channels;
                }
                self->audio_avail += dst_bytes;
                samples_copied += samples_to_copy;
            }
            pthread_cond_broadcast(&self->audio_cond);
        }
        pthread_mutex_unlock(&self->audio_mutex);
    }

    return init_audio;
}

static int consumer_play_video(consumer_aaudio self, mlt_frame frame)
{
    mlt_events_fire(self->properties, "consumer-frame-show", mlt_event_data_from_frame(frame));
    return 0;
}

static void *video_thread(void *arg)
{
    consumer_aaudio self = arg;

    struct timeval now;
    int64_t start = 0;
    int64_t elapsed = 0;
    struct timespec tm;
    mlt_frame next = NULL;
    mlt_properties properties = NULL;
    double speed = 0;

    int real_time = mlt_properties_get_int(self->properties, "real_time");

    gettimeofday(&now, NULL);
    start = (int64_t) now.tv_sec * 1000000 + now.tv_usec;

    while (self->running) {
        pthread_mutex_lock(&self->video_mutex);
        next = mlt_deque_pop_front(self->queue);
        while (next == NULL && self->running) {
            pthread_cond_wait(&self->video_cond, &self->video_mutex);
            next = mlt_deque_pop_front(self->queue);
        }
        pthread_mutex_unlock(&self->video_mutex);

        if (!self->running || next == NULL) {
            if (self->running) {
                mlt_log_warning(MLT_CONSUMER_SERVICE(&self->parent),
                                "video thread got a null frame even though the consumer is still running!\n");
            }
            break;
        }

        properties = MLT_FRAME_PROPERTIES(next);
        speed = mlt_properties_get_double(properties, "_speed");

        gettimeofday(&now, NULL);
        elapsed = ((int64_t) now.tv_sec * 1000000 + now.tv_usec) - start;

        if (mlt_properties_get_int(properties, "rendered") == 1) {
            int64_t scheduled = mlt_properties_get_int64(properties, "playtime");
            int64_t difference = scheduled - elapsed;

            if (real_time && (difference > 20000 && speed == 1.0)) {
                tm.tv_sec = difference / 1000000;
                tm.tv_nsec = (difference % 1000000) * 1000;
                nanosleep(&tm, NULL);
            }

            if (!real_time || (difference > -10000 || speed != 1.0 || mlt_deque_count(self->queue) < 2))
                consumer_play_video(self, next);

            if (real_time && (mlt_deque_count(self->queue) == 0 && speed == 1.0)) {
                gettimeofday(&now, NULL);
                start = ((int64_t) now.tv_sec * 1000000 + now.tv_usec) - scheduled + 20000;
                start += mlt_properties_get_int(self->properties, "video_delay") * 1000;
            }
        }

        mlt_frame_close(next);
        next = NULL;
    }

    if (next != NULL) {
        consumer_play_video(self, next);
        mlt_frame_close(next);
        next = NULL;
    }
    while (mlt_deque_count(self->queue) > 0) {
        next = mlt_deque_pop_front(self->queue);
        consumer_play_video(self, next);
        mlt_frame_close(next);
        next = NULL;
    }

    mlt_consumer_stopped(&self->parent);
    return NULL;
}

static void *consumer_thread(void *arg)
{
    consumer_aaudio self = arg;
    mlt_consumer consumer = &self->parent;
    mlt_properties consumer_props = MLT_CONSUMER_PROPERTIES(consumer);

    pthread_t thread;
    int init_audio = 1;
    int init_video = 1;
    mlt_frame frame = NULL;
    mlt_properties properties = NULL;
    int64_t duration = 0;
    int64_t playtime = mlt_properties_get_int(consumer_props, "video_delay") * 1000;
    struct timespec tm = {0, 100000};

    pthread_mutex_lock(&self->refresh_mutex);
    self->refresh_count = 0;
    pthread_mutex_unlock(&self->refresh_mutex);

    while (self->running) {
        frame = mlt_consumer_rt_frame(consumer);

        if (frame) {
            properties = MLT_FRAME_PROPERTIES(frame);
            double speed = mlt_properties_get_double(properties, "_speed");

            mlt_events_block(consumer_props, consumer_props);
            mlt_properties_set_int(consumer_props, "refresh", 0);
            mlt_events_unblock(consumer_props, consumer_props);

            init_audio = consumer_play_audio(self, frame, init_audio, &duration);

            if (init_video) {
                pthread_create(&thread, NULL, video_thread, self);
                init_video = 0;
            }

            mlt_properties_set_int64(properties, "playtime", playtime);

            while (self->running && speed != 0 && mlt_deque_count(self->queue) > 15)
                nanosleep(&tm, NULL);

            if (self->running && speed) {
                pthread_mutex_lock(&self->video_mutex);
                if (self->is_purge && speed == 1.0) {
                    mlt_frame_close(frame);
                    frame = NULL;
                    self->is_purge = 0;
                } else {
                    mlt_deque_push_back(self->queue, frame);
                    pthread_cond_broadcast(&self->video_cond);
                }
                pthread_mutex_unlock(&self->video_mutex);
                playtime += duration;
            } else if (self->running) {
                pthread_mutex_lock(&self->refresh_mutex);
                consumer_play_video(self, frame);
                mlt_frame_close(frame);
                frame = NULL;
                self->refresh_count--;
                while (self->running && self->refresh_count <= 0) {
                    pthread_cond_wait(&self->refresh_cond, &self->refresh_mutex);
                }
                pthread_mutex_unlock(&self->refresh_mutex);
            }

            if (speed == 0.0)
                mlt_consumer_purge(consumer);
        }
    }

    if (init_video == 0) {
        pthread_mutex_lock(&self->video_mutex);
        pthread_cond_broadcast(&self->video_cond);
        pthread_mutex_unlock(&self->video_mutex);
        pthread_join(thread, NULL);
    }

    if (frame) {
        consumer_play_video(self, frame);
        mlt_frame_close(frame);
        frame = NULL;
    }

    pthread_mutex_lock(&self->audio_mutex);
    self->audio_avail = 0;
    pthread_mutex_unlock(&self->audio_mutex);

    return NULL;
}

static void consumer_close(mlt_consumer parent)
{
    consumer_aaudio self = parent->child;

    mlt_consumer_stop(parent);
    close_stream(self);
    mlt_consumer_close(parent);
    mlt_deque_close(self->queue);

    pthread_mutex_destroy(&self->audio_mutex);
    pthread_cond_destroy(&self->audio_cond);
    pthread_mutex_destroy(&self->video_mutex);
    pthread_cond_destroy(&self->video_cond);
    pthread_mutex_destroy(&self->refresh_mutex);
    pthread_cond_destroy(&self->refresh_cond);
    free(self->audio_buffer);
    free(self);
}

MLT_REPOSITORY
{
    MLT_REGISTER(mlt_service_consumer_type, "aaudio", consumer_aaudio_init);
    /* alias so existing "sdl2_audio" backend lookups (Kdenlive's default) find this consumer on Android */
    MLT_REGISTER(mlt_service_consumer_type, "sdl2_audio", consumer_aaudio_init);
}
