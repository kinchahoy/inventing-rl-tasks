# Candidate Pipeline

Find one strong Harbor task cheaply. Use [clarified-vision.md](clarified-vision.md) as the task contract. Keep this process lightweight and revise it from evidence.

## 1. Find runnable endpoints

First pass: Luna screens 2–3 endpoints from each of SymPy, NetworkX, pyperformance, Lark, and Pygments. Results go in [screening/first-pass.md](old/screening/first-pass.md).

Prefer public operations near the top of a library's computational logic: one meaningful parse, symbolic computation, graph analysis, or rendering operation. An endpoint should exercise substantial machinery, but touching the largest fraction of a library is not a goal. For pyperformance, use existing benchmark entry points; it is a suite rather than a library.

Use public API documentation, examples, and upstream workloads. Avoid deep implementation reading or optimization at this stage. Record the exact callable and revision/version, a reproducible workload, output check, setup/timing boundary, source link, and unresolved risks. Sample workload choices do not narrow the original API contract.

## 2. Survey execution mechanically

Measure the original endpoint unchanged: **one call on one input**, with no injected threads or concurrent independent calls. Use matching ordinary and free-threaded CPython builds, both restricted to one available CPU.

Use two input sizes and three timed invocations per size on each runtime. Aim for roughly ten seconds or less per endpoint in total. Preserve raw samples, mark the first call, and flag variability: initially, a sample range above 20% of the median or a sub-millisecond median is a warning to investigate, not a rejection rule.

Generate fresh equivalent mutable inputs outside timing; include everything the API call itself does. Document imports, reusable setup, caches, and any warmup rather than hiding work. Compare meaningful observable outputs where available; a discarded result or returned timer is a correctness limitation to record.

Serialize measurements on this machine. Record runtime builds, GIL mode after imports, affinity, input parameters, and errors. This pass identifies runnable workloads and sequential behavior. It cannot establish internal parallelization feasibility or difficulty.

If dependencies, runtimes, or workloads are unavailable, report that explicitly. Do not substitute invented timings or spend the screening budget building infrastructure.

## 3. Lightweight source filter

After the baseline survey, inspect the surviving implementations briefly. Check where computation occurs, native-code dominance, dependency structure, semantic constraints, and likely trivial shortcuts. Give each candidate an honest one-line reason to investigate or reject it. Do not claim high potential solely because its algorithm sounds complex.

## 4. Try cheap transformations

Give promising endpoints to coding agents for independent, short attempts at ordinary standard-library substitution, straightforward partitioning, or local accumulators. These attempts can happen across candidates in parallel; timing remains serialized.

Each attempt returns a patch, correctness evidence, measurements, and the specific remaining obstacle. A simple passing transformation suggests an easy task. A failed attempt is a lead, not headroom evidence. Prefer coupled dependency, representation, and scheduling problems over added line count or unrelated functions.

## 5. Prove one candidate and package it

Develop a passing reference for the strongest survivor. Establish exact compatibility, one-core performance, overall acceleration, and real multicore scaling on varied inputs. Set thresholds from demonstrated performance with noise margin. Target a complete verifier under ten seconds.

Final correctness checks must be robust and inexpensive: a small diverse hidden differential suite against the original, including ordinary, unusual valid, and relevant edge cases, plus targeted concurrency invariants. Check exact outputs and observable mutations/exceptions where applicable, on both runtimes. Share the roughly ten-second total verifier budget with performance checks. Survey output fingerprints are smoke checks, not this final validation.

Reuse the experiment's workload and correctness checks in one Harbor task. Hide verifier inputs, workload mix, and core allocations. Publish the behavioral contract and performance requirements. Confirm the environment and policy allow ordinary Python features; verifier defects are not agent failures.

**Do not leak likely test inputs.** Survey recipes, input sizes/shapes, seeds, distributions, timing tables, and workload-specific optimization hints are research-only artifacts. Do not copy them into the agent image, instructions, public checks, or example fixtures. Preserve the original API's full supported contract; do not disclose which part the verifier is likely to exercise. Review packaging for indirect hints as well as exposed test files.

## 6. Final headroom gate

Validate Oracle reward 1, no-op reward 0, and the Harbor checker. Freeze the task, run three generous Haiku attempts, and inspect the failures. Require pass@3 = 0 for the take-home. Retest material revisions. Preserve actual results and trajectories.

Current status lives in [handoff.md](handoff.md).
