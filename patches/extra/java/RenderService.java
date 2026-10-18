package org.kdenlive.android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

/**
 * Foreground service that keeps the process alive (and the CPU awake) while a render is running,
 * so that rendering continues when the user switches to another app. Also posts the "finished" notification
 * with Play / Share actions.
 */
public class RenderService extends Service {
    private static final String CHANNEL_PROGRESS = "kdenlive_render";
    private static final String CHANNEL_DONE = "kdenlive_render_done";
    private static final int ID_PROGRESS = 7001;
    private static final int ID_DONE = 7002;
    private static PowerManager.WakeLock s_wakeLock;

    private static void ensureChannels(Context ctx) {
        NotificationManager nm = ctx.getSystemService(NotificationManager.class);
        if (nm.getNotificationChannel(CHANNEL_PROGRESS) == null) {
            nm.createNotificationChannel(new NotificationChannel(CHANNEL_PROGRESS, "Rendering", NotificationManager.IMPORTANCE_LOW));
        }
        if (nm.getNotificationChannel(CHANNEL_DONE) == null) {
            nm.createNotificationChannel(new NotificationChannel(CHANNEL_DONE, "Render finished", NotificationManager.IMPORTANCE_DEFAULT));
        }
    }

    private static PendingIntent openAppIntent(Context ctx) {
        Intent launch = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        return PendingIntent.getActivity(ctx, 0, launch, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    private static Notification progressNotification(Context ctx, String title, int percent) {
        Notification.Builder b = new Notification.Builder(ctx, CHANNEL_PROGRESS)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Kdenlive: rendering")
            .setContentText(title)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openAppIntent(ctx));
        b.setProgress(100, Math.max(0, Math.min(100, percent)), percent <= 0);
        return b.build();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        ensureChannels(this);
        String title = intent != null ? intent.getStringExtra("title") : "";
        Notification n = progressNotification(this, title == null ? "" : title, 0);
        if (Build.VERSION.SDK_INT >= 35) {
            startForeground(ID_PROGRESS, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING);
        } else {
            startForeground(ID_PROGRESS, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        }
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    // ---- called from native code ----

    public static void start(Context ctx, String title) {
        PowerManager pm = ctx.getSystemService(PowerManager.class);
        if (s_wakeLock == null) {
            s_wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Kdenlive:render");
        }
        if (!s_wakeLock.isHeld()) {
            s_wakeLock.acquire(6 * 60 * 60 * 1000L);
        }
        Intent i = new Intent(ctx, RenderService.class);
        i.putExtra("title", title);
        try {
            ctx.startForegroundService(i);
        } catch (RuntimeException e) {
            // not allowed to start from the background: rendering still works while the app is visible
        }
    }

    public static void update(Context ctx, String title, int percent) {
        NotificationManager nm = ctx.getSystemService(NotificationManager.class);
        nm.notify(ID_PROGRESS, progressNotification(ctx, title, percent));
    }

    public static void stop(Context ctx) {
        if (s_wakeLock != null && s_wakeLock.isHeld()) {
            s_wakeLock.release();
        }
        ctx.stopService(new Intent(ctx, RenderService.class));
        ctx.getSystemService(NotificationManager.class).cancel(ID_PROGRESS);
    }

    public static void finished(Context ctx, String uri, String title, boolean ok, String message) {
        ensureChannels(ctx);
        Notification.Builder b = new Notification.Builder(ctx, CHANNEL_DONE)
            .setSmallIcon(ok ? android.R.drawable.stat_sys_download_done : android.R.drawable.stat_notify_error)
            .setContentTitle(ok ? "Render finished" : "Render failed")
            .setContentText(ok ? title : message)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(ctx));
        if (ok && uri != null && !uri.isEmpty()) {
            Uri u = Uri.parse(uri);
            Intent view = new Intent(Intent.ACTION_VIEW).setDataAndType(u, "video/*").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            b.addAction(new Notification.Action.Builder(null, "Play",
                PendingIntent.getActivity(ctx, 1, view, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT)).build());
            Intent send = new Intent(Intent.ACTION_SEND).setType("video/*").putExtra(Intent.EXTRA_STREAM, u).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(send, "Share video").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            b.addAction(new Notification.Action.Builder(null, "Share",
                PendingIntent.getActivity(ctx, 2, chooser, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT)).build());
        }
        ctx.getSystemService(NotificationManager.class).notify(ID_DONE, b.build());
    }
}
