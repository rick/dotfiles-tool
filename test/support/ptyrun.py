#!/usr/bin/env python3
"""Run a command on a pty, answering each prompt in turn.

Not named pty.py: that shadows the stdlib module this imports.

    ptyrun.py <answers> <command> [args...]

<answers> is comma-separated, one per prompt, e.g. "y,n,q". Prompts beyond the
list get an empty line (the default), so a test need only spell out the answers
it cares about. A bare `script -q` will not do: it closes stdin, so the child
reads EOF rather than the keystroke.
"""
import os, pty, select, signal, sys, time

PROMPT = b"mark as done?"
TIMEOUT = 30


def main():
    answers = [a for a in sys.argv[1].split(",") if a != ""]
    argv = sys.argv[2:]

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(argv[0], argv)

    out, seen, sent = b"", 0, 0
    deadline = time.time() + TIMEOUT
    timed_out = False
    while time.time() < deadline:
        if os.waitpid(pid, os.WNOHANG)[0] != 0:
            break
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
        count = out.count(PROMPT)
        while count > seen:
            time.sleep(0.1)
            reply = answers[sent] if sent < len(answers) else ""
            os.write(fd, (reply + "\n").encode())
            seen += 1
            sent += 1
    else:
        timed_out = True
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)

    while True:
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            break
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk

    sys.stdout.write(out.decode("utf-8", "replace"))
    sys.exit(75 if timed_out else 0)


main()
