%% Labyrinth domain tests: map invariants, move legality, heuristic
%% properties, optimal costs, and unreachable exits.
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../prolog/domains/labyrinth/labyrinth').
:- use_module('../prolog/domains/labyrinth/maps/labyrinth_default_map', []).
:- use_module('../prolog/domains/labyrinth/maps/labyrinth_multi_exit_map', []).
:- use_module('../prolog/domains/labyrinth/maps/labyrinth_open_map', []).
:- use_module('support/labyrinth_sealed_map', []).
:- use_module('../prolog/search/a_star').
:- use_module('../prolog/search/ida_star').

%% maps(-Maps) is det.
maps([labyrinth_default_map, labyrinth_multi_exit_map, labyrinth_open_map]).

%% heuristic_names(-Names) is det.
heuristic_names([manhattan, euclidean]).

%% map_problem(+Map, +Heuristic, -Problem) is det.
map_problem(Map, Heuristic, problem(labyrinth, lab(Map, Heuristic))).

%% map_dimensions(+Map, -Rows, -Cols) is det.
map_dimensions(Map, Rows, Cols) :-
    call(Map:rows(Rows)),
    call(Map:cols(Cols)).

%% free_cells(+Map, -Cells) is det.
free_cells(Map, Cells) :-
    map_dimensions(Map, Rows, Cols),
    findall(pos(Row, Column),
            ( between(1, Rows, Row),
              between(1, Cols, Column),
              \+ call(Map:blocked(pos(Row, Column))) ),
            Cells).

%% oracle_distance(+Problem, +Start, -Distance) is det.
%
%  Breadth-first shortest distance from Start to any exit, used as an
%  independent optimality and admissibility oracle on small maps.
oracle_distance(Problem, Start, Distance) :-
    distance_search(Problem, [Start-0], [], Distance).

distance_search(Problem, [State-Depth|Open], Visited, Distance) :-
    ( once(labyrinth:goal_test(Problem, State)) ->
        Distance = Depth
    ; labyrinth:state_key(Problem, State, Key),
      ( memberchk(Key, Visited) ->
          distance_search(Problem, Open, Visited, Distance)
      ;
          labyrinth:successors(Problem, State, Moves),
          NextDepth is Depth + 1,
          findall(Next-NextDepth, member(move(_, _, Next), Moves), More),
          append(Open, More, Open1),
          distance_search(Problem, Open1, [Key|Visited], Distance)
      )
    ).

%% path_valid(+Problem, +Path) is semidet.
path_valid(Problem, Path) :-
    labyrinth:initial_state(Problem, Start),
    replay(Problem, Start, Path).

replay(Problem, State, []) :-
    once(labyrinth:goal_test(Problem, State)).
replay(Problem, State, [step(Action, Cost, Next)|Rest]) :-
    once(labyrinth:successors(Problem, State, Moves)),
    memberchk(move(Action, Cost, Next), Moves),
    replay(Problem, Next, Rest).

:- begin_tests(labyrinth_domain).

test(dimensions_are_positive, [forall(member(Map, [labyrinth_default_map,
                                                   labyrinth_multi_exit_map,
                                                   labyrinth_open_map]))]) :-
    map_dimensions(Map, Rows, Cols),
    Rows > 0,
    Cols > 0.

test(map_invariants, [forall(member(Map, [labyrinth_default_map,
                                          labyrinth_multi_exit_map,
                                          labyrinth_open_map]))]) :-
    labyrinth:map_valid(Map).

test(start_is_inside_and_free, [forall(member(Map, [labyrinth_default_map,
                                                    labyrinth_multi_exit_map,
                                                    labyrinth_open_map]))]) :-
    map_dimensions(Map, Rows, Cols),
    call(Map:start(pos(Row, Column))),
    Row >= 1, Row =< Rows,
    Column >= 1, Column =< Cols,
    \+ call(Map:blocked(pos(Row, Column))).

test(exits_are_inside_and_free, [forall(member(Map, [labyrinth_default_map,
                                                     labyrinth_multi_exit_map,
                                                     labyrinth_open_map]))]) :-
    map_dimensions(Map, Rows, Cols),
    forall(call(Map:exit(pos(Row, Column))),
           ( Row >= 1, Row =< Rows,
             Column >= 1, Column =< Cols,
             \+ call(Map:blocked(pos(Row, Column))) )).

test(at_least_two_exits, [forall(member(Map, [labyrinth_default_map,
                                              labyrinth_multi_exit_map,
                                              labyrinth_open_map]))]) :-
    findall(Exit, call(Map:exit(Exit)), Exits),
    length(Exits, Count),
    Count >= 2.

test(successors_are_legal_moves, [forall(member(Map, [labyrinth_default_map,
                                                     labyrinth_multi_exit_map,
                                                     labyrinth_open_map]))]) :-
    Problem = problem(labyrinth, lab(Map, manhattan)),
    labyrinth:initial_state(Problem, Start),
    labyrinth:successors(Problem, Start, Moves),
    Moves \== [],
    map_dimensions(Map, Rows, Cols),
    forall(member(move(Action, Cost, pos(Row, Column)), Moves),
           ( memberchk(Action, [up, right, down, left]),
             Cost =:= 1,
             Row >= 1, Row =< Rows,
             Column >= 1, Column =< Cols,
             \+ call(Map:blocked(pos(Row, Column))) )).

