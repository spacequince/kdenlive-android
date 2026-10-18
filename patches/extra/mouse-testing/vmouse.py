#!/usr/bin/env python3
"""Virtual USB mouse on the phone through Android's `uinput` tool (a REAL mouse: BTN_LEFT/RIGHT/MIDDLE + wheel).
Usage as a module: m = VMouse(); m.move_to(x, y); m.click(); m.right_click(); m.drag(x1,y1,x2,y2); m.scroll(dy); m.close()"""
import json, subprocess, time, re, os
ADB = os.path.expanduser('~/kdenlive-android/sdk/platform-tools/adb')

def adb(*a, **k):
    return subprocess.run([ADB, 'shell'] + list(a), capture_output=True, text=True, **k).stdout

class VMouse:
    def __init__(self):
        self.p = subprocess.Popen([ADB, 'shell', 'uinput', '-'], stdin=subprocess.PIPE, text=True, bufsize=1)
        self._send({"id": 7, "command": "register", "name": "Kdenlive Test Mouse", "vid": 0x18d1, "pid": 0x4e11, "bus": "usb",
                    "configuration": [
                        {"type": "UI_SET_EVBIT", "data": ["EV_KEY", "EV_REL", "EV_SYN"]},
                        {"type": "UI_SET_KEYBIT", "data": ["BTN_LEFT", "BTN_RIGHT", "BTN_MIDDLE"]},
                        {"type": "UI_SET_RELBIT", "data": ["REL_X", "REL_Y", "REL_WHEEL", "REL_HWHEEL"]}]})
        time.sleep(1.5)

    def _send(self, obj):
        self.p.stdin.write(json.dumps(obj) + "\n"); self.p.stdin.flush()

    def inject(self, events):
        flat = []
        for t, c, v in events:
            flat += [t, c, v]
        self._send({"id": 7, "command": "inject", "events": flat + ["EV_SYN", "SYN_REPORT", 0]})
        time.sleep(0.05)

    def rel(self, dx, dy):
        self.inject([("EV_REL", "REL_X", int(dx)), ("EV_REL", "REL_Y", int(dy))])

    def pos(self):
        """last pointer position (device px) reported by the app's MOUSEPOS log, or None"""
        out = subprocess.run([ADB, 'logcat', '-d', '-t', '400'], capture_output=True, text=True).stdout
        last = None
        for l in out.splitlines():
            m = re.search(r'MOUSEPOS \d+ (-?\d+) (-?\d+)', l)
            if m:
                last = (float(m.group(1)), float(m.group(2)))
        return last

    GAIN = 2.3   # measured: device px per relative unit (linear, pointer speed 0)

    def slam(self):
        for _ in range(3):
            self.rel(-2000, -2000); time.sleep(0.08)
        self.cur = (0.0, 0.0)

    def move_to(self, x, y, tries=0):
        """open-loop move: slam into the top-left corner then travel by calibrated relative steps
        (works in dialogs where the app logs no pointer position)"""
        self.slam()
        gx, gy = x / self.GAIN, y / self.GAIN
        n = max(1, int(max(abs(gx), abs(gy)) // 50) + 1)
        sx = sy = 0
        for i in range(1, n + 1):
            tx, ty = round(gx * i / n), round(gy * i / n)
            self.rel(tx - sx, ty - sy)
            sx, sy = tx, ty
            time.sleep(0.03)
        self.cur = (sx * self.GAIN, sy * self.GAIN)
        time.sleep(0.25)
        return self.cur

    def move_rel_to(self, x, y):
        """relative travel from the current (tracked) position, without slamming (keeps drags continuous)"""
        cx, cy = self.cur
        dx, dy = (x - cx) / self.GAIN, (y - cy) / self.GAIN
        n = max(1, int(max(abs(dx), abs(dy)) // 40) + 1)
        sx = sy = 0
        for i in range(1, n + 1):
            tx, ty = round(dx * i / n), round(dy * i / n)
            self.rel(tx - sx, ty - sy); sx, sy = tx, ty
            time.sleep(0.03)
        self.cur = (cx + sx * self.GAIN, cy + sy * self.GAIN)

    def shot(self, path):
        with open(path, 'wb') as f:
            f.write(subprocess.run([ADB, 'exec-out', 'screencap', '-p'], capture_output=True).stdout)

    def button(self, name, down):
        self.inject([("EV_KEY", name, 1 if down else 0)])

    def click(self, name="BTN_LEFT"):
        self.button(name, True); time.sleep(0.08); self.button(name, False)

    def right_click(self):
        self.click("BTN_RIGHT")

    def drag(self, x1, y1, x2, y2, steps=14):
        self.move_to(x1, y1); time.sleep(0.5)
        self.rel(2, 0); time.sleep(0.15); self.rel(-2, 0); time.sleep(0.5)   # let QML hover state (drag proxy) settle
        self.button("BTN_LEFT", True); time.sleep(0.25)
        for i in range(1, steps + 1):
            self.move_rel_to(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
            time.sleep(0.04)
        time.sleep(0.3); self.button("BTN_LEFT", False)

    def scroll(self, notches):
        self.inject([("EV_REL", "REL_WHEEL", int(notches))])

    def close(self):
        try:
            self._send({"id": 7, "command": "unregister"})
        finally:
            self.p.stdin.close()
