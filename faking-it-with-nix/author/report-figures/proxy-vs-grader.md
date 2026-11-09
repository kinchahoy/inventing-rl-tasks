# Headroom lives where the agent's local proxy is weaker than the grader

```mermaid
flowchart LR
  A[Agent reads reference<br/>minutes 0-7] --> B[Edit / build / boot loop<br/>against its own snapshot]
  B -->|local proxy green:<br/>build OK, own benchmark OK| C[Confident 'done'<br/>12-35 of 60 min]
  C --> D{Grader: behavioural diff<br/>vs reference}
  D -->|proxy == grader<br/>Lean| E[Passes, or uses the full budget]
  D -->|proxy weaker than grader<br/>Nix, Python| F[pass@3 = 0<br/>headroom]
  B -.->|0-3 reference queries<br/>after first edit| A
```

| Effort | Agent's proxy | Grader | Result |
|---|---|---|---|
| Lean | `isabelle build` | the same build | agents use 35-53 min; headroom gone once budgets loosen |
| Nix | build + boot green | behavioural diff vs reference | agents stop on green |
| Python | own benchmark (wrong size, in-process) | timed harness | Lark stops at 5-8 min |
