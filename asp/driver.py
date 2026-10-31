#!/usr/bin/env python3
"""Command-line driver and validation harness for the ASP tournament models.

The driver loads a round instance, solves it with the official lexicographic
model or the sum-of-differences baseline, checks the schedule invariants, and
prints the result. With --advance it also writes the instance for the next
round by applying the chosen winners and the BYE award.

Typical use::

    python asp/driver.py --instance asp/instances/round1.lp
    python asp/driver.py --instance asp/instances/round1.lp --model sum --json
    python asp/driver.py --instance asp/instances/round1.lp \
        --advance asp/instances/round2.lp --win-points 1

When no explicit results are supplied, the player with the lexicographically
smaller identifier wins each match. Explicit results use a JSON list; matches
omitted from the list keep the default winner::

    [{"players": ["alice", "bob"], "winner": "alice"}]

The BYE always awards the same number of wins as a match victory.
"""

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import clingo

ASP_DIR = Path(__file__).resolve().parent
MODEL_FILES = {
    "official": ASP_DIR / "tournament.lp",
    "sum": ASP_DIR / "tournament_sum.lp",
}
SOLVER_ARGS = ["--opt-mode=optN", "--models=0", "--warn=none"]
FACT_SHOWS = """
#show round/1.
#show player/1.
#show score/2.
#show played/2.
#show had_bye/1.
#show new_player/1.
"""


@dataclass(frozen=True)
class RoundFacts:
    round_number: int | None
    players: tuple[str, ...]
    scores: dict[str, int]
    played: frozenset[tuple[str, str]]
    had_bye: frozenset[str]
    new_players: frozenset[str]


@dataclass(frozen=True)
class Schedule:
    matches: tuple[tuple[str, str], ...]
    bye: str | None
    unequal_pairs: tuple[tuple[str, str], ...]
    cost: tuple[int, ...]


@dataclass(frozen=True)
class SolveOutcome:
    status: str
    schedules: tuple[Schedule, ...] = ()

    @property
    def representative(self) -> Schedule | None:
        return self.schedules[0] if self.schedules else None


def canonical_pair(first: str, second: str) -> tuple[str, str]:
    return (first, second) if first < second else (second, first)


def _is_function(symbol, name: str, arity: int) -> bool:
    return (
        symbol.type == clingo.SymbolType.Function
        and symbol.name == name
        and len(symbol.arguments) == arity
    )


def read_facts(instance_text: str) -> RoundFacts:
    """Parse the input vocabulary of an instance into a canonical record."""
    program = instance_text + FACT_SHOWS
    control = clingo.Control(["--models=1", "--warn=none"])
    control.add("base", [], program)
    control.ground([("base", [])])
    with control.solve(yield_=True) as handle:
        model = next(iter(handle), None)
        handle.get()
    if model is None:
        raise ValueError("instance facts are inconsistent and have no model")

    round_number = None
    players = []
    scores = {}
    played = set()
    had_bye = set()
    new_players = set()
    for symbol in model.symbols(shown=True):
        arguments = symbol.arguments
        if _is_function(symbol, "round", 1):
            round_number = int(str(arguments[0]))
        elif _is_function(symbol, "player", 1):
            players.append(str(arguments[0]))
        elif _is_function(symbol, "score", 2):
            player, value = str(arguments[0]), int(str(arguments[1]))
            if scores.get(player, value) != value:
                raise ValueError(f"player {player!r} has conflicting scores")
            scores[player] = value
        elif _is_function(symbol, "played", 2):
            played.add(canonical_pair(str(arguments[0]), str(arguments[1])))
        elif _is_function(symbol, "had_bye", 1):
            had_bye.add(str(arguments[0]))
        elif _is_function(symbol, "new_player", 1):
            new_players.add(str(arguments[0]))

    return RoundFacts(
        round_number=round_number,
        players=tuple(sorted(players)),
        scores=scores,
        played=frozenset(played),
        had_bye=frozenset(had_bye),
        new_players=frozenset(new_players),
    )


