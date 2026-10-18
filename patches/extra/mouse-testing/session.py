#!/usr/bin/env python3
"""Interactive helper: python3 session.py 'click 500 300' 'shot name' ... (commands run in one virtual-mouse session).
Coordinates are DEVICE px (= screenshot px x 1.07)."""
import sys, time
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vmouse
S = os.environ.get('SHOT_DIR', '/tmp')   # screenshots go here
m = vmouse.VMouse()
m.rel(-1, -1); time.sleep(0.3)
try:
    for c in sys.argv[1:]:
        a = c.split()
        op = a[0]
        if op == 'click': m.move_to(float(a[1]), float(a[2])); time.sleep(0.1); m.click()
        elif op == 'rclick': m.move_to(float(a[1]), float(a[2])); time.sleep(0.1); m.right_click()
        elif op == 'mclick': m.move_to(float(a[1]), float(a[2])); time.sleep(0.1); m.click('BTN_MIDDLE')
        elif op == 'dclick': m.move_to(float(a[1]), float(a[2])); time.sleep(0.1); m.click(); time.sleep(0.12); m.click()
        elif op == 'move': print('at', m.move_to(float(a[1]), float(a[2])))
        elif op == 'drag': m.drag(*[float(v) for v in a[1:5]])
        elif op == 'scroll': m.move_to(float(a[1]), float(a[2])); time.sleep(0.1); m.scroll(int(a[3]))
        elif op == 'wait': time.sleep(float(a[1]))
        elif op == 'shot': m.shot(f'{S}/{a[1]}.png')
        elif op == 'key': vmouse.adb('input', 'keyevent', *a[1:])
        elif op == 'pos': print('pos', m.pos())
        time.sleep(0.4)
finally:
    m.close()