test(multi_exit_map_has_one_unreachable_exit) :-
    Problem = problem(labyrinth, lab(labyrinth_multi_exit_map, manhattan)),
    \+ labyrinth:reachable(Problem, pos(1, 9)),
    labyrinth:reachable(Problem, pos(9, 5)),
    labyrinth:reachable(Problem, pos(9, 9)).

test(solvable_maps_are_detected) :-
    forall(member(Map, [labyrinth_default_map, labyrinth_multi_exit_map,
                        labyrinth_open_map]),
           labyrinth:solvable(problem(labyrinth, lab(Map, manhattan)))).

test(sealed_map_is_not_solvable) :-
    \+ labyrinth:solvable(problem(labyrinth,
                                  lab(labyrinth_sealed_map, manhattan))).

test(heuristics_are_zero_at_exits, [forall(member(Map, [labyrinth_default_map,
                                                        labyrinth_multi_exit_map,
                                                        labyrinth_open_map]))]) :-
    forall(( member(Heuristic, [manhattan, euclidean]),
             call(Map:exit(Exit)) ),
           ( map_problem(Map, Heuristic, Problem),
             labyrinth:heuristic(Problem, Exit, H),
             H =:= 0 )).

test(heuristics_are_admissible_on_free_cells) :-
    forall(member(Map, [labyrinth_default_map, labyrinth_multi_exit_map,
                        labyrinth_open_map]),
           ( map_problem(Map, manhattan, Problem),
             free_cells(Map, Cells),
             forall(( member(State, Cells),
                      member(Heuristic, [manhattan, euclidean]) ),
                    ( map_problem(Map, Heuristic, HeuristicProblem),
                      oracle_distance(Problem, State, Exact),
                      labyrinth:heuristic(HeuristicProblem, State, H),
                      H =< Exact )) )).

test(heuristics_are_consistent_on_free_cells) :-
    forall(member(Map, [labyrinth_default_map, labyrinth_multi_exit_map,
                        labyrinth_open_map]),
           ( free_cells(Map, Cells),
             forall(( member(State, Cells),
                      member(Heuristic, [manhattan, euclidean]) ),
                    ( map_problem(Map, Heuristic, Problem),
                      labyrinth:heuristic(Problem, State, H),
                      forall(labyrinth:successors(Problem, State, Moves),
                             forall(member(move(_, Cost, Next), Moves),
                                    ( labyrinth:heuristic(Problem, Next, NextH),
                                      H =< Cost + NextH ))) )) )).

test(a_star_and_ida_star_agree) :-
    forall(member(Map, [labyrinth_default_map, labyrinth_multi_exit_map,
                        labyrinth_open_map]),
           forall(member(Heuristic, [manhattan, euclidean]),
                  ( map_problem(Map, Heuristic, Problem),
                    a_star(Problem, [heuristic(Heuristic)], AResult, _),
                    ida_star(Problem, [heuristic(Heuristic)], IResult, _),
                    AResult = solved(APath, ACost),
                    IResult = solved(IPath, ICost),
                    ACost =:= ICost,
                    path_valid(Problem, APath),
                    path_valid(Problem, IPath) ))).

test(a_star_matches_breadth_first_oracle) :-
    forall(member(Map, [labyrinth_default_map, labyrinth_multi_exit_map,
                        labyrinth_open_map]),
           forall(member(Heuristic, [manhattan, euclidean]),
                  ( map_problem(Map, Heuristic, Problem),
                    labyrinth:initial_state(Problem, Start),
                    oracle_distance(Problem, Start, Exact),
                    a_star(Problem, [heuristic(Heuristic)],
                           solved(_, Cost), _),
                    Cost =:= Exact ))).

test(ida_star_matches_breadth_first_oracle) :-
    forall(member(Map, [labyrinth_default_map, labyrinth_multi_exit_map,
                        labyrinth_open_map]),
           forall(member(Heuristic, [manhattan, euclidean]),
                  ( map_problem(Map, Heuristic, Problem),
                    labyrinth:initial_state(Problem, Start),
                    oracle_distance(Problem, Start, Exact),
                    ida_star(Problem, [heuristic(Heuristic)],
                             solved(_, Cost), _),
                    Cost =:= Exact ))).

test(no_path_when_no_exit_is_reachable) :-
    Problem = problem(labyrinth, lab(labyrinth_sealed_map, manhattan)),
    a_star(Problem, [], no_path, AStats),
    ida_star(Problem, [], no_path, IStats),
    AStats.expanded =:= 0,
    IStats.expanded =:= 0.

test(a_star_respects_expansion_limit) :-
    Problem = problem(labyrinth, lab(labyrinth_default_map, manhattan)),
    a_star(Problem, [max_expansions(1)], limit_exceeded, Stats),
    Stats.expanded =:= 1.

test(ida_star_respects_expansion_limit) :-
    Problem = problem(labyrinth, lab(labyrinth_default_map, manhattan)),
    ida_star(Problem, [max_expansions(1)], limit_exceeded, Stats),
    Stats.expanded =:= 1.

:- end_tests(labyrinth_domain).
