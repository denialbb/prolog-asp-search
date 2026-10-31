%% ida_star.pl - generic IDA* with path-only cycle checking.
%%
%% Design notes:
%%   * The first threshold is h(start); every iteration is a depth-first
%%     search that cuts off nodes with f = g + h above the threshold. The next
%%     threshold is the smallest f that exceeded the current one, so an
%%     admissible heuristic makes the sequence converge to an optimal cost.
%%   * Only the current path is used for cycle checking. A state reached by a
%%     different branch is expanded again, which is the textbook memory-bound
%%     behaviour: space is O(depth), time can be much larger than A*.
%%   * Every visit counts as an expansion, including re-expansions across
%%     iterations. Max depth and peak stack size are tracked separately.
%%   * Domains may export solvable/1; the engine calls it before searching so
%%     unsolvable 8-puzzle instances and sealed labyrinths fail fast.
:- module(ida_star, [ida_star/4]).

:- use_module(library(lists)).
:- use_module(search_common).

%% ida_star(+Problem, +Options, -Result, -Stats) is det.
%
%  Options:
%    heuristic(Name)      select a domain heuristic (optional)
%    max_expansions(N)    stop after N expanded nodes (default 1,000,000)
%    timeout(Seconds)     wall-clock budget per call (default 60)
%
%  Result is solved(Path, Cost), no_path, or limit_exceeded, with the same
%  path representation as a_star/4.
ida_star(Problem0, Options, Result, Stats) :-
    once(ida_star_(Problem0, Options, Result, Stats)).

%% ida_star_(+Problem, +Options, -Result, -Stats) is det.
%
%  Implementation of ida_star/4. The once/1 in the public wrapper is the
%  determinism commitment: every engine branch is intended to be single-valued.
ida_star_(Problem0, Options, Result, Stats) :-
    problem_with_heuristic(Problem0, Options, Problem),
    Problem = problem(Domain, _),
    option_or(Options, max_expansions, 1000000, MaxExpansions),
    option_or(Options, timeout, 60, Timeout),
    statistics(cputime, Cpu0),
    time_now(Wall0),
    Deadline is Wall0 + Timeout,
    new_counters(Counters0),
    ( precheck_unsolvable(Problem) ->
        Result = no_path,
        Counters = Counters0
    ;
        call(Domain:initial_state(Problem, Start)),
        call(Domain:state_key(Problem, Start, StartKey)),
        call(Domain:heuristic(Problem, Start, H0)),
        Threshold is H0,
        Counters1 = Counters0.put(max_frontier, 1),
        ida_loop(Problem, Domain, Start, StartKey, Threshold,
                 MaxExpansions, Deadline, Counters1, Result, Counters)
    ),
    statistics(cputime, Cpu1),
    time_now(Wall1),
    Cpu is Cpu1 - Cpu0,
    Wall is Wall1 - Wall0,
    result_stats(Result, Counters, Cpu, Wall, Stats).

%% ida_loop(+Problem, +Domain, +Start, +StartKey, +Threshold, +MaxExpansions,
%%          +Deadline, +Counters0, -Result, -Counters) is det.
%
%  Run one threshold iteration and either finish or raise the threshold to the
%  smallest f that was cut off. cutoff(none) means the reachable space under
%  the current threshold was exhausted, so the instance has no solution.
ida_loop(Problem, Domain, Start, StartKey, Threshold, MaxExpansions, Deadline,
         Counters0, Result, Counters) :-
    Iterations1 is Counters0.iterations + 1,
    Counters1 = Counters0.put(iterations, Iterations1),
    ida_dfs(Problem, Domain, Start, 0, Threshold, [StartKey], [], 0,
            MaxExpansions, Deadline, Outcome, Counters1, Counters2),
    ( Outcome = solved(Path, Cost) ->
        Result = solved(Path, Cost),
        Counters = Counters2
    ; Outcome = limit_exceeded ->
        Result = limit_exceeded,
        Counters = Counters2
    ; Outcome = cutoff(none) ->
        Result = no_path,
        Counters = Counters2
    ; Outcome = cutoff(Next),
      Next \== none,
      Next > Threshold ->
        ida_loop(Problem, Domain, Start, StartKey, Next, MaxExpansions,
                 Deadline, Counters2, Result, Counters)
    ;
        Result = no_path,
        Counters = Counters2
    ).