def _schedule_from_model(model) -> Schedule:
    matches = []
    byes = []
    unequal = []
    for symbol in model.symbols(shown=True):
        arguments = symbol.arguments
        if _is_function(symbol, "match", 2):
            matches.append((str(arguments[0]), str(arguments[1])))
        elif _is_function(symbol, "bye", 1):
            byes.append(str(arguments[0]))
        elif _is_function(symbol, "unequal_pair", 2):
            unequal.append((str(arguments[0]), str(arguments[1])))
    if len(byes) > 1:
        raise RuntimeError(f"answer set contains several BYEs: {byes}")
    return Schedule(
        matches=tuple(sorted(matches)),
        bye=byes[0] if byes else None,
        unequal_pairs=tuple(sorted(unequal)),
        cost=tuple(int(value) for value in model.cost),
    )


def solve(
    instance_text: str,
    model: str = "official",
    relax_bye: bool = False,
    relax_repeat_pair: bool = False,
) -> SolveOutcome:
    """Solve one round, returning all distinct optimal schedules."""
    control = clingo.Control(SOLVER_ARGS)
    control.load(str(MODEL_FILES[model]))
    control.add("base", [], instance_text)
    control.ground([("base", [])])
    control.assign_external(clingo.Function("relax_bye"), relax_bye)
    control.assign_external(
        clingo.Function("relax_repeat_pair"), relax_repeat_pair
    )

    found = {}
    with control.solve(yield_=True) as handle:
        for candidate in handle:
            schedule = _schedule_from_model(candidate)
            key = (schedule.matches, schedule.bye)
            previous = found.get(key)
            if previous is None or schedule.cost < previous.cost:
                found[key] = schedule
        result = handle.get()

    if not found:
        status = "unsat" if not result.satisfiable else "unknown"
        return SolveOutcome(status=status)

    best_cost = min(schedule.cost for schedule in found.values())
    optimal = [schedule for schedule in found.values() if schedule.cost == best_cost]
    optimal.sort(key=lambda schedule: (schedule.matches, schedule.bye or ""))
    return SolveOutcome(status="optimal", schedules=tuple(optimal))


def _check_players(facts: RoundFacts, schedule: Schedule, errors: list[str]):
    players = set(facts.players)
    for first, second in schedule.matches:
        if first >= second:
            errors.append(f"match {first}-{second} is not canonical")
        if first not in players or second not in players:
            errors.append(f"match {first}-{second} uses an inactive player")
        if canonical_pair(first, second) in facts.played:
            errors.append(f"pair {first}-{second} already played")


def _check_bye(facts: RoundFacts, schedule: Schedule, errors: list[str]):
    expected = 1 if len(facts.players) % 2 == 1 else 0
    actual = 1 if schedule.bye is not None else 0
    if actual != expected:
        errors.append(f"expected {expected} BYE(s), found {actual}")
    if schedule.bye is None:
        return
    if schedule.bye not in facts.players:
        errors.append(f"BYE player {schedule.bye} is not active")
    if schedule.bye in facts.had_bye:
        errors.append(f"player {schedule.bye} already received a BYE")
    if any(schedule.bye in pair for pair in schedule.matches):
        errors.append(f"BYE player {schedule.bye} also has a match")


def validate(facts: RoundFacts, schedule: Schedule) -> list[str]:
    """Return the invariant violations of a schedule, if any."""
    errors = []
    _check_players(facts, schedule, errors)
    _check_bye(facts, schedule, errors)

    if len(set(schedule.matches)) != len(schedule.matches):
        errors.append("schedule contains a duplicate match")
    incident = {}
    for first, second in set(schedule.matches):
        for player in (first, second):
            incident[player] = incident.get(player, 0) + 1
    for player, count in incident.items():
        if count > 1:
            errors.append(f"player {player} has {count} matches")

    covered = set(incident)
    if schedule.bye is not None:
        covered.add(schedule.bye)
    missing = set(facts.players) - covered
    if missing:
        errors.append(f"players without a match or BYE: {sorted(missing)}")
    return errors


def _basic_hints(facts: RoundFacts) -> list[str]:
    if not facts.players:
        return ["the instance lists no active players"]
    if len(facts.players) % 2 == 1 and all(
        player in facts.had_bye for player in facts.players
    ):
        return [
            "the field is odd but every active player already received a BYE"
        ]
    return []


