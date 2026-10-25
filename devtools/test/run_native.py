#!/usr/bin/env python3
"""Run a native engine test and reap its Windows process descendants on exit.

Do not use this wrapper for general application launches: test-owned child
processes, including delayed driver updaters, are terminated when the test ends.
Linux/macOS retain normal subprocess behavior. No driver settings are changed.
"""

import argparse
import os
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("executable")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    job = None
    before = []
    if os.name == "nt":
        from windows_process_job import TestJob, ngx_census

        before = ngx_census()
        if len(before) > 8:
            print("ERROR: Test harness found an NGX updater backlog; no engine launched.", file=sys.stderr)
            return 1
    process = subprocess.Popen([args.executable, *args.arguments])
    try:
        if os.name == "nt":
            try:
                job = TestJob(process)
            except OSError:
                process.terminate()
                process.wait(timeout=10)
                raise
        return_code = process.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        print("ERROR: Native test timed out.", file=sys.stderr)
        return_code = 1
    finally:
        if job is not None:
            remaining = job.close()
            if remaining:
                print(f"Test harness: closed {len(remaining)} remaining test process(es).")
    if os.name == "nt":
        time.sleep(0.25)
        after = ngx_census()
        if set(after) - set(before):
            print("ERROR: NGX updater census grew after test cleanup.", file=sys.stderr)
            return_code = 1
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
