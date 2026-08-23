#!/usr/bin/env python3
"""PreToolUse(Bash): escalate git operations that would write to `main`.

Pal is GitFlow: `main` carries tagged releases only, and the standing rule is
"push the task branch and ask before merging". This turns that rule from advice
into a prompt. It never denies — it asks.
"""
import json
import re
import subprocess
import sys


def current_branch() -> str:
    try:
        return subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    except Exception:
        return ""


def reason_for(command: str, branch: str) -> str | None:
    if re.search(r"\bgit\s+push\b[^|;&]*\b(origin\s+main|HEAD:main|main:main)\b", command):
        return "pushes to `main`"
    write_op = re.search(r"\bgit\s+(commit|merge|rebase|cherry-pick)\b", command)
    if branch == "main" and write_op:
        return f"runs `git {write_op.group(1)}` while HEAD is on `main`"
    return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    command = (payload.get("tool_input") or {}).get("command") or ""
    if "git" not in command:
        return 0

    reason = reason_for(command, current_branch())
    if reason is None:
        return 0

    json.dump({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "escalate",
            "permissionDecisionReason": (
                f"Pal GitFlow: this command {reason}. `main` carries tagged releases only, "
                "and the standing rule is to push the task branch and ask before merging. "
                "Confirm this is an approved release or hotfix."
            ),
        }
    }, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