def _relaxation_hints(instance_text: str, facts: RoundFacts) -> list[str]:
    relaxed_bye = solve(instance_text, relax_bye=True)
    if relaxed_bye.status == "optimal":
        bye = relaxed_bye.representative.bye
        if bye in facts.had_bye:
            return [
                f"allowing a repeated BYE makes the round feasible; "
                f"the BYE would fall on {bye}, who already had one"
            ]
        return ["relaxing BYE uniqueness does not change feasibility"]

    relaxed_both = solve(
        instance_text, relax_bye=True, relax_repeat_pair=True
    )
    if relaxed_both.status != "optimal":
        return [
            "no schedule exists even after relaxing BYE uniqueness and "
            "repeated pairings"
        ]
    repeated = [
        pair
        for pair in relaxed_both.representative.matches
        if pair in facts.played
    ]
    if repeated:
        shown = ", ".join(f"{first}-{second}" for first, second in repeated)
        return [
            "a repeated BYE alone is not enough; allowing repeated pairings "
            f"makes the round feasible (needed: {shown})"
        ]
    return [
        "a repeated BYE alone is not enough, but relaxing repeated "
        "pairings makes the round feasible"
    ]


def _diagnose(instance_text: str, facts: RoundFacts) -> tuple[str, ...]:
    hints = _basic_hints(facts)
    hints.extend(_relaxation_hints(instance_text, facts))
    return tuple(hints)


def read_results(path: str) -> dict[tuple[str, str], str]:
    """Read explicit winners from a JSON list of {players, winner} objects."""
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    results = {}
    for entry in raw:
        first, second = entry["players"]
        results[canonical_pair(first, second)] = entry["winner"]
    return results


def _winners(
    schedule: Schedule, results: dict[tuple[str, str], str]
) -> dict[tuple[str, str], str]:
    winners = {}
    for pair in schedule.matches:
        winner = results.get(pair, min(pair))
        if winner not in pair:
            raise ValueError(f"winner {winner!r} does not play in {pair}")
        winners[pair] = winner
    extra = set(results) - set(schedule.matches)
    if extra:
        raise ValueError(f"results mention unknown matches: {sorted(extra)}")
    return winners


def _updated_scores(
    facts: RoundFacts,
    winners: dict[tuple[str, str], str],
    bye: str | None,
    win_points: int,
) -> dict[str, int]:
    scores = dict(facts.scores)
    for winner in winners.values():
        scores[winner] += win_points
    if bye is not None:
        scores[bye] += win_points
    return scores


def _render_instance(
    round_number: int,
    players: tuple[str, ...],
    scores: dict[str, int],
    played: set[tuple[str, str]],
    had_bye: set[str],
) -> str:
    lines = [
        f"% Round {round_number}: cumulative history and standings.",
        "",
        f"round({round_number}).",
        "",
    ]
    lines.extend(f"player({player})." for player in players)
    lines.append("")
    lines.extend(f"score({player}, {scores[player]})." for player in players)
    lines.append("")
    lines.extend(f"played({first}, {second})." for first, second in sorted(played))
    if had_bye:
        lines.append("")
        lines.extend(f"had_bye({player})." for player in sorted(had_bye))
    return "\n".join(lines) + "\n"


def build_next_instance(
    facts: RoundFacts,
    schedule: Schedule,
    win_points: int = 1,
    results: dict[tuple[str, str], str] | None = None,
) -> str:
    """Apply the round results and render the cumulative next-round instance.

    Every active player remains active, including players who joined this
    round; a player is never removed. History and scores are cumulative.
    """
    winners = _winners(schedule, results or {})
    scores = _updated_scores(facts, winners, schedule.bye, win_points)
    played = set(facts.played) | set(schedule.matches)
    had_bye = set(facts.had_bye)
    if schedule.bye is not None:
        had_bye.add(schedule.bye)
    return _render_instance(
        (facts.round_number or 0) + 1,
        facts.players,
        scores,
        played,
        had_bye,
    )


