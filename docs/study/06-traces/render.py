"""Render a Harbor trial's ATIF trajectory (agent/trajectory.json) as readable Markdown.

Usage:
    uv run 06-traces/render.py <trial-dir> <out.md> [--notes notes.md] [--max-lines 40]

<trial-dir> is a Harbor trial directory (contains result.json, agent/trajectory.json and,
for these tasks, verifier/checks.json). --notes inserts a hand-written "what to notice"
block after the header, so a re-render keeps the commentary.
"""

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

# Commands that mark the agent's inspect -> evaluate -> build -> boot loop (same idea as author/trial-stats.py).
CANDIDATE = re.compile(r"GUEST_SSH_PORT=3222")
REFERENCE = re.compile(r"/opt/runtime/guest")
BUILD = re.compile(r"build-replica")
CHECK = re.compile(r"check-replica")


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value)  # Python 3.11+ accepts a trailing Z


def clip(text: str, max_lines: int) -> str:
    lines = text.rstrip("\n").splitlines()
    if len(lines) <= max_lines:
        return "\n".join(lines)
    head = max_lines - 10
    return "\n".join([*lines[:head], f"... [{len(lines) - max_lines} lines omitted] ...", *lines[-10:]])


def fence(text: str, lang: str = "") -> str:
    ticks = "````" if "```" in text else "```"
    return f"{ticks}{lang}\n{text}\n{ticks}"


def render_call(call: dict[str, Any], max_lines: int) -> str:
    name: str = call.get("function_name", "?")
    args: dict[str, Any] = call.get("arguments") or {}
    if name.lower() == "bash" or name == "Monitor":
        desc = args.get("description")
        label = f"**{name}**" + (f" — {desc}" if isinstance(desc, str) and desc else "")
        return f"{label}\n\n{fence(str(args.get('command', '')), 'bash')}"
    if name == "Write":
        content = str(args.get("content", ""))
        return f"**Write** `{args.get('file_path')}` ({len(content.splitlines())} lines)\n\n{fence(clip(content, max_lines * 2), 'nix')}"
    if name == "Edit":
        old, new = str(args.get("old_string", "")), str(args.get("new_string", ""))
        diff = "\n".join(["- " + line for line in old.splitlines()] + ["+ " + line for line in new.splitlines()])
        return f"**Edit** `{args.get('file_path')}`\n\n{fence(clip(diff, max_lines), 'diff')}"
    if name == "Read":
        return f"**Read** `{args.get('file_path')}`"
    return f"**{name}**\n\n{fence(json.dumps(args, indent=1)[:2000], 'json')}"


def observation_text(step: dict[str, Any]) -> str:
    parts: list[str] = []
    for result in (step.get("observation") or {}).get("results") or []:
        content = result.get("content")
        if isinstance(content, str):
            parts.append(content)
        elif isinstance(content, list):
            parts.extend(str(item.get("text", "")) for item in content if isinstance(item, dict))
    return "\n".join(parts)


def commands(step: dict[str, Any]) -> list[str]:
    return [str((c.get("arguments") or {}).get("command", "")) for c in step.get("tool_calls") or []]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("trial", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--notes", type=Path)
    parser.add_argument("--max-lines", type=int, default=40)
    opts = parser.parse_args()

    trial: Path = opts.trial
    result: dict[str, Any] = json.loads((trial / "result.json").read_text())
    trajectory: dict[str, Any] = json.loads((trial / "agent" / "trajectory.json").read_text())
    steps: list[dict[str, Any]] = trajectory["steps"]
    checks_path = trial / "verifier" / "checks.json"
    checks: dict[str, Any] | None = json.loads(checks_path.read_text()) if checks_path.exists() else None

    start = parse_time(steps[0]["timestamp"])
    execution = result.get("agent_execution") or {}
    minutes: float | None = None
    if execution.get("started_at") is not None and execution.get("finished_at") is not None:
        minutes = (parse_time(execution["finished_at"]) - parse_time(execution["started_at"])).total_seconds() / 60
    rewards = (result.get("verifier_result") or {}).get("rewards") or {}
    llm_calls = sum(int(s.get("llm_call_count") or 0) for s in steps)
    tool_calls = sum(len(s.get("tool_calls") or []) for s in steps)
    cost = (trajectory.get("final_metrics") or {}).get("total_cost_usd")

    def stamp(step: dict[str, Any]) -> str:
        seconds = int((parse_time(step["timestamp"]) - start).total_seconds())
        return f"{seconds // 60:02d}:{seconds % 60:02d}"

    # Heuristic: a command queries the reference if it calls the guest helper more often than it targets port 3222.
    ref_steps = [s for s in steps if any(len(REFERENCE.findall(c)) > len(CANDIDATE.findall(c)) for c in commands(s))]
    build_steps = [s for s in steps if any(BUILD.search(c) for c in commands(s))]
    check_steps = [s for s in steps if any(CHECK.search(c) for c in commands(s))]
    cand_steps = [s for s in steps if any(CANDIDATE.search(c) for c in commands(s))]

    out: list[str] = [f"# Trace: {result.get('trial_name')}", ""]
    rows = [
        ("Task", result.get("task_name")),
        ("Model", (result.get("agent_info") or {}).get("model_info", {}).get("name")),
        ("Reward", rewards.get("reward")),
        ("Agent minutes", f"{minutes:.1f}" if minutes is not None else "n/a"),
        ("ATIF steps / LLM calls / tool calls", f"{len(steps)} / {llm_calls} / {tool_calls}"),
        ("Cost (USD, ATIF estimate)", f"{cost:.2f}" if isinstance(cost, (int, float)) else "n/a"),
        ("Steps querying the reference (heuristic)", f"{len(ref_steps)} (last at step {ref_steps[-1]['step_id']}, {stamp(ref_steps[-1])})" if ref_steps else "0"),
        ("Steps with check-replica / build-replica / candidate shell", f"{len(check_steps)} / {len(build_steps)} / {len(cand_steps)}"),
    ]
    if checks is not None:
        rows.append(("Verifier build / boot seconds", f"{checks['seconds'].get('build')} / {checks['seconds'].get('boot')}"))
    out += ["| Field | Value |", "|---|---|", *[f"| {k} | {v} |" for k, v in rows], ""]

    if checks is not None:
        failed = [c for c in checks["checks"] if not c.get("passed")]
        out += [f"**Failed checks ({len(failed)} of {len(checks['checks'])}):**", ""]
        for c in failed:
            detail = " ".join(str(c.get("detail", "")).split())
            detail = detail[-160:] if len(detail) > 160 else detail
            out.append(f"- `{c['name']}` ({c.get('origin')}): `{detail.replace('`', '')}`")
        out.append("")

    if opts.notes is not None and opts.notes.exists():
        out += [opts.notes.read_text().rstrip(), ""]

    out += ["## Steps", ""]
    for step in steps:
        source = step.get("source")
        out.append(f"### step {step['step_id']} · {stamp(step)} · {source}")
        out.append("")
        message = str(step.get("message") or "").strip()
        if source == "user":
            out += [fence(clip(message, opts.max_lines), "text"), ""]
            continue
        if message:
            out += ["> " + line for line in message.splitlines()] + [""]
        for call in step.get("tool_calls") or []:
            out += [render_call(call, opts.max_lines), ""]
        obs = observation_text(step)
        if obs.strip():
            out += ["<details><summary>observation</summary>", "", fence(clip(obs, opts.max_lines), "text"), "", "</details>", ""]
    opts.out.write_text("\n".join(out) + "\n")
    print(f"wrote {opts.out} ({len(steps)} steps)")


if __name__ == "__main__":
    main()
