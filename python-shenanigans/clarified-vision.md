# Research Vision: Automatic Parallelization of Ordinary Python

## 1. Objective

Find a real coding-agent capability gap and turn it into excellent, verifiable reinforcement-learning tasks.

Our starting hypothesis is **semantics-preserving, pure-Python to pure-Python optimization for free-threaded CPython**. Can an agent understand ordinary sequential code, restructure its computation, and achieve meaningful multicore scaling while preserving exact behavior and acceptable one-core performance?

The long-term vision is automatic performance engineering: programmers write readable, conventional code, and agents transform it to use CPUs, SIMD, GPUs, or heterogeneous hardware efficiently. This project tests one tractable part of that vision.

The immediate priority is demonstrated headroom, not commitment to this topic. If it produces weak or infeasible tasks, reconsider it quickly. SIMD and GPU tracks remain possible, but their runtimes, libraries, and permitted native operations require explicit agreement before experimentation.

## 2. Take-Home Context

This research take-home asks for a small sample pack of verifiable, long-horizon software-engineering tasks, evidence of current model failures, and a credible approach to producing 1,000 genuinely distinct tasks.

Research taste and judgment matter more than quantity. One excellent task is more valuable than several weak ones.

The specified model is **Claude Haiku 5.5 through Claude Code, with high reasoning effort**. For this assignment, headroom means **pass@3 = 0**: three independent attempts all fail. Preserve actual trajectories and verifier results.

Full agent evaluations are the final headroom gate, not the primary discovery method. First establish feasibility, verification quality, and plausible engineering depth cheaply.

The user manages the time and evaluation budget. Keep the research lightweight: no general UI, benchmark service, or production verifier platform.

## 3. Task Contract

### Pure Python to pure Python

Both the starting computational implementation and the transformed implementation must be written in Python. Free-threaded CPython provides multicore execution; the replacement must also work correctly on ordinary GIL-enabled CPython.

Allowed:

- Normal Python language features and standard-library modules, subject to the computation restrictions below.
- Threads, locks, queues, thread pools, and other standard synchronization tools.
- Substantial changes to algorithms, internal representations, data structures, and helper functions.
- Ordinary C-backed builtins and standard-library operations, including sorting, `heapq`, `bisect`, `collections`, `array`, and `itertools`.
- Existing project dependencies, with no new third-party dependencies.

Not allowed:

- Adding native extensions, JIT compilation, or custom compiled kernels.
- Loading native computational implementations through `ctypes` or similar mechanisms.
- Invoking a compiler, external executable, subprocess, or multiprocessing worker to perform the computation.
- Offloading computation to an external service.

These restrictions govern the submitted implementation, not the research tools or verifier infrastructure.

Allow ordinary Python programming rather than banning useful library operations to manufacture difficulty. If a standard-library substitution makes a candidate trivial, reject the candidate.

### Drop-in equivalence

Preserve the public API and exact observable behavior on all supported inputs: accepted types, return values, ordering, mutations, exceptions, and other specified effects. Do not narrow the contract or introduce approximate numerical results. Respect any tolerance already present in the original specification.

Custom comparisons, hashing, callbacks, and arithmetic can make execution order observable. Account for these where supported. Passing finite tests is evidence of correctness, not proof of equivalence on every input.

Keep existing installation requirements and GIL-enabled compatibility. A dependency-free original must remain dependency free.

### Performance

Require meaningful multicore scaling, substantial overall acceleration against the original, and no unacceptable one-core regression relative to the original on GIL-enabled CPython. Sequential optimization alone does not satisfy the task.

The current one-core target is `T_transformed_1 <= 1.05 * T_original`, a maximum 5% regression. Both series prompts and private verifier configurations must use this same limit.

Fix numerical thresholds only after establishing a passing reference implementation and allowing for measurement noise.

Final (2026-11-03): per timed row, single core `T_1 <= 1.05 * T_original`; each doubling of cores at least 1.10x end to end and 1.05x for constituent operations (replacing the earlier overall 1.15x and `1 + 0.4(N-1)` scaling limits); calibrated against one oracle per task on mi60.

## 4. Efficient, Repeatable Candidate Pipeline

Use a small, repeatable process rather than general infrastructure. Each surviving candidate should have a compact package: source references, a public contract, workload generation, correctness checks, measurements, and a passing transformation.

### A. Source screen

