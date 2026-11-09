"""Summarize Harbor claude-code trials: horizon (LLM calls, tool calls, build/boot loops), cost, score by origin.

Usage: uv run tools/trial-stats.py <job-or-trial-dir> [...]
"""

import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

# Bash commands that mark the inspect -> evaluate -> build -> boot loop.
LOOP_MARKERS = {
    "check-replica": r"check-replica",
    "build-replica": r"build-replica",
    "boot candidate": r"run-[\w-]+-vm",
    "guest shell": r"/opt/runtime/guest",
    "candidate shell": r"GUEST_SSH_PORT=3222",
}


def seconds(start: str | None, end: str | None) -> float | None:
    if start is None or end is None:
        return None
    return (datetime.fromisoformat(end) - datetime.fromisoformat(start)).total_seconds()


def trial_stats(trial: Path) -> dict[str, Any]:
    result = json.loads((trial / "result.json").read_text())
    steps: list[dict[str, Any]] = json.loads((trial / "agent" / "trajectory.json").read_text())["steps"]
    agent_steps = [s for s in steps if s.get("source") == "agent"]
    tools: Counter[str] = Counter()
    loops: Counter[str] = Counter()
    first_submission: str | None = None
    for step in agent_steps:
        for call in step.get("tool_calls") or []:
            tools[call["function_name"]] += 1
            args = json.dumps(call.get("arguments", {}))
            if call["function_name"] == "Bash":
                for label, pattern in LOOP_MARKERS.items():
                    loops[label] += bool(re.search(pattern, args))
            if (
                first_submission is None
                and "/app/submission/" in args
                and call["function_name"] in ("Write", "Edit", "Bash")
            ):
                first_submission = step["timestamp"]
    sidechain = sum(1 for s in agent_steps if (s.get("extra") or {}).get("is_sidechain"))
    prompts = [(s.get("metrics") or {}).get("prompt_tokens") or 0 for s in agent_steps]
    agent = result.get("agent_execution") or {}
    usage = result.get("agent_result") or {}
    checks_file = trial / "verifier" / "checks.json"
    by_origin: dict[str, list[int]] = {}
    failed: list[str] = []
    if checks_file.exists():
        raw = json.loads(checks_file.read_text()).get("checks", [])
        if isinstance(raw, dict):  # lean-to-isabelle: {gate: bool | detail string}; keep the boolean gates
            raw = [{"name": k, "passed": v} for k, v in raw.items() if isinstance(v, bool)]
        for check in raw:
            tally = by_origin.setdefault(check.get("origin", "recipe"), [0, 0])
            tally[0] += check["passed"]
            tally[1] += 1
            if not check["passed"]:
                failed.append(check["name"])
    started = agent.get("started_at") or (steps[0]["timestamp"] if steps else None)
    return {
        "trial": trial.name,
        "reward": (result.get("verifier_result") or {}).get("rewards"),
        "score_by_origin": {k: f"{p}/{n}" for k, (p, n) in by_origin.items()},
        "failed": failed,
        "agent_seconds": seconds(agent.get("started_at"), agent.get("finished_at")),
        "llm_calls": sum(int(s.get("llm_call_count") or 1) for s in agent_steps),
        "llm_calls_subagents": sidechain,
        "tool_calls": sum(tools.values()),
        "tools": dict(tools.most_common()),
        "loop": dict(loops),
        "first_submission_write_s": seconds(started, first_submission),
        "peak_prompt_tokens": max(prompts, default=0),
        "tokens": {k: usage.get(k) for k in ("n_input_tokens", "n_cache_tokens", "n_output_tokens")},
        "cost_usd": usage.get("cost_usd"),
        "exception": (result.get("exception_info") or {}).get("exception_type"),
    }


def trials(path: Path) -> list[Path]:
    if (path / "agent" / "trajectory.json").exists():
        return [path]
    found = sorted(p.parent.parent for p in path.glob("*/agent/trajectory.json"))
    if not found:
        raise SystemExit(f"No claude-code trajectories under {path} (oracle/nop trials have none).")
    return found


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for arg in sys.argv[1:]:
        for trial in trials(Path(arg)):
            print(json.dumps(trial_stats(trial), indent=2))


if __name__ == "__main__":
    main()
