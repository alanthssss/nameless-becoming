#!/usr/bin/env python3
"""Bound one test command on macOS/Linux without requiring GNU timeout."""
import os
import signal
import subprocess
import sys

process = subprocess.Popen(sys.argv[2:], start_new_session=True)
try:
    raise SystemExit(process.wait(timeout=float(sys.argv[1])))
except subprocess.TimeoutExpired:
    print(f"TIMEOUT after {sys.argv[1]}s: {sys.argv[2:]}", file=sys.stderr)
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    raise SystemExit(124)
