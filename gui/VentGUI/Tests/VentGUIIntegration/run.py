#!/usr/bin/env python3
"""Compile and run isolated AppKit lifecycle checks against a fake Unix helper.

Requires a logged-in macOS GUI session. Never connects to /tmp/ventd.sock.
"""
import os
import pathlib
import plistlib
import socketserver
import subprocess
import tempfile
import threading
import time


ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Sources" / "VentGUI"
TEST = pathlib.Path(__file__).with_name("LifecycleIntegration.swift")


class FakeHelper(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True

    def __init__(self, path, scenario):
        super().__init__(path, Handler)
        self.lock = threading.Lock()
        self.high = False
        self.online = scenario != "unresponsive"
        self.auto = "OK"
        self.guard_checked = False
        self.count = 0
        self.commands = []
        self.auto_acknowledged = False
        self.first_drop = scenario in ("first-drop", "unresponsive")
        self.version_seen = False


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        command = self.rfile.readline(1024).decode("utf-8").strip()
        server = self.server
        delay = 0
        with server.lock:
            if command.startswith("TEST "):
                action = command[5:]
                if action == "HIGH":
                    server.high = True
                elif action == "LOW":
                    server.high = False
                elif action == "OFFLINE":
                    server.online = False
                elif action == "ONLINE":
                    server.online = True
                    server.first_drop = False
                elif action == "RESET_COUNT":
                    server.count = 0
                elif action == "RESET_LOG":
                    server.commands.clear()
                elif action == "AUTO_ERROR":
                    server.auto = "ERR failed"
                elif action == "AUTO_TIMEOUT":
                    server.auto = "TIMEOUT"
                elif action == "AUTO_OK":
                    server.auto = "OK"
                elif action == "DELAY_AUTO":
                    server.auto = "DELAY"
                if action == "GUARD_CHECKED":
                    server.guard_checked = True
                if action == "WRITES":
                    response = "|".join(server.commands)
                elif action == "COUNT":
                    response = str(server.count)
                elif action == "VERSION_SEEN":
                    response = "1" if server.version_seen else "0"
                else:
                    response = "OK"
            else:
                server.commands.append(command)
                server.count += 1
                if server.first_drop and not server.online and command != "HEARTBEAT":
                    return
                if command == "HEARTBEAT":
                    response = "OK" if server.online else "ERR offline"
                elif command == "VERSION":
                    response = "VERSION 1.3.7"
                    if server.first_drop and not server.version_seen:
                        server.version_seen = True
                        server.online = False
                        delay = 2
                elif command == "FANS":
                    rpm = 5000 if server.high else 1000
                    response = f"FANS 1\n0 {rpm} 1000 6000 {rpm} 1"
                elif command == "CONFIG":
                    response = "CONFIG 20 95 55 20 130"
                elif command == "TEMPS":
                    response = "TEMPS 1\nTC0P 58"
                elif command == "MODESTATUS":
                    response = "MODE MANUAL_RPM 55 58 0"
                elif command == "MODE AUTO":
                    response = server.auto
                    if response == "TIMEOUT":
                        delay, response = 6, "OK"
                    elif response == "DELAY":
                        delay, response = 2, "OK"
                else:
                    response = "OK"
        if delay:
            time.sleep(delay)
        try:
            self.wfile.write((response + "\n").encode())
            self.wfile.flush()
            if command == "MODE AUTO" and response == "OK":
                with server.lock:
                    server.auto_acknowledged = True
        except (BrokenPipeError, ConnectionResetError):
            pass


def main():
    with tempfile.TemporaryDirectory(prefix="vent-test-", dir="/tmp") as temporary:
        directory = pathlib.Path(temporary)
        socket_path = directory / "helper.sock"
        app = directory / "Lifecycle.app" / "Contents"
        executable = app / "MacOS" / "Lifecycle"
        executable.parent.mkdir(parents=True)
        with (app / "Info.plist").open("wb") as info:
            plistlib.dump({"CFBundleIdentifier": "dev.vent.lifecycle-tests",
                           "CFBundleExecutable": "Lifecycle", "CFBundlePackageType": "APPL",
                           "CFBundleName": "Vent Lifecycle Tests", "CFBundleVersion": "1", "LSUIElement": True}, info)
        default_sdk = pathlib.Path(subprocess.check_output(["xcrun", "--show-sdk-path", "--sdk", "macosx"], text=True).strip())
        compatible_sdk = default_sdk.parent / "MacOSX26.5.sdk"
        sdk = pathlib.Path(os.environ.get("SDKROOT", str(compatible_sdk if compatible_sdk.is_dir() else default_sdk)))
        if not sdk.is_dir():
            raise RuntimeError(f"macOS SDK directory not found: {sdk}")
        subprocess.run(["xcrun", "swiftc", "-sdk", str(sdk), "-module-cache-path", str(directory / "module-cache"),
                        *map(str, sorted(SOURCE.glob("*.swift"))), str(TEST),
                        str(TEST.with_name("UpdateIntegration.swift")), "-o", str(executable)], check=True)
        environment = os.environ.copy()
        environment["VENT_SOCKET_PATH"] = str(socket_path)
        for scenario in ("updates", "missing", "unresponsive", "disabled", "monitor", "retry-notification", "first-drop", "failure", "timeout", "ordering"):
            helper = None
            if scenario not in ("missing", "updates"):
                helper = FakeHelper(str(socket_path), scenario)
                threading.Thread(target=helper.serve_forever, daemon=True).start()
            try:
                started = time.monotonic()
                subprocess.run([str(executable), scenario], env=environment, timeout=25, check=True)
                elapsed = time.monotonic() - started
                if helper:
                    deadline = time.monotonic() + 1
                    while not helper.auto_acknowledged and time.monotonic() < deadline:
                        time.sleep(0.01)
                    with helper.lock:
                        commands = list(helper.commands)
                        acknowledged = helper.auto_acknowledged
                    assert acknowledged, f"{scenario}: exited without Auto acknowledgement"
                    writes = [item for item in commands if item.startswith(("MODE ", "SET ", "SETALL "))]
                    assert writes and writes[-1] == "MODE AUTO", f"{scenario}: final writes {writes}"
                    if scenario == "ordering":
                        assert helper.guard_checked, "pending termination guard was not exercised"
                        assert "SETALL 2500" not in writes, "accepted a fan write after termination began"
                        assert writes.count("MODE MANUAL") == 1, "accepted mode change during termination"
                        assert "MODE MANUAL" in writes and any(item.startswith("SETALL ") for item in writes), f"queued writes missing: {writes}"
                        assert elapsed >= 2, "app exited before delayed Auto acknowledgement"
                print(f"PASS {scenario} ({elapsed:.1f}s)", flush=True)
            finally:
                subprocess.run(["defaults", "delete", "dev.vent.lifecycle-tests"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                if helper:
                    helper.shutdown()
                    helper.server_close()
                    socket_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
