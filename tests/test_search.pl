%% Engine-level tests: duplicate handling, reopening, limits, and statistics.
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../prolog/search/a_star').
:- use_module('../prolog/search/ida_star').
:- use_module('support/graph_domain').

%% path_cost(+Path, -Cost) is det.
path_cost([], 0).
path_cost([step(_, StepCost, _)|Rest], Cost) :-
    path_cost(Rest, RestCost),
    Cost is StepCost + RestCost.

%% path_valid(+Problem, +Domain, +Start, +Path) is semidet.
%
%  Replay a path through the domain contract: every step must be an offered
%  move and the final state must satisfy goal_test. Used as an independent
%  check of the reconstructed paths.
path_valid(Problem, Domain, Start, Path) :-
    replay(Problem, Domain, Start, Path).

replay(Problem, Domain, State, []) :-
    once(call(Domain:goal_test(Problem, State))).
replay(Problem, Domain, State, [step(Action, Cost, Next)|Rest]) :-
    once(call(Domain:successors(Problem, State, Moves))),
    memberchk(move(Action, Cost, Next), Moves),
    replay(Problem, Domain, Next, Rest).

:- begin_tests(search_engines).

test(a_star_reopens_inconsistent_state) :-
    a_star(problem(graph, reopen), [], Result, Stats),
    Result = solved(Path, 3),
    path_cost(Path, 3),
    path_valid(problem(graph, reopen), graph_domain, s, Path),
    Stats.status == solved,
    Stats.iterations =:= 1,
    Stats.reopened >= 1,
    Stats.expanded >= 5.

test(a_star_discards_stale_frontier_entries) :-
    a_star(problem(graph, stale), [], solved(Path, 6), Stats),
    path_cost(Path, 6),
    Stats.stale >= 1,
    Stats.reopened >= 1.

test(a_star_goal_is_tested_on_pop) :-
    a_star(problem(graph, reopen), [], solved(_, Cost), _),
    Cost =:= 3.

test(ida_star_matches_a_star_on_inconsistent_graph) :-
    ida_star(problem(graph, reopen), [], Result, Stats),
    Result = solved(Path, 3),
    path_valid(problem(graph, reopen), graph_domain, s, Path),
    Stats.status == solved,
    Stats.iterations >= 2,
    Stats.expanded >= 3.

test(a_star_is_deterministic) :-
    a_star(problem(graph, reopen), [], Result1, _),
    a_star(problem(graph, reopen), [], Result2, _),
    Result1 == Result2.

test(stats_exposes_required_keys) :-
    a_star(problem(graph, reopen), [], _, Stats),
    forall(member(Key, [expanded, generated, stale, reopened, max_frontier,
                        iterations, cpu, wall, solution_cost, path_length]),
           get_dict(Key, Stats, _)).

test(a_star_respects_max_expansions) :-
    a_star(problem(graph, reopen), [max_expansions(4)], limit_exceeded, Stats),
    Stats.expanded =:= 4.

test(a_star_accepts_goal_on_last_allowed_expansion) :-
    a_star(problem(graph, reopen), [max_expansions(5)], solved(_, 3), _).

test(ida_star_respects_max_expansions) :-
    ida_star(problem(graph, reopen), [max_expansions(3)], limit_exceeded, Stats),
    Stats.expanded =:= 3.

test(a_star_respects_timeout) :-
    a_star(problem(graph, reopen), [timeout(0)], limit_exceeded, _).

test(ida_star_respects_timeout) :-
    ida_star(problem(graph, reopen), [timeout(0)], limit_exceeded, _).

:- end_tests(search_engines).
