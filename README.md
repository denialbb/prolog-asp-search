# prolog-asp-search

Exam project for **Artificial Intelligence and Laboratory** (a.y. 2025–2026),
*Logic Programming and Answer Set Programming* module.

The repository contains the two required activities:

1. **Prolog** — a generic implementation and comparative analysis of **A\*** and
   **IDA\*** on two domains: a labyrinth with multiple exits and the 8-puzzle.
2. **ASP (Clingo)** — a tournament scheduler for a Pokémon League with dynamic
   arrivals, BYE handling, and score-balanced pairings.

Everything is written in English: identifiers, comments, tests, report, and
slides.

---

## 1. Requirements

| Tool | Version used | Purpose |
|---|---|---|
| SWI-Prolog | 10.0.2 | search engines, domains, plunit tests |
| Python | 3.12 (CI: 3.11) | ASP driver and Python tests |
| Clingo (Python) | 5.8.2 | ASP solving through the Python API |
| Typst | 0.15.1 | report and slides |

```bash
python -m pip install -r requirements-dev.txt
```

The Python package `clingo` bundles the solver; the standalone `clingo`
binary is only needed for the command-line examples below.

---

## 2. Repository layout

```
prolog/
  search/                 generic engines, independent of any domain
    search_common.pl      options, optional domain hooks, statistics
    a_star.pl             A* with lazy deletion and reopening
    ida_star.pl           IDA* with path-only cycle checking
  domains/
    labyrinth/            grid domain, heuristics, three maps
    puzzle8/              8-puzzle domain, heuristics, twelve instances
  benchmarks/
    bench.pl              reproducible benchmark matrix and CSV writer
    results/              frozen benchmark output
asp/
  tournament_common.lp    shared generate-test constraints
  tournament.lp           official lexicographic objective
  tournament_sum.lp       sum-of-differences baseline
  driver.py               CLI, validation, multi-round harness, UNSAT diagnosis
  instances/              progressive round instances and an infeasible case
tests/
  test_search.pl          engine contract, reopening, limits
  test_labyrinth.pl       map invariants, heuristics, BFS oracle
  test_puzzle8.pl         parity, heuristics, BFS oracle
  test_tournament.py      ASP invariants, objective contrast, multi-round
  test_complexity.py      per-function cyclomatic complexity
report/report.typ         Typst report
slides/slides.typ         Typst presentation
```

---

## 3. Activity 1 — A\* and IDA\* in Prolog

### 3.1 Problem contract

The engines only know this interface:

```prolog
Problem = problem(DomainModule, Config)

initial_state(+Problem, -State).
goal_test(+Problem, +State).
successors(+Problem, +State, -Moves).   % move(Action, Cost, NextState)
heuristic(+Problem, +State, -H).        % admissible, non-negative
state_key(+Problem, +State, -Key).      % ground canonical key
state_label(+Problem, +State, -Label).  % human-readable
```

Engines:

```prolog
a_star(+Problem, +Options, -Result, -Stats).
ida_star(+Problem, +Options, -Result, -Stats).
```

`Result` is `solved(Path, Cost)`, `no_path`, or `limit_exceeded`. `Path` is a
list of `step(Action, Cost, State)` terms from the successor of the initial
state to the goal; the initial state is implicit. Options are
`heuristic(Name)`, `max_expansions(N)`, and `timeout(Seconds)`.

### 3.2 Implementation notes

**A\*** uses `library(heaps)` with key `f(F, -G, Seq)`: smaller `f` wins, ties
prefer the larger `g`, and a monotonic sequence number makes the order
deterministic. `library(heaps)` has no decrease-key, so improved successors are
pushed again and stale entries are discarded lazily when popped. Best `g`
values and parent pointers live in `library(assoc)`; a cheaper path to an
already expanded state reopens it. The goal test runs on pop, not on
generation, which preserves optimality for an admissible but inconsistent
heuristic.

