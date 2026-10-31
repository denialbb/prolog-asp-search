import importlib.util
import json
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

pytest.importorskip("clingo")

ROOT = Path(__file__).resolve().parent.parent
DRIVER_PATH = ROOT / "asp" / "driver.py"


def _load_driver():
    spec = importlib.util.spec_from_file_location("tournament_driver", DRIVER_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


driver = _load_driver()


def instance(text):
    return textwrap.dedent(text).strip() + "\n"


def solve(text, model="official"):
    outcome = driver.solve(instance(text), model)
    assert outcome.status == "optimal", f"{model} model returned {outcome.status}"
    return outcome


def incident_counts(schedule):
    counts = {}
    for first, second in schedule.matches:
        counts[first] = counts.get(first, 0) + 1
        counts[second] = counts.get(second, 0) + 1
    return counts


def total_difference(facts, schedule):
    return sum(
        abs(facts.scores[first] - facts.scores[second])
        for first, second in schedule.matches
    )


def equal_pair_count(facts, schedule):
    return sum(
        facts.scores[first] == facts.scores[second]
        for first, second in schedule.matches
    )


def test_asp_directory_structure():
    asp_dir = ROOT / "asp"
    assert asp_dir.is_dir()
    assert (asp_dir / "instances").is_dir()
    assert (asp_dir / "tournament.lp").is_file()
    assert (asp_dir / "tournament_sum.lp").is_file()
    assert (asp_dir / "driver.py").is_file()


def test_odd_field_has_exactly_one_bye():
    text = (ROOT / "asp" / "instances" / "round1.lp").read_text(encoding="utf-8")
    outcome = driver.solve(text, "official")
    assert outcome.status == "optimal"
    for schedule in outcome.schedules:
        assert schedule.bye is not None
        assert len(schedule.matches) == 2


def test_even_field_has_no_bye():
    outcome = solve(
        """
        player(a; b; c; d).
        score(a, 0). score(b, 0). score(c, 0). score(d, 0).
        """
    )
    for schedule in outcome.schedules:
        assert schedule.bye is None
        assert len(schedule.matches) == 2


def test_non_bye_players_have_exactly_one_opponent():
    text = (ROOT / "asp" / "instances" / "round3.lp").read_text(encoding="utf-8")
    facts = driver.read_facts(text)
    outcome = driver.solve(text, "official")
    for schedule in outcome.schedules:
        assert driver.validate(facts, schedule) == []
        counts = incident_counts(schedule)
        for player in facts.players:
            if player == schedule.bye:
                assert player not in counts
            else:
                assert counts[player] == 1


def test_no_repeated_pairings_or_byes():
    text = (ROOT / "asp" / "instances" / "round3.lp").read_text(encoding="utf-8")
    facts = driver.read_facts(text)
    outcome = driver.solve(text, "official")
    for schedule in outcome.schedules:
        for pair in schedule.matches:
            assert pair not in facts.played
        assert schedule.bye not in facts.had_bye


def test_matches_are_canonical_and_unique():
    outcome = solve(
        """
        player(a; b; c; d; e).
        score(a, 3). score(b, 2). score(c, 2). score(d, 1). score(e, 0).
        """
    )
    for schedule in outcome.schedules:
        assert list(schedule.matches) == sorted(set(schedule.matches))
        for first, second in schedule.matches:
            assert first < second


def test_objective_counterexample():
    # The two zero-score players have already met, so the only equal-score
    # pair still available is c-d. The official model keeps that pair and
    # accepts a larger total gap; the sum baseline breaks the equal pair to
    # reduce the total absolute difference.
    text = """
        player(a; b; c; d; e; f).
        score(a, 0). score(b, 0). score(c, 1). score(d, 1).
        score(e, 2). score(f, 3).
        played(a, b).
    """
    facts = driver.read_facts(instance(text))

    official = solve(text, "official")
    for schedule in official.schedules:
        assert equal_pair_count(facts, schedule) == 1
        assert total_difference(facts, schedule) == 5
        assert len(schedule.unequal_pairs) == 2

    baseline = solve(text, "sum")
    for schedule in baseline.schedules:
        assert equal_pair_count(facts, schedule) == 0
        assert total_difference(facts, schedule) == 3


def test_new_player_is_included_and_stays_active():
    text = (ROOT / "asp" / "instances" / "round2.lp").read_text(encoding="utf-8")
    facts = driver.read_facts(text)
    assert "frank" in facts.players
    assert facts.new_players == frozenset({"frank"})

    outcome = driver.solve(text, "official")
    schedule = outcome.representative
    assert schedule.bye == "frank" or any(
        "frank" in pair for pair in schedule.matches
    )

    next_text = driver.build_next_instance(
        facts, schedule, win_points=1, results={("alice", "frank"): "frank"}
    )
    next_facts = driver.read_facts(next_text)
    assert "frank" in next_facts.players
    assert next_facts.scores["frank"] == facts.scores["frank"] + 1


def test_infeasible_instance_is_reported_cleanly():
    path = ROOT / "asp" / "instances" / "infeasible.lp"
    text = path.read_text(encoding="utf-8")
    outcome = driver.solve(text, "official")
    assert outcome.status == "unsat"

    result = subprocess.run(
        [sys.executable, str(DRIVER_PATH), "--instance", str(path), "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 2
    payload = json.loads(result.stdout)
    assert payload["status"] == "unsat"
    assert any("repeated BYE" in hint for hint in payload["diagnosis"])


def test_relaxation_ladder_reports_repeated_pairing(tmp_path):
    path = tmp_path / "complete_history.lp"
    path.write_text(
        instance(
            """
            player(a; b; c; d).
            score(a, 0). score(b, 1). score(c, 2). score(d, 3).
            played(a, b). played(a, c). played(a, d).
            played(b, c). played(b, d). played(c, d).
            """
        ),
        encoding="utf-8",
    )
    result = subprocess.run(
        [sys.executable, str(DRIVER_PATH), "--instance", str(path), "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 2
    payload = json.loads(result.stdout)
    assert payload["status"] == "unsat"
    assert any("repeated pairings" in hint for hint in payload["diagnosis"])


def test_multi_round_harness_updates_scores_and_history():
    text = (ROOT / "asp" / "instances" / "round1.lp").read_text(encoding="utf-8")
    facts = driver.read_facts(text)
    schedule = driver.solve(text, "official").representative
    assert schedule.matches == (("alice", "bob"), ("carol", "dave"))
    assert schedule.bye == "erin"

    next_text = driver.build_next_instance(
        facts,
        schedule,
        win_points=2,
        results={("alice", "bob"): "alice", ("carol", "dave"): "carol"},
    )
    next_facts = driver.read_facts(next_text)

    assert next_facts.round_number == facts.round_number + 1
    assert next_facts.scores == {
        **facts.scores,
        "alice": facts.scores["alice"] + 2,
        "carol": facts.scores["carol"] + 2,
        "erin": facts.scores["erin"] + 2,
    }
    assert next_facts.played == facts.played | set(schedule.matches)
    assert next_facts.had_bye == facts.had_bye | {"erin"}


def test_default_winner_is_smaller_identifier():
    text = (ROOT / "asp" / "instances" / "round1.lp").read_text(encoding="utf-8")
    facts = driver.read_facts(text)
    schedule = driver.solve(text, "official").representative
    next_text = driver.build_next_instance(facts, schedule)
    next_facts = driver.read_facts(next_text)
    assert next_facts.scores["alice"] == facts.scores["alice"] + 1
    assert next_facts.scores["carol"] == facts.scores["carol"] + 1
    assert next_facts.scores["erin"] == facts.scores["erin"] + 1
    assert next_facts.scores["bob"] == facts.scores["bob"]


@pytest.mark.parametrize("model", ["official", "sum"])
@pytest.mark.parametrize("name", ["round1.lp", "round2.lp", "round3.lp"])
def test_committed_instances_are_valid(name, model):
    text = (ROOT / "asp" / "instances" / name).read_text(encoding="utf-8")
    facts = driver.read_facts(text)
    outcome = driver.solve(text, model)
    assert outcome.status == "optimal"
    for schedule in outcome.schedules:
        assert driver.validate(facts, schedule) == []
