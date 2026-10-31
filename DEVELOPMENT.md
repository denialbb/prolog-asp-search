# Development Guidelines and Project Standards

Internal guidelines for development and for the code quality expected in the
exam deliverable.

---

## 1. Code and comment standards

- **Declarative, modular style.**
  - Prolog: keep the domain-agnostic search engine (`prolog/search/`) clearly
    separated from the domain logic (`prolog/domains/`). Write short clauses,
    use green cuts only, and keep naming consistent in English.
  - ASP (Clingo): follow the formal *generate–test–optimize* structure, with
    explicit pairings and constraints.
- **Descriptive, non-historical comments.**
  - Document predicate semantics (arguments and modes `+`, `-`, `?`) and the
    theoretical rationale of each heuristic (admissibility, consistency).
  - Historical comments or change logs in source code are forbidden (for
    example “fixed bug with…”, “changed by…”, “previous attempt commented
    out”). Version control belongs to Git history.
  - Remove unused code blocks.

---

## 2. Test-driven development and cyclomatic complexity

- **Red–green flow.**
  - Define preliminary test cases in `tests/` for domains, heuristics, and
    tournament constraints.
  - Track the transition from failing tests (red) to passing tests (green) as
    the algorithmic modules are integrated.
- **Cyclomatic complexity.**
  - Keep the logical complexity of each component within strict limits
    (complexity per function ≤ 10).
  - The automated tests (`tests/test_complexity.py` via `radon` and `flake8`)
    verify that support and benchmark code stays below the maximum threshold.

---

## 3. CI automation (GitHub Actions)

The CI pipeline (`.github/workflows/ci.yml`) runs on every push to `main` and
on every pull request:

1. Unit tests for the Prolog engines and domains with `plunit` on SWI-Prolog
   (`swipl -g run_tests -t halt ...`).
2. ASP constraint verification with Clingo through the `pytest` suite.
3. Cyclomatic-complexity and syntax linting with `radon` and `flake8`.

To run the checks locally before pushing:

```bash
swipl -g run_tests -t halt tests/test_search.pl
swipl -g run_tests -t halt tests/test_labyrinth.pl
swipl -g run_tests -t halt tests/test_puzzle8.pl
pytest -v tests/
flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
radon cc -s -a -nb tests/ asp/ prolog/
```

---

## 4. Academic integrity of the deliverable

The source code and the report/slides will be examined by the instructors:

- No markers, boilerplate, or patterns attributable to automatic generators
  or artificial intelligence.
- A clean, atomic, descriptive commit history following the standard
  convention (`feat:`, `fix:`, `test:`, `docs:`).
- Documentation and comments written with academic rigour and full conceptual
  command of the algorithms.