**IDA\*** starts at `h(start)` and raises the threshold to the smallest `f`
that exceeded the previous bound. Cycle checking uses only the current path, so
memory is linear in depth but states can be re-expanded through different
branches. Every visit counts as an expansion; iterations and maximum depth are
reported separately.

Both engines expose `expanded`, `generated`, `stale`, `reopened`,
`max_frontier`, `iterations`, `max_depth`, `cpu`, `wall`, `solution_cost`, and
`path_length` in the statistics dict.

### 3.3 Domains

**Labyrinth.** Maps are modules exporting `cols/1`, `rows/1`, `start/1`,
`exit/1` (one or more facts), and `blocked/1`. States are `pos(Row, Column)`,
1-based. Moves are the four orthogonal neighbours with unit cost. The
heuristics take the minimum Manhattan or Euclidean distance over every exit;
an unreachable exit can only lower the estimate, so it does not break
admissibility. Three maps ship with the project:

| Map | Size | Exits | Optimal cost |
|---|---|---|---|
| `labyrinth_default_map` | 10×10 | 2 reachable | 16 |
| `labyrinth_multi_exit_map` | 9×9 | 2 reachable + 1 sealed | 12 |
| `labyrinth_open_map` | 8×8 | 2 reachable | 7 |

The multi-exit map contains an exit inside a sealed room, which exercises the
“minimum over all exits” rule and the unreachable-exit handling.

**8-puzzle.** States are flat nine-element lists in row-major order with `0`
as the blank; the goal is `[1,2,3,4,5,6,7,8,0]`. Moves swap the blank with an
orthogonal neighbour. Solvability is decided by inversion parity with the
blank removed before any search starts. The available heuristics are
`misplaced` and `manhattan`; both ignore the blank and are admissible and
consistent. Twelve solvable instances cover optimal costs from 2 to 16.

### 3.4 Tests

```bash
swipl -g run_tests -t halt tests/test_search.pl
swipl -g run_tests -t halt tests/test_labyrinth.pl
swipl -g run_tests -t halt tests/test_puzzle8.pl
```

The suites cover the engine contract, lazy deletion and reopening on
hand-built graphs, expansion and timeout limits, map invariants, move
legality, heuristic admissibility and consistency on every free cell, parity
rejection, and optimal-cost agreement with an independent breadth-first
oracle.

### 3.5 Benchmarks

```bash
swipl -g "bench:main" -t halt prolog/benchmarks/bench.pl
# shorter run:
swipl -g "bench:main([repetitions(3),timeout(30)])" -t halt \
      prolog/benchmarks/bench.pl
```

The matrix is 3 labyrinth maps × {Manhattan, Euclidean} × {A\*, IDA\*} plus
12 puzzle instances × {misplaced, Manhattan} × {A\*, IDA\*}: 60 configurations,
five repetitions each, 300 runs. The harness writes
`prolog/benchmarks/results/runs.csv` (one row per repetition) and
`summary.csv` (median counters per configuration). A 60-second timeout is the
default; all runs in the frozen results finish in about 14 seconds.

Representative medians:

| Domain / instance | Solver | Heuristic | Cost | Expanded | CPU (ms) |
|---|---|---|---:|---:|---:|
| labyrinth / default | A\* | Manhattan | 16 | 44 | 4.3 |
| labyrinth / default | A\* | Euclidean | 16 | 41 | 2.9 |
| labyrinth / default | IDA\* | Manhattan | 16 | 3,465 | 77.0 |
| labyrinth / default | IDA\* | Euclidean | 16 | 73,471 | 1,802.8 |
| 8-puzzle / medium_16 | A\* | Manhattan | 16 | 48 | 3.5 |
| 8-puzzle / medium_16 | IDA\* | Manhattan | 16 | 180 | 6.0 |
| 8-puzzle / medium_16 | IDA\* | misplaced | 16 | 2,419 | 65.8 |

