%% 8-puzzle domain tests: parity, move legality, heuristics, and solver
%% agreement against a breadth-first oracle.
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- use_module('../prolog/domains/puzzle8/puzzle8').
:- use_module('../prolog/domains/puzzle8/instances/puzzle8_instances').
:- use_module('../prolog/search/a_star').
:- use_module('../prolog/search/ida_star').

%% heuristic_names(-Names) is det.
heuristic_names([misplaced, manhattan]).

%% puzzle_problem(+State, +Heuristic, -Problem) is det.
puzzle_problem(State, Heuristic, problem(puzzle8, p8(State, Heuristic))).

%% oracle_distance(+Start, -Distance) is det.
%
%  Breadth-first distance to the goal over the puzzle contract. Used on a few
%  instances as an independent optimality and admissibility oracle.
oracle_distance(Start, Distance) :-
    distance_search([Start-0], [], Distance).

distance_search([State-Depth|Open], Visited, Distance) :-
    ( puzzle8:goal_test(problem(puzzle8, p8(State, misplaced)), State) ->
        Distance = Depth
    ; puzzle8:state_key(problem(puzzle8, p8(State, misplaced)), State, Key),
      ( memberchk(Key, Visited) ->
          distance_search(Open, Visited, Distance)
      ;
          puzzle8:successors(problem(puzzle8, p8(State, misplaced)), State,
                             Moves),
          NextDepth is Depth + 1,
          findall(Next-NextDepth, member(move(_, _, Next), Moves), More),
          append(Open, More, Open1),
          distance_search(Open1, [Key|Visited], Distance)
      )
    ).

%% path_valid(+Problem, +Path) is semidet.
path_valid(Problem, Path) :-
    puzzle8:initial_state(Problem, Start),
    replay(Problem, Start, Path).

replay(Problem, State, []) :-
    once(puzzle8:goal_test(Problem, State)).
replay(Problem, State, [step(Action, Cost, Next)|Rest]) :-
    once(puzzle8:successors(Problem, State, Moves)),
    memberchk(move(Action, Cost, Next), Moves),
    replay(Problem, Next, Rest).

%% blank_count(+State, -Count) is det.
blank_count(State, Count) :-
    aggregate_all(count, (member(0, State)), Count).

:- begin_tests(puzzle8_domain).

test(goal_state_is_valid) :-
    puzzle8:goal_state(Goal),
    puzzle8:valid_state(Goal),
    puzzle8:goal_test(problem(puzzle8, p8(Goal, misplaced)), Goal).

test(state_key_is_ground) :-
    puzzle8:state_key(problem(puzzle8, p8([1,2,3,4,5,6,7,0,8], misplaced)),
                      [1,2,3,4,5,6,7,0,8], Key),
    ground(Key),
    Key == [1,2,3,4,5,6,7,0,8].

test(state_label_is_readable) :-
    puzzle8:state_label(problem(puzzle8, p8([1,2,3,4,5,6,7,8,0], misplaced)),
                        [1,2,3,4,5,6,7,8,0], Label),
    atom(Label).

test(successors_swap_blank_with_adjacent_tile) :-
    State = [1,2,3,4,0,5,6,7,8],
    once(puzzle8:successors(problem(puzzle8, p8(State, misplaced)), State,
                            Moves)),
    Moves \== [],
    forall(member(move(Action, Cost, Next), Moves),
           ( memberchk(Action, [up, right, down, left]),
             Cost =:= 1,
             blank_count(Next, 1),
             msort(Next, Sorted),
             Sorted == [0,1,2,3,4,5,6,7,8] )).

test(inversions_of_goal_is_zero) :-
    puzzle8:inversions([1,2,3,4,5,6,7,8], Count),
    Count =:= 0.

test(inversions_counts_reversed_pair) :-
    puzzle8:inversions([1,2,3,4,5,6,8,7], Count),
    Count =:= 1.

