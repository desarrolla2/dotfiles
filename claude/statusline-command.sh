#!/bin/bash
# Claude Code status line:
#   model | dir ⎇ branch | context | cost | lines changed | 5h block (reset) | weekly (reset)
# Reads the status line JSON payload from stdin (see Claude Code docs).
# Parsed with python3 so the script has no jq dependency.

input=$(cat)

python3 - "$input" <<'EOF'
import json, locale, os, subprocess, sys, time

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

# Python starts in the C locale, so weekday names would always be English.
# Opt into the system locale; ignore it when that locale is not generated.
try:
    locale.setlocale(locale.LC_TIME, "")
except locale.Error:
    pass

def get(path):
    node = data
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node

DIM = "\033[2m"
RESET = "\033[0m"
CYAN = "\033[2;36m"
GREEN = "\033[2;32m"
YELLOW = "\033[2;33m"
MAGENTA = "\033[2;35m"

def reset_in(epoch):
    """Time until a rate-limit window resets: '2h10m', '35m' or 'Fri 09:00'."""
    if not epoch:
        return None
    remaining = int(epoch - time.time())
    if remaining <= 0:
        return None
    if remaining >= 24 * 3600:
        return time.strftime("%a %H:%M", time.localtime(epoch))
    hours, minutes = divmod(remaining // 60, 60)
    return f"{hours}h{minutes:02d}m" if hours else f"{minutes}m"

segments = []

model = get(["model", "display_name"]) or "unknown"
segments.append(f"{CYAN}{model}{RESET}")

cwd = get(["workspace", "current_dir"]) or ""
if cwd:
    place = os.path.basename(cwd.rstrip("/")) or "/"
    try:
        branch = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=1,
        ).stdout.strip()
    except Exception:
        branch = ""
    if branch:
        place += f" ⎇ {branch}"
    segments.append(f"{GREEN}{place}{RESET}")

ctx = get(["context_window", "used_percentage"])
if ctx is not None:
    segments.append(f"{DIM}Ctx {ctx:.0f}%{RESET}")

cost = get(["cost", "total_cost_usd"])
if cost is not None:
    segments.append(f"{DIM}${cost:.2f}{RESET}")

added = get(["cost", "total_lines_added"])
removed = get(["cost", "total_lines_removed"])
if added is not None or removed is not None:
    segments.append(f"{DIM}+{added or 0}/-{removed or 0}{RESET}")

for path, label, color in (
    (["rate_limits", "five_hour"], "5h", YELLOW),
    (["rate_limits", "seven_day"], "7d", MAGENTA),
):
    window = get(path) or {}
    pct = window.get("used_percentage")
    if pct is None:
        continue
    seg = f"{label} {pct:.0f}%"
    reset = reset_in(window.get("resets_at"))
    if reset:
        seg += f" ↻{reset}"
    segments.append(f"{color}{seg}{RESET}")

print(f"{DIM} | {RESET}".join(segments), end="")
EOF