The full analysis is in the report. The short version: A\* expands far fewer
nodes but keeps a frontier and parent maps; IDA\* uses linear memory but pays
for re-expansion, dramatically so on the labyrinth with the weaker Euclidean
estimate. On the 8-puzzle the two heuristics separate clearly—Manhattan
reduces both solvers' expansions by roughly an order of magnitude on the
hardest instances.

---

## 4. Activity 2 — ASP tournament scheduler

### 4.1 Input vocabulary

Each round instance contains the active players, the current standings in
wins, and the full cumulative history:

```prolog
round(1).
player(alice).
score(alice, 2).        % current wins
played(alice, bob).     % already played; unordered
had_bye(carol).         % BYE received in an earlier round
new_player(dave).       % optional: joined this round, also listed in player/1
```

Every active player has exactly one `score/2` fact; a new player starts at 0.
A BYE awards the same number of wins as a match victory.

### 4.2 Hard constraints

- canonical pairings `match(X, Y)` with `X < Y`;
- each player has at most one opponent;
- exactly one BYE on an odd field, none on an even field;
- the BYE player has no match;
- no repeated pairing (`played/2`, checked in both orientations);
- no repeated BYE (`had_bye/1`);
- no withdrawals: players who enter stay active.

### 4.3 Objectives

`asp/tournament.lp` is the official model and optimises lexicographically:

1. minimise the number of matches between players with different scores
   (equivalently, maximise equal-score pairings);
2. minimise the total absolute score difference;
3. minimise the score of the BYE player, so the lowest-standing eligible
   player receives the free win when the first two levels leave a choice.

`asp/tournament_sum.lp` keeps the same hard constraints and minimises only the
total absolute difference. It is the baseline for the report: the two models
are not equivalent, and the instance `a,b = 0`, `c,d = 1`, `e = 2`, `f = 3`
with `played(a,b)` makes the difference explicit. The official model returns
one equal-score pair and total difference 5; the sum model returns zero
equal-score pairs and total difference 3.

### 4.4 Running the scheduler

```bash
# official model on the first round
python asp/driver.py --instance asp/instances/round1.lp

# sum baseline, machine-readable output
python asp/driver.py --instance asp/instances/round1.lp --model sum --json

# write the cumulative instance for the next round
python asp/driver.py --instance asp/instances/round1.lp \
    --advance /tmp/round2.lp --win-points 1
```

When no explicit results are supplied, the lexicographically smaller player
identifier wins each match; this keeps the harness deterministic. Explicit
winners can be passed as a JSON list:

```json
[{"players": ["alice", "bob"], "winner": "alice"}]
```

On an infeasible instance the driver returns exit code 2 and reports what had
to be relaxed (a repeated BYE or a repeated pairing). The raw models can also
be run directly:

```bash
clingo asp/tournament.lp asp/instances/round1.lp \
       --opt-mode=optN --models=0
```

`score/2` stores wins, so the driver's `--win-points` is 1 by default. If a
course variant uses a 3-point table, pass `--win-points 3`; the ASP encoding
does not change because it only compares current scores.

### 4.5 Tests

```bash
pytest -v tests/
```

The ASP tests cover odd/even BYE counts, pairing uniqueness, canonical output,
repeated pairings and BYEs, the official-versus-sum counterexample, new-player
arrivals, the infeasible instance, the relaxation ladder, and the multi-round
harness (scores and history).

---

## 5. Report and slides

```bash
typst compile report/report.typ
typst compile slides/slides.typ
```

The report contains the design rationale, correctness arguments, the full
benchmark tables, the objective comparison, and the limitations. The slides
are a ten-minute summary of the same material.

---

## 6. Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request:

1. `flake8` for syntax-level errors;
2. the radon complexity report (the hard constraint is per function in
   `tests/test_complexity.py`);
3. the three plunit suites with SWI-Prolog;
4. the Python and ASP test suite with pytest.

Run the same checks locally with the commands in the sections above.