Start with [SymPy](https://github.com/sympy/sympy), [NetworkX](https://github.com/networkx/networkx), and [pyperformance](https://github.com/python/pyperformance), but look beyond mathematical code. Parsers, text processing, serialization, compression, rendering, query engines, and simulations may offer better problems.

Record for each plausible candidate:

| Field | Evidence |
|---|---|
| Source | Repository, revision, files, and functions |
| Contract | Computation and behavior that must be preserved |
| Workload | Realistic, quickly generated input family |
| Dependencies | Shared state, ordering constraints, reductions, and bottlenecks |
| Transformation | Plausible decomposition and required engineering changes |
| Verification | Existing tests, correctness reference, and unusual valid inputs |
| Risks | Trivial shortcuts, semantic uncertainty, and feasibility concerns |
| Measurements | Timings where available; otherwise explicitly marked hypotheses |
| Variation | Related problems requiring meaningfully different engineering |

Build the inventory incrementally. The earlier 15–25-candidate goal is possible breadth, not a prerequisite to experimentation or a quota to fill with weak entries. Do not impose a fixed domain mix.

Prioritize substantial, strongly sequential-looking code with potentially hidden parallelism. A scout's inability to identify a parallelization strategy is not a rejection criterion; mark feasibility unresolved. Reject clear poor fits such as dominant native-library computation, trivial thread-pool solutions, or difficulty caused mainly by artificial restrictions. Establish actual parallel feasibility later through reference implementation work.

### B. Minimal local experiment

For a promising candidate:

1. Run the original on a meaningful workload and check where time is spent.
2. Measure its GIL-enabled one-core baseline.
3. Prototype the transformation under free-threaded Python.
4. Compare correctness on varied inputs and measure one-core and multicore behavior.

Use this computer. A single timing observation and noisy results are acceptable for quick screening; label them preliminary. Do not repeatedly benchmark many versions of the original. Measure unmodified free-threaded overhead when it answers a concrete question, rather than making runtime-parity research a separate project.

Abandon candidates when experiments do not support useful scaling or acceptable one-core performance. Record why so subsequent experiments can reuse what we learned.

### C. Feasibility and engineering-depth gate

Before building a full task, require a correct transformation with measured acceleration and scaling, quick and credible verification, and substantive difficulty that survives ordinary standard-library access.

Assess depth through the source and prototype: which dependencies must be understood, representations changed, execution phases coordinated, and correctness or performance problems resolved? Mathematical sophistication or line count alone is weak evidence.

### D. Task packaging

Turn the surviving package into a Harbor task with clear instructions, a reproducible environment, hidden verification cases, and a passing Oracle. Reuse the experiment's workload and correctness machinery.

### E. Final validation and headroom gate

Validate Oracle and no-op behavior, run the task checker, then run the three full model attempts. Give the model a generous opportunity to solve the task, roughly 30–60 minutes and enough turns where appropriate.

Inspect actual failures. Environment failures, ambiguous instructions, and impossible thresholds are not capability headroom.

## 5. Scope and Long-Horizon Difficulty

Target migration of a substantial computational portion of a library, covering multiple public operations and the internal machinery they use. Begin at high-level endpoints and follow significant callees, shared helpers, representations, and execution phases. Isolated kernels are discovery anchors, not the desired final scope. Group overlapping endpoints into coherent subsystems and expand to nearby public operations that use the same machinery.

The horizon should arise naturally from understanding code, designing transformations, implementing coordinated changes, preserving behavior, debugging, profiling, and improving performance. Library-wide migration is a valid scope when the engineering warrants it; arbitrary line counts and unrelated optimization requests are weak proxies for difficulty.

Favor multiple functions sharing representations or execution phases and requiring coordinated changes. Document the public surface and implementation breadth rather than assuming a sophisticated algorithm alone provides sufficient scope.

Do not add elaborate concurrency APIs, unrelated maintenance work, or excessive edge cases solely to lengthen a task. A previous whole-factorization proposal risked testing library-maintenance complexity more than algorithmic parallelization; any such pivot should be deliberate.

Use coupled engineering decisions as a cheap indication of depth before evaluation. Trajectories provide the final evidence of headroom, not a prerequisite for screening candidates.

## 6. Verification and Measurement

### Environment and enforcement

Use uv-managed CPython 3.15 environments: a free-threaded build with the GIL disabled and a matching GIL-enabled baseline. Check the runtime mode rather than assuming it from the environment name.

A clean virtual environment containing only the original project's required dependencies helps validate installation requirements. It does **not** enforce computation restrictions: standard-library code can load native libraries, invoke executables, or launch processes. Check those restrictions through implementation review and focused execution controls where necessary. Do not build an elaborate sandbox before a concrete task needs it.

### Correctness and hidden cases

Test diverse inputs, including randomized, adversarial, and unusual valid cases. Use relevant upstream tests, differential comparisons, and targeted concurrency invariants. Confirm GIL-enabled and free-threaded behavior.

Keep verifier inputs, seeds, workload mix, and expected answers hidden. The agent may create its own tests and benchmarks. Publish the API, supported semantics, allowed techniques, and performance requirements without revealing likely test inputs or tailoring the contract to benchmark cases.

Research fixtures, sizes/shapes, distributions, timing tables, and workload-specific hints must stay out of agent-visible instructions, environments, public checks, and example fixtures. Preserve the full supported API contract without revealing which inputs are likely to be tested. Review task packaging for indirect leaks too.

### Performance

Internally investigate one, two, and four available CPU cores. The third-attempt tasks now state the core counts (N = 1, 2, 4) in the instruction and give the agent environment the same 4 CPUs, so what the agent can test matches what is graded; only inputs and the workload mix stay hidden. The implementation should adapt to available resources while preserving its public API.

Control available CPU capacity as well as worker configuration so apparent one-core execution cannot secretly use extra cores. Record:

- `T_original`: original implementation on one core of GIL-enabled CPython.
- `T_transformed_1`: transformed implementation on one core of free-threaded CPython.
- `T_transformed_N`: transformed implementation with N cores available under free-threaded CPython.

Measure:

- Overall acceleration: `T_original / T_transformed_N`.
- Actual multicore scaling: `T_transformed_1 / T_transformed_N`.
- One-core regression: `T_transformed_1 / T_original`.

Check that multicore benefits come from the transformation. Do not waste screening time exhaustively rerunning the sequential original at every core count.

Use varied workloads and calibrate thresholds against a passing implementation. Preliminary screening can use n=1; final checks should control allocations and repeat measurements enough to distinguish improvement from noise.

Account explicitly for setup, conversion, worker creation, and result assembly. Define any permitted amortization or worker reuse. Python still has warmup effects from specialization, caches, and lazy initialization: compare equivalent execution states and do not hide required work in untimed warmup. Check first-call correctness too.

Target **under ten seconds for a complete verifier run** (third-attempt verifiers use a provisional 900 s timeout because every timed sample runs in a fresh process; cost is unmeasured), including correctness and performance checks. If reliable validation really requires longer, explain why and discuss the exception. Keep broader final robustness checks separate from quick screening where appropriate.

### References

A correctness reference may use unrestricted tools to establish expected results. Performance experiments may investigate alternatives. The passing Harbor Oracle must satisfy the same implementation restrictions as the agent. Every retained task needs a genuine passing solution.

## 7. Harbor and Submission Requirements

Use [Harbor](https://harborframework.com/docs/getting-started) to package tasks, run agents, verify outcomes, and preserve trajectories.

Each task includes `instruction.md`, `task.toml`, `environment/Dockerfile`, `tests/test.sh`, and `solution/solve.sh`. The verifier writes its reward to `/logs/verifier/reward.txt` or the corresponding supported JSON output.

State all enforced requirements in the instructions. Hidden inputs and hardware allocations must not create hidden behavioral requirements.

Required runs for each retained task:

```bash
harbor run -p <task-path> -a oracle
harbor run -p <task-path> -a nop
harbor check <task-path> -m claude-haiku-5-5
harbor run -p <task-path> -a claude-code -m claude-haiku-5-5 \
  --ak reasoning_effort=high -k 3
```

The Oracle must earn reward 1, the no-op reward 0, and all three model attempts must fail for the assignment's headroom criterion. The checker supplements manual review; it does not prove task quality.

Analyze dependency mistakes, incorrect semantics, races, poor decomposition, synchronization or representation bottlenecks, and unsuccessful optimization iterations. Preserve every trial and Harbor's generated directory structure. Never fabricate trajectories.

Deliver one ZIP containing:

```text
samples/    Retained Harbor tasks
jobs/       Harbor-generated runs, results, and trajectories
archive/    Rejected built tasks useful to the research narrative
report/     Concise customer-facing report
```

Each retained task needs three model trials, a successful Oracle run, and an unsuccessful no-op run.

The report is **human-written**. Do not spend agent time drafting it. Research artifacts should help the user explain the capability gap, failures, task value, relevant external evidence, assumptions, automated steps, and scale plan.

## 8. Scaling and Research Judgment

Discovery can be broad, but the final family should express a coherent capability. Meaningful variation comes from different dependencies, representations, synchronization needs, algorithms, and realistic application constraints.

Changed seeds, arbitrary input sizes, and variable renaming are not distinct engineering tasks. Avoid a collection solvable by the same mechanical transformation.

Use the candidate pipeline to explain a credible route to 1,000 tasks: mining, feasibility filtering, reference implementation, correctness verification, performance calibration, headroom testing, deduplication, and human review. Identify what can be automated and what requires expert work. Do not promise fully automated scale without evidence.

Prioritize real capability gaps, reliable correctness, demonstrated performance feasibility, and substantive engineering. Keep experiments fast and records reusable. Build only enough machinery to compare a few candidates efficiently, and choose the next step from evidence rather than a rigid plan.
