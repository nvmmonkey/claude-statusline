#!/usr/bin/env bash
# Install the status line into ~/.claude. Safe to re-run: it copies the script,
# backs up settings.json, sets the "statusLine" key and leaves every other key
# alone. Re-run it after `tt setup` or a token-tracker upgrade, which put the
# stock tt-statusline.py back.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
script="$claude_dir/tt-statusline.py"
settings="$claude_dir/settings.json"

python="$(command -v python3 || true)"
if [ -z "$python" ]; then
  echo "python3 is not on PATH. Install Python 3.8 or newer, then re-run." >&2
  exit 1
fi

mkdir -p "$claude_dir"
install -m 0755 "$here/tt-statusline.py" "$script"
echo "script:   $script"

if [ -f "$settings" ]; then
  backup="$settings.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p "$settings" "$backup"
  echo "backup:   $backup"
fi

# Set only "statusLine". Absolute paths, because Claude Code may run the
# command with a shorter PATH than your shell. A symlinked settings.json is
# written through to its target.
"$python" - "$settings" "$python" "$script" <<'PY'
import json, os, sys

path, python, script = sys.argv[1:4]
path = os.path.realpath(path)
settings = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if text.strip():
        try:
            settings = json.loads(text)
        except json.JSONDecodeError as e:
            sys.exit(f"{path} is not valid JSON ({e}). Fix it and re-run; nothing was changed.")
previous = settings.get("statusLine")
settings["statusLine"] = {"type": "command", "command": f"{python} {script}"}
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
if previous and previous != settings["statusLine"]:
    print(f"replaced: {json.dumps(previous, ensure_ascii=False)}")
print(f"settings: {path}")
print(f"command:  {settings['statusLine']['command']}")
PY

# Render the sample once. HOME points at an empty folder so the run cannot
# overwrite the real ~/.claude/tt-status.json.
tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT
out="$(HOME="$tmp_home" "$python" "$script" < "$here/sample-input.json")"
lines="$(printf '%s\n' "$out" | grep -c .)"
if [ "$lines" -ne 3 ]; then
  echo "Sample render printed $lines lines instead of 3:" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
printf '%s\n' "$out"
echo "Installed. The status line appears after your next message in Claude Code."