def _schedule_payload(schedule: Schedule) -> dict:
    return {
        "cost": list(schedule.cost),
        "matches": [list(pair) for pair in schedule.matches],
        "bye": schedule.bye,
        "unequal_pairs": [list(pair) for pair in schedule.unequal_pairs],
    }


def _unsat_payload(args, facts, hints) -> dict:
    return {
        "status": "unsat",
        "model": args.model,
        "round": facts.round_number,
        "diagnosis": list(hints),
    }


def _optimal_payload(args, facts, outcome, next_path) -> dict:
    schedule = outcome.representative
    return {
        "status": "optimal",
        "model": args.model,
        "round": facts.round_number,
        "players": list(facts.players),
        "scores": dict(sorted(facts.scores.items())),
        "schedule": _schedule_payload(schedule),
        "optimal_schedules": len(outcome.schedules),
        "next_instance": str(next_path) if next_path else None,
    }


def _print_human(args, facts, outcome, next_path):
    schedule = outcome.representative
    print(f"Model: {args.model}")
    if facts.round_number is not None:
        print(f"Round: {facts.round_number}")
    print(f"Cost: {list(schedule.cost)}")
    print("Matches:")
    for first, second in schedule.matches:
        print(f"  {first} vs {second}")
    print(f"BYE: {schedule.bye if schedule.bye is not None else 'none'}")
    print(f"Optimal schedules: {len(outcome.schedules)}")
    if next_path:
        print(f"Next instance: {next_path}")


def _emit_unsat(args, instance_text, facts, outcome) -> int:
    hints = _diagnose(instance_text, facts)
    if args.json:
        print(json.dumps(_unsat_payload(args, facts, hints), indent=2))
    else:
        print(f"Status: {outcome.status}")
        for hint in hints:
            print(f"Diagnosis: {hint}")
    return 2


def _emit_invalid(errors) -> int:
    print("error: the model produced an invalid schedule:")
    for error in errors:
        print(f"  {error}")
    return 1


def _advance_if_requested(args, facts, outcome) -> str | None:
    if not args.advance:
        return None
    results = read_results(args.results) if args.results else {}
    next_text = build_next_instance(
        facts, outcome.representative, args.win_points, results
    )
    Path(args.advance).write_text(next_text, encoding="utf-8")
    return args.advance


def _run(args) -> int:
    try:
        instance_text = Path(args.instance).read_text(encoding="utf-8")
        facts = read_facts(instance_text)
        outcome = solve(instance_text, args.model)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"error: {error}")
        return 1

    if outcome.status != "optimal":
        return _emit_unsat(args, instance_text, facts, outcome)

    errors = [
        error
        for schedule in outcome.schedules
        for error in validate(facts, schedule)
    ]
    if errors:
        return _emit_invalid(errors)

    try:
        next_path = _advance_if_requested(args, facts, outcome)
    except (OSError, ValueError, KeyError) as error:
        print(f"error: cannot advance the tournament: {error}")
        return 1

    if args.json:
        print(json.dumps(_optimal_payload(args, facts, outcome, next_path),
                         indent=2))
    else:
        _print_human(args, facts, outcome, next_path)
    return 0


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Solve one round of the ASP tournament scheduler."
    )
    parser.add_argument("--instance", required=True, help="round instance .lp")
    parser.add_argument(
        "--model",
        choices=sorted(MODEL_FILES),
        default="official",
        help="official lexicographic model or sum baseline (default: official)",
    )
    parser.add_argument(
        "--win-points",
        type=int,
        default=1,
        help="wins awarded for a victory or a BYE (default: 1)",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON")
    parser.add_argument(
        "--advance",
        metavar="PATH",
        help="write the cumulative instance for the next round",
    )
    parser.add_argument(
        "--results",
        metavar="PATH",
        help="JSON list of explicit winners used by --advance",
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    if args.win_points < 0:
        print("error: --win-points must be non-negative")
        return 1
    if args.results and not args.advance:
        print("error: --results requires --advance")
        return 1
    return _run(args)


if __name__ == "__main__":
    raise SystemExit(main())
