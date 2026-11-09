# Ablations

Copies of a task with one prompt sentence changed; same images and verifier. Not in TASKS.
Run with `../tools/pilot ablations/<variant>/<task-id> <minutes> --job-name <name>`.

| Variant | Added sentence | Question |
|---|---|---|
| node31-process-nudge | "Before you finish, compare the reference and your replica systematically, and fix every difference you find." | Are misses a self-checking gap? |
| node31-downscope | "Focus on the applications and the tools their operators use; base-OS tuning is out of scope." | Is breadth the difficulty? (Changes the task: OS-level checks still graded.) |
| node31-commands | Graded paragraph adds "stock utilities nobody here is likely to need" (don't matter) and "the commands people are likely to use for this machine's job" (do) | Does stating the commands contract fix `amtool_operator`? (Candidate wording for all prompts.) |
| node17-no-clock / node31-no-clock | First-line sentence "You have 60 minutes." removed (Harbor still stops at 60 min) | Is the headroom partly agents misjudging the clock? (2 of 7 final core trials stopped citing time early) |
