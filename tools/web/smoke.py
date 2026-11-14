"""Browser smoke test: open the exported web build in real (headless) Chrome and make sure the
game actually starts, reaches the menu and a level, with no load failures or script errors.

The Godot tests run the game natively; they can't catch a web build that fails to load
(that happened once: the page asked for a file that had been renamed). This can.

Usage:  python3 tools/web/smoke.py build/web [screenshot_dir]
Needs:  pip install playwright   (uses the installed Google Chrome, no browser download)
"""
import functools
import http.server
import os
import sys
import threading
import time

from playwright.sync_api import sync_playwright

root = sys.argv[1]
shots = sys.argv[2] if len(sys.argv) > 2 else None
READY = "GAME READY"     # printed by game.gd once data, fonts, music and save are loaded

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


handler = functools.partial(Quiet, directory=root)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f"http://127.0.0.1:{server.server_port}/index.html"

problems, console = [], []


def fail(msg):
    problems.append(msg)


with sync_playwright() as pw:
    browser = pw.chromium.launch(channel="chrome", headless=True, args=[
        "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist",
        "--autoplay-policy=no-user-gesture-required"])
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    page.on("console", lambda m: console.append(f"[{m.type}] {m.text}"))
    page.on("pageerror", lambda e: fail(f"page error: {e}"))
    page.on("response", lambda r: r.status >= 400 and fail(f"HTTP {r.status} for {r.url}"))
    page.goto(url)

    # 1. the engine loads: Godot removes the #status overlay on success, shows #status-notice on failure
    deadline = time.time() + 90
    while time.time() < deadline:
        if page.locator("#status-notice").is_visible():
            fail("load failed: " + page.locator("#status-notice").inner_text().strip())
            break
        if page.locator("#status").count() == 0 and any(READY in c for c in console):
            break
        time.sleep(0.5)
    else:
        fail("game did not report ready within 90 s")

    if not problems:
        # 2. drive it: title -> menu -> play, then fire a shot
        time.sleep(1.5)
        if shots: page.screenshot(path=os.path.join(shots, "1_title.png"))
        page.keyboard.press("Space"); time.sleep(1.2)
        if shots: page.screenshot(path=os.path.join(shots, "2_menu.png"))
        page.keyboard.press("Enter"); time.sleep(1.2)
        page.mouse.move(900, 300); page.mouse.click(900, 300); time.sleep(1.5)
        if shots: page.screenshot(path=os.path.join(shots, "3_play.png"))

    for c in console:
        if "SCRIPT ERROR" in c or "USER ERROR" in c or ("[error]" in c and "ERROR:" in c):
            fail("console: " + c)
    browser.close()

server.shutdown()
print("\n".join("  " + c for c in console[-25:]))
if problems:
    print("\nWEB SMOKE TEST FAILED")
    for p in problems:
        print("  - " + p)
    sys.exit(1)
print("\nweb smoke test: game loaded, reached a level, no errors")
