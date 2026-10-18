package org.kdenlive.android;

import android.view.InputDevice;
import android.view.MotionEvent;

/**
 * Qt for Android loses mouse button events for dialog windows (touch events work). While a dialog is open
 * (flag set from native code), mouse events are converted to single-finger touch events.
 */
public class KdenliveActivity extends org.qtproject.qt.android.bindings.QtActivity {
    public static volatile boolean mouseAsTouch = false;

    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (mouseAsTouch && ev.getPointerCount() == 1 && ev.getToolType(0) == MotionEvent.TOOL_TYPE_MOUSE) {
            int action = ev.getActionMasked();
            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_MOVE || action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                MotionEvent.PointerProperties[] props = new MotionEvent.PointerProperties[1];
                MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[1];
                props[0] = new MotionEvent.PointerProperties();
                props[0].id = 0;
                props[0].toolType = MotionEvent.TOOL_TYPE_FINGER;
                coords[0] = new MotionEvent.PointerCoords();
                ev.getPointerCoords(0, coords[0]);
                MotionEvent touch = MotionEvent.obtain(ev.getDownTime(), ev.getEventTime(), action, 1, props, coords, 0, 0, ev.getXPrecision(), ev.getYPrecision(),
                    0, ev.getEdgeFlags(), InputDevice.SOURCE_TOUCHSCREEN, 0);
                try {
                    return super.dispatchTouchEvent(touch);
                } finally {
                    touch.recycle();
                }
            }
        }
        return super.dispatchTouchEvent(ev);
    }
}