%% ida_dfs(+Problem, +Domain, +State, +G, +Bound, +Keys, +StepsRev, +Depth,
%%         +MaxExpansions, +Deadline, -Outcome, +Counters0, -Counters) is det.
%
%  Outcome is solved(Path, Cost), cutoff(NextF), or limit_exceeded. NextF is
%  the smallest f above Bound seen in this subtree, or none if every leaf was
%  a dead end.
ida_dfs(Problem, Domain, State, G, Bound, Keys, StepsRev, Depth,
        MaxExpansions, Deadline, Outcome, Counters0, Counters) :-
    ( Counters0.expanded >= MaxExpansions ->
        Outcome = limit_exceeded,
        Counters = Counters0
    ; time_exceeded(Deadline) ->
        Outcome = limit_exceeded,
        Counters = Counters0
    ;
        Expanded1 is Counters0.expanded + 1,
        Counters1 = Counters0.put(expanded, Expanded1),
        MaxDepth is max(Counters0.max_depth, Depth),
        MaxFrontier is max(Counters0.max_frontier, Depth + 1),
        Counters2 = Counters1.put(max_depth, MaxDepth).put(max_frontier,
                                                           MaxFrontier),
        call(Domain:heuristic(Problem, State, H)),
        F is G + H,
        ( F > Bound ->
            Outcome = cutoff(F),
            Counters = Counters2
        ; call(Domain:goal_test(Problem, State)) ->
            reverse(StepsRev, Path),
            Outcome = solved(Path, G),
            Counters = Counters2
        ; call(Domain:successors(Problem, State, Moves)) ->
            length(Moves, NumMoves),
            Generated1 is Counters2.generated + NumMoves,
            Counters3 = Counters2.put(generated, Generated1),
            Context = ctx(Problem, Domain, Bound, Keys, StepsRev, Depth,
                          MaxExpansions, Deadline),
            ida_expand(Moves, Context, State, G, none, Outcome,
                       Counters3, Counters)
        ;
            Outcome = cutoff(none),
            Counters = Counters2
        )
    ).

%% ida_expand(+Moves, +Context, +State, +G, +Next0, -Outcome,
%%            +Counters0, -Counters) is det.
%
%  Explore successors left to right. The first solution or limit wins; cut-off
%  values are folded into the smallest next threshold. Successors whose key is
%  already on the current path are skipped.
ida_expand([], _, _, _, Next, cutoff(Next), Counters, Counters).
ida_expand([move(Action, MoveCost, Next)|Moves], Context, State, G, Next0,
           Outcome, Counters0, Counters) :-
    Context = ctx(Problem, Domain, Bound, Keys, StepsRev, Depth,
                  MaxExpansions, Deadline),
    call(Domain:state_key(Problem, Next, NextKey)),
    ( memberchk(NextKey, Keys) ->
        ida_expand(Moves, Context, State, G, Next0, Outcome,
                   Counters0, Counters)
    ;
        GNext is G + MoveCost,
        NextDepth is Depth + 1,
        ida_dfs(Problem, Domain, Next, GNext, Bound, [NextKey|Keys],
                [step(Action, MoveCost, Next)|StepsRev], NextDepth,
                MaxExpansions, Deadline, ChildOutcome, Counters0, Counters1),
        ( ChildOutcome = cutoff(none) ->
            ida_expand(Moves, Context, State, G, Next0, Outcome,
                       Counters1, Counters)
        ; ChildOutcome = cutoff(F) ->
            min_next(Next0, F, Next1),
            ida_expand(Moves, Context, State, G, Next1, Outcome,
                       Counters1, Counters)
        ;
            Outcome = ChildOutcome,
            Counters = Counters1
        )
    ).

%% min_next(+Accumulator, +Value, -Minimum) is det.
%
%  none represents "no cut-off seen yet"; both arguments are numeric
%  otherwise.
min_next(none, Value, Value).
min_next(Accumulator, Value, Minimum) :-
    Accumulator \== none,
    Minimum is min(Accumulator, Value).
