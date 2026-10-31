from pathlib import Path
import pytest

try:
    import clingo
    HAS_CLINGO = True
except ImportError:
    HAS_CLINGO = False


def test_asp_directory_structure():
    """Verify presence of tournament encoding and instances directory."""
    asp_dir = Path(__file__).resolve().parent.parent / "asp"
    assert asp_dir.exists(), "asp/ directory must exist"
    assert (asp_dir / "instances").exists(), "asp/instances/ directory must exist"


@pytest.mark.xfail(reason="Tournament encoding (tournament.lp) under active development (TDD Red phase)", strict=False)
def test_tournament_odd_player_bye_constraint():
    """
    Contract test for the ASP tournament scheduler:
    With an odd number of players (5 players), exactly one player must receive BYE.
    """
    if not HAS_CLINGO:
        pytest.skip("clingo library not installed in test environment")

    lp_file = Path(__file__).resolve().parent.parent / "asp" / "tournament.lp"
    assert lp_file.exists(), "tournament.lp must exist"

    instance = """
    giocatore(lorenzo; emma; simone; diego; giada).
    punteggio(lorenzo, 0).
    punteggio(emma, 0).
    punteggio(simone, 0).
    punteggio(diego, 0).
    punteggio(giada, 0).
    """

    ctl = clingo.Control()
    ctl.load(str(lp_file))
    ctl.add("base", [], instance)
    ctl.ground([("base", [])])

    models = []
    with ctl.solve(yield_=True) as handle:
        for m in handle:
            models.append([str(sym) for sym in m.symbols(shown=True)])

    assert len(models) > 0, "Scheduler must find at least one valid pairing"
    # In each valid answer set, exactly one player receives BYE
    for m in models:
        byes = [sym for sym in m if sym.startswith("bye(")]
        assert len(byes) == 1, f"Expected exactly 1 BYE, got: {byes}"