test(parity_accepts_goal_and_known_instance) :-
    puzzle8:solvable_state([1,2,3,4,5,6,7,8,0]),
    puzzle8:solvable_state([1,2,3,4,5,6,0,7,8]).

test(parity_rejects_single_swap) :-
    \+ puzzle8:solvable_state([1,2,3,4,5,6,8,7,0]).

test(unsolvable_instance_is_rejected_without_search) :-
    State = [1,2,3,4,5,6,8,7,0],
    Problem = problem(puzzle8, p8(State, manhattan)),
    a_star(Problem, [], no_path, AStats),
    ida_star(Problem, [], no_path, IStats),
    AStats.expanded =:= 0,
    IStats.expanded =:= 0.

test(heuristics_are_zero_at_goal) :-
    Goal = [1,2,3,4,5,6,7,8,0],
    forall(member(Heuristic, [misplaced, manhattan]),
           ( puzzle_problem(Goal, Heuristic, Problem),
             puzzle8:heuristic(Problem, Goal, H),
             H =:= 0 )).

test(heuristic_values_on_two_move_state) :-
    State = [1,2,3,4,5,6,0,7,8],
    puzzle8:heuristic(problem(puzzle8, p8(State, misplaced)), State, 2),
    puzzle8:heuristic(problem(puzzle8, p8(State, manhattan)), State, 2).

test(manhattan_dominates_misplaced) :-
    forall(instance(_, _, State),
           ( puzzle8:heuristic(problem(puzzle8, p8(State, misplaced)),
                               State, Misplaced),
             puzzle8:heuristic(problem(puzzle8, p8(State, manhattan)),
                               State, Manhattan),
             Manhattan >= Misplaced )).

test(heuristics_are_admissible_on_samples) :-
    forall(member(State, [[1,2,3,4,5,6,0,7,8],
                          [0,1,2,5,6,3,4,7,8],
                          [0,1,2,4,7,3,8,5,6],
                          [1,5,4,0,3,2,7,8,6]]),
           ( oracle_distance(State, Exact),
             forall(member(Heuristic, [misplaced, manhattan]),
                    ( puzzle_problem(State, Heuristic, Problem),
                      puzzle8:heuristic(Problem, State, H),
                      H =< Exact )) )).

test(a_star_and_ida_star_agree_on_instances) :-
    forall(instance(_, _, State),
           forall(member(Heuristic, [misplaced, manhattan]),
                  ( puzzle_problem(State, Heuristic, Problem),
                    a_star(Problem, [heuristic(Heuristic)], AResult, _),
                    ida_star(Problem, [heuristic(Heuristic)], IResult, _),
                    AResult = solved(APath, ACost),
                    IResult = solved(IPath, ICost),
                    ACost =:= ICost,
                    path_valid(Problem, APath),
                    path_valid(Problem, IPath),
                    length(APath, PathLength),
                    PathLength =:= ACost ))).

test(a_star_matches_breadth_first_oracle) :-
    forall(member(State, [[1,2,3,4,5,6,0,7,8],
                          [1,2,3,5,6,8,4,7,0],
                          [0,7,2,5,1,3,8,4,6]]),
           ( oracle_distance(State, Exact),
             forall(member(Heuristic, [misplaced, manhattan]),
                    ( puzzle_problem(State, Heuristic, Problem),
                      a_star(Problem, [heuristic(Heuristic)],
                             solved(_, Cost), _),
                      Cost =:= Exact )) )).

test(a_star_respects_expansion_limit) :-
    State = [1,2,3,4,5,6,0,7,8],
    Problem = problem(puzzle8, p8(State, manhattan)),
    a_star(Problem, [max_expansions(1)], limit_exceeded, Stats),
    Stats.expanded =:= 1.

test(ida_star_respects_expansion_limit) :-
    State = [1,2,3,4,5,6,0,7,8],
    Problem = problem(puzzle8, p8(State, manhattan)),
    ida_star(Problem, [max_expansions(1)], limit_exceeded, Stats),
    Stats.expanded =:= 1.

:- end_tests(puzzle8_domain).
