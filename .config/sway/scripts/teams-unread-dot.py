#!/usr/bin/env python3
# teams-unread-dot — red dot on the Teams title bar / tab ONLY for messages you have not
# looked at yet.
#
# Teams writes its unread-chat count into the window title, e.g. "(3) Chat | ...". That
# number stays until every chat is read inside Teams, so a plain title rule (see
# window-icons.conf) would show the dot all day. What we want instead is "something new
# arrived since I last looked at Teams".
#
# How it works, per Teams window:
#   * seen  = the unread count the last time the window had focus (focusing it = "I looked").
#   * count = the unread count in the current title.
#   * The dot is shown when count > seen. Focusing the window sets seen = count, which clears
#     the dot; it stays clear until Teams reports MORE unread chats than you have seen.
#   * If count drops below seen (you read chats), seen follows it down, so the next new
#     message lights the dot again.
#
# Limits: the count is Teams' number of unread CHATS, so another message inside a chat that
# is already unread does not raise it and therefore does not light the dot.
#
# The dot is set through `title_format` (the base icon rule lives in window-icons.conf; we
# read it from there and prepend the dot). Sway re-runs for_window rules on every title
# change, which resets the format to the plain icon; we then re-apply the dot right after.
#
# Runs in the background from sway config (exec_always). Debug log: TEAMS_DOT_DEBUG=1

import json
import os
import re
import signal
import subprocess
import sys
import time

CONF = os.path.expanduser("~/.config/sway/window-icons.conf")
RUN_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PIDFILE = os.path.join(RUN_DIR, "sway-teams-unread-dot.pid")
STATE = os.path.join(RUN_DIR, "sway-teams-unread-dot.json")

# Same app ids as the Teams rules in window-icons.conf (Chrome PWA / teams-for-linux).
TEAMS_RE = re.compile(
    r"^(chrome-ompifgpmddkgmclendfeacglnodjjndh-.*|teams-for-linux|teams|ms-teams)$", re.I)
# "(3) Chat | ..." or "Microsoft Teams (PWA) - (3) Chat | ..."; a "(N)" inside a chat name
# further along the title must not count.
COUNT_RE = re.compile(r"(?:^|- )\((\d+)\)\s")
DOT = "<span font='JetBrainsMono Nerd Font 11' foreground='#f38ba8'>●</span>"

# exec_always also re-runs apply-window-icons.sh, which resets every title_format to the
# plain icon. Wait this long before the first apply so the dot goes on AFTER that reset.
STARTUP_DELAY = 1.0

DEBUG = bool(os.environ.get("TEAMS_DOT_DEBUG"))


def log(msg):
    if DEBUG:
        print(f"teams-unread-dot: {msg}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Pure logic (no sway involved)
# ---------------------------------------------------------------------------

def is_teams(container):
    ident = container.get("app_id") or (container.get("window_properties") or {}).get("class")
    return bool(ident and TEAMS_RE.match(ident))


def unread_count(title):
    m = COUNT_RE.search(title or "")
    return int(m.group(1)) if m else 0


class SeenTracker:
    """seen-count bookkeeping; observe() answers "should this window show the dot"."""

    def __init__(self, seen=None):
        self.seen = dict(seen or {})

    def observe(self, con_id, count, focused):
        seen = self.seen.get(con_id, 0)  # a window we never saw before: nothing seen yet
        if focused or count < seen:
            seen = count
        self.seen[con_id] = seen
        return count > seen

    def adopt(self, con_id, count):
        """Treat the current count of an already-open window as seen (daemon just started)."""
        self.seen[con_id] = count

    def forget(self, con_id):
        self.seen.pop(con_id, None)


# ---------------------------------------------------------------------------
# Talking to sway
# ---------------------------------------------------------------------------

def swaymsg(*args):
    return subprocess.run(["swaymsg", *args], capture_output=True, text=True).stdout


def teams_containers(node):
    """Yield every Teams window container in a get_tree result."""
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        if child.get("pid") and is_teams(child):
            yield child
        yield from teams_containers(child)


def plain_format():
    """The base Teams icon format, read from window-icons.conf (single source of truth)."""
    try:
        with open(CONF, encoding="utf-8") as f:
            for line in f:
                if (line.startswith("for_window [app_id=") and "ompifgpmddkgmclendfeacglnodjjndh" in line
                        and " title=" not in line):
                    m = re.search(r'title_format "(.*)"\s*$', line)
                    if m:
                        return m.group(1)
    except OSError:
        pass
    return None


def set_format(con_id, fmt):
    swaymsg(f'[con_id={con_id}] title_format "{fmt}"')


def load_state(sock):
    try:
        with open(STATE, encoding="utf-8") as f:
            data = json.load(f)
        if data.get("sock") == sock:  # ids restart every sway session: ignore an old session's file
            return {int(k): v for k, v in data.get("seen", {}).items()}
    except (OSError, ValueError):
        pass
    return {}


def save_state(sock, tracker):
    tmp = f"{STATE}.{os.getpid()}"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"sock": sock, "seen": tracker.seen}, f)
        os.replace(tmp, STATE)
    except OSError:
        pass


def take_over_pidfile():
    """Sway re-runs this script on every reload: stop the old copy so there is only one."""
    try:
        with open(PIDFILE) as f:
            old = int(f.read().strip())
        with open(f"/proc/{old}/cmdline") as f:
            if old != os.getpid() and "teams-unread-dot" in f.read():
                os.kill(old, signal.SIGTERM)
    except (OSError, ValueError):
        pass
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))


def main():
    sock = os.environ.get("SWAYSOCK")
    if not sock:
        sys.exit("teams-unread-dot: SWAYSOCK not set (run inside a sway session)")
    plain = plain_format()
    if not plain:
        sys.exit(f"teams-unread-dot: no Teams icon rule found in {CONF}")
    dot_fmt = f"{DOT} {plain}"
    take_over_pidfile()

    tracker = SeenTracker(load_state(sock))
    dot_on = {}  # con_id -> True while the dot format is what is currently applied

    def show(con_id, want):
        if want and not dot_on.get(con_id):
            set_format(con_id, dot_fmt)
        elif not want and dot_on.get(con_id):
            set_format(con_id, plain)
        dot_on[con_id] = want
        log(f"con {con_id}: dot={'on' if want else 'off'}")

    # Windows that already exist. Ones we have state for (a reload) keep their history;
    # others are treated as already seen so a fresh daemon does not flag old unread chats.
    time.sleep(STARTUP_DELAY)
    tree = json.loads(swaymsg("-t", "get_tree", "-r") or "{}")
    for c in teams_containers(tree):
        count = unread_count(c.get("name"))
        if c["id"] not in tracker.seen:
            tracker.adopt(c["id"], count)
        show(c["id"], tracker.observe(c["id"], count, bool(c.get("focused"))))
    save_state(sock, tracker)

    events = subprocess.Popen(["swaymsg", "-r", "-t", "subscribe", "-m", '["window"]'],
                              stdout=subprocess.PIPE, text=True)
    for line in events.stdout:
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        c = ev.get("container") or {}
        change, con_id = ev.get("change"), c.get("id")
        if con_id is None or not is_teams(c):
            continue
        if change == "close":
            tracker.forget(con_id)
            dot_on.pop(con_id, None)
        elif change in ("new", "title", "focus"):
            if change in ("new", "title"):
                dot_on[con_id] = False  # the for_window rule just reset it to the plain icon
            show(con_id, tracker.observe(con_id, unread_count(c.get("name")), bool(c.get("focused"))))
        else:
            continue
        save_state(sock, tracker)


if __name__ == "__main__":
    main()
