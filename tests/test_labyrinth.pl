:- begin_tests(labyrinth_rules).

:- ensure_loaded('../prolog/domains/labyrinth/maps/labirinto_default.pl').

test(dimensions_valid) :-
    num_col(Cols),
    num_righe(Rows),
    Cols > 0,
    Rows > 0.

test(start_is_valid_cell) :-
    iniziale(pos(R, C)),
    num_col(Cols),
    num_righe(Rows),
    R >= 1, R =< Rows,
    C >= 1, C =< Cols,
    \+ occupata(pos(R, C)).

test(goal_is_valid_cell) :-
    finale(pos(R, C)),
    num_col(Cols),
    num_righe(Rows),
    R >= 1, R =< Rows,
    C >= 1, C =< Cols,
    \+ occupata(pos(R, C)).

test(start_distinct_from_goal) :-
    iniziale(Start),
    finale(Goal),
    Start \= Goal.

test(obstacles_within_bounds) :-
    num_col(Cols),
    num_righe(Rows),
    forall(occupata(pos(R, C)),
           (R >= 1, R =< Rows, C >= 1, C =< Cols)).

:- end_tests(labyrinth_rules).
