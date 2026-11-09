"""Per-trial stats for Harbor jobs: reward, agent minutes, LLM turns, tool calls, tokens.

Reads each trial's result.json and its agent-agnostic ATIF trajectory (agent/trajectory.json), which
Harbor writes for every agent that supports it, including trials that timed out.
Usage: uv run lean-to-isabelle/job_stats.py jobs/<job> [jobs/<job> ...]
"""

import json
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path


def minutes(span: dict[str, str] | None) -> str:
    if span is None or span.get("finished_at") is None:
        return "-"
    start, end = (datetime.fromisoformat(span[k]) for k in ("started_at", "finished_at"))
    return f"{(end - start).total_seconds() / 60:.1f}"


def trial_stats(trial: Path) -> dict[str, str]:
    result = json.loads((trial / "result.json").read_text())
    rewards = (result.get("verifier_result") or {}).get("rewards") or {}
    usage = result.get("agent_result") or {}
    exception = result.get("exception_info") or {}
    out_tokens = usage.get("n_output_tokens")
    row = {
        "task": result.get("task_name", trial.name),
        "reward": str(rewards.get("reward", "-")),
        "agent_min": minutes(result.get("agent_execution")),
        "turns": "-",
        "tool_calls": "-",
        "top_tools": "-",
        "out_tokens": "-" if out_tokens is None else str(out_tokens),
        "exception": exception.get("exception_type", ""),
    }
    trajectory = trial / "agent" / "trajectory.json"
    if trajectory.is_file():
        steps = [
            s for s in json.loads(trajectory.read_text())["steps"] if s.get("source") == "agent"
        ]
        tools = Counter(c["function_name"] for s in steps for c in s.get("tool_calls") or [])
        row["turns"] = str(sum(int(s.get("llm_call_count", 1)) for s in steps))
        row["tool_calls"] = str(sum(tools.values()))
        row["top_tools"] = " ".join(f"{name}:{n}" for name, n in tools.most_common(3)) or "-"
    return row


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: job_stats.py jobs/<job> [jobs/<job> ...]")
    rows = [
        trial_stats(trial)
        for job in map(Path, sys.argv[1:])
        for trial in sorted(job.iterdir())
        if (trial / "result.json").is_file() and (trial / "config.json").is_file()
    ]
    if not rows:
        sys.exit("no trials found (expected jobs/<job>/<trial>/result.json)")
    columns = list(rows[0])
    widths = {c: max(len(c), *(len(r[c]) for r in rows)) for c in columns}
    print("  ".join(c.ljust(widths[c]) for c in columns))
    for row in rows:
        print("  ".join(row[c].ljust(widths[c]) for c in columns))


if __name__ == "__main__":
    main()
