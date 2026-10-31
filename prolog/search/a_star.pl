%% a_star.pl - generic A* with best-g duplicate handling.
%%
%% Design notes:
%%   * The frontier is a SWI min-heap keyed by f(F, -G, Seq). Smaller f wins;
%%     on equal f the more negative -G wins, so deeper nodes are expanded
%%     first; Seq is a monotonic counter that makes ties deterministic.
%%   * Best g-scores and parent pointers live in library(assoc) trees. The
%%     trees are persistent, backtrack-safe, and use standard order on the
%%     ground keys supplied by the domain.
%%   * library(heaps) has no decrease-key, so improved nodes are pushed again
%%     and old entries are discarded lazily. A popped entry is stale when its
%%     stored g is worse than the best known g; a cheaper path discovered for
%%     an already expanded state reopens it.
%%   * The goal test runs on pop, never on generation. This keeps A* optimal
%%     with an admissible heuristic that is not necessarily consistent.
%%   * generated counts every successor produced; expanded counts every
%%     non-stale pop that reaches the goal test.
:- module(a_star, [a_star/4]).

:- use_module(library(heaps)).
:- use_module(library(assoc)).
:- use_module(search_common).

%% a_star(+Problem, +Options, -Result, -Stats) is det.
%
%  Options:
%    heuristic(Name)      select a domain heuristic (optional)
%    max_expansions(N)    stop after N expanded nodes (default 1,000,000)
%    timeout(Seconds)     wall-clock budget per call (default 60)
%
%  Result is solved(Path, Cost), no_path, or limit_exceeded. Path is a list
%  of step(Action, Cost, State) from the successor of the initial state to the
%  goal; the initial state is implicit.
a_star(Problem0, Options, Result, Stats) :-
    once(a_star_(Problem0, Options, Result, Stats)).

%% a_star_(+Problem, +Options, -Result, -Stats) is det.
%
%  Implementation of a_star/4. The once/1 in the public wrapper is the
%  determinism commitment: every engine branch is intended to be single-valued.
a_star_(Problem0, Options, Result, Stats) :-
    problem_with_heuristic(Problem0, Options, Problem),
    Problem = problem(Domain, _),
    option_or(Options, max_expansions, 1000000, MaxExpansions),
    option_or(Options, timeout, 60, Timeout),
    statistics(cputime, Cpu0),
    time_now(Wall0),
    Deadline is Wall0 + Timeout,
    new_counters(Counters0),
    ( precheck_unsolvable(Problem) ->
        Result0 = no_path,
        Counters = Counters0
    ;
        call(Domain:initial_state(Problem, Start)),
        call(Domain:heuristic(Problem, Start, H0)),
        F0 is H0,
        Neg0 is -0,
        empty_heap(Heap0),
        add_to_heap(Heap0, f(F0, Neg0, 0), node(Start, 0), Heap1),
        call(Domain:state_key(Problem, Start, StartKey)),
        empty_assoc(GMap0),
        put_assoc(StartKey, GMap0, 0, GMap1),
        empty_assoc(Parents0),
        Counters1 = Counters0.put(iterations, 1).put(max_frontier, 1),
        Frontier0 = frontier(Heap1, GMap1, Parents0, 1),
        a_star_loop(Problem, Domain, MaxExpansions, Deadline,
                    Frontier0, Counters1, Result0, Parents, Counters)
    ),
    statistics(cputime, Cpu1),
    time_now(Wall1),
    Cpu is Cpu1 - Cpu0,
    Wall is Wall1 - Wall0,
    ( Result0 = solved(GoalState, _) ->
        reconstruct_path(Problem, Domain, Start, Parents, GoalState, Path, Cost),
        Result = solved(Path, Cost)
    ;
        Result = Result0
    ),
    result_stats(Result, Counters, Cpu, Wall, Stats).

%% a_star_loop(+Problem, +Domain, +MaxExpansions, +Deadline,
%%             +Frontier0, +Counters0, -Result, -Parents, -Counters) is det.
%
%  Result is solved(GoalState, Cost), no_path, or limit_exceeded. Parents is
%  the final parent map, needed only for path reconstruction after a solution.
a_star_loop(Problem, Domain, MaxExpansions, Deadline,
            Frontier0, Counters0, Result, Parents, Counters) :-
    Frontier0 = frontier(Heap0, GMap0, Parents0, Seq0),
    ( Counters0.expanded >= MaxExpansions ->
        Result = limit_exceeded,
        Parents = Parents0,
        Counters = Counters0
    ; time_exceeded(Deadline) ->
        Result = limit_exceeded,
        Parents = Parents0,
        Counters = Counters0
    ; get_from_heap(Heap0, _Key, node(State, G), Heap1) ->
        call(Domain:state_key(Problem, State, Key)),
        get_assoc(Key, GMap0, BestG),
        ( G > BestG ->
            Stale1 is Counters0.stale + 1,
            Counters1 = Counters0.put(stale, Stale1),
            Frontier1 = frontier(Heap1, GMap0, Parents0, Seq0),
            a_star_loop(Problem, Domain, MaxExpansions, Deadline,
                        Frontier1, Counters1, Result, Parents, Counters)
        ;
            Expanded1 is Counters0.expanded + 1,
            Counters1 = Counters0.put(expanded, Expanded1),
            ( call(Domain:goal_test(Problem, State)) ->
                Result = solved(State, G),
                Parents = Parents0,
                Counters = Counters1
            ;
                call(Domain:successors(Problem, State, Moves)),
                length(Moves, NumMoves),
                Generated1 is Counters1.generated + NumMoves,
                Counters2 = Counters1.put(generated, Generated1),
                Context = ctx(Problem, Domain),
                FrontierAfterPop = frontier(Heap1, GMap0, Parents0, Seq0),
                expand_moves(Moves, Context, State, G, FrontierAfterPop,
                             Counters2, Frontier1, Counters3),
                a_star_loop(Problem, Domain, MaxExpansions, Deadline,
                            Frontier1, Counters3, Result, Parents, Counters)
            )
        )
    ;
        Result = no_path,
        Parents = Parents0,
        Counters = Counters0
    ).

%% expand_moves(+Moves, +Context, +State, +G, +Frontier0, +Counters0,
%%              -Frontier, -Counters) is det.
%
%  Push improved successors onto the frontier. A successor whose new g is not
%  strictly better than the best known g is not pushed; a strictly better one
%  is pushed and, if the state was already known, counted as reopened.
expand_moves([], _, _, _, Frontier, Counters, Frontier, Counters).
expand_moves([move(Action, MoveCost, Next)|Moves], Context, State, G,
             Frontier0, Counters0, Frontier, Counters) :-
    Context = ctx(Problem, Domain),
    Frontier0 = frontier(_, GMap0, _, _),
    GNext is G + MoveCost,
    call(Domain:state_key(Problem, Next, Key)),
    ( get_assoc(Key, GMap0, KnownG) ->
        ( GNext < KnownG ->
            push_successor(Problem, Domain, Next, GNext, KnownG,
                           move(Action, MoveCost), State,
                           Frontier0, Counters0, Frontier1, Counters1),
            expand_moves(Moves, Context, State, G, Frontier1, Counters1,
                         Frontier, Counters)
        ;
            expand_moves(Moves, Context, State, G, Frontier0, Counters0,
                         Frontier, Counters)
        )
    ;
        push_successor(Problem, Domain, Next, GNext, none,
                       move(Action, MoveCost), State,
                       Frontier0, Counters0, Frontier1, Counters1),
        expand_moves(Moves, Context, State, G, Frontier1, Counters1,
                     Frontier, Counters)
    ).

%% push_successor(+Problem, +Domain, +Next, +GNext, +KnownG, +Move,
%%                +State, +Frontier0, +Counters0, -Frontier, -Counters) is det.
%
%  Store the new best g and parent for Next, push it, and update the reopened
%  and max_frontier counters. KnownG is none for a previously unseen state.
push_successor(Problem, Domain, Next, GNext, KnownG, move(Action, MoveCost),
               State, Frontier0, Counters0, Frontier, Counters) :-
    Frontier0 = frontier(Heap0, GMap0, Parents0, Seq0),
    call(Domain:state_key(Problem, Next, NextKey)),
    put_assoc(NextKey, GMap0, GNext, GMap1),
    put_assoc(NextKey, Parents0, parent(State, Action, MoveCost), Parents1),
    call(Domain:heuristic(Problem, Next, H)),
    F is GNext + H,
    NegG is -GNext,
    add_to_heap(Heap0, f(F, NegG, Seq0), node(Next, GNext), Heap1),
    Seq1 is Seq0 + 1,
    heap_size(Heap1, Size),
    MaxFrontier is max(Counters0.max_frontier, Size),
    ( KnownG == none ->
        Counters1 = Counters0
    ;
        Reopened1 is Counters0.reopened + 1,
        Counters1 = Counters0.put(reopened, Reopened1)
    ),
    Counters = Counters1.put(max_frontier, MaxFrontier),
    Frontier = frontier(Heap1, GMap1, Parents1, Seq1).

%% reconstruct_path(+Problem, +Domain, +Start, +Parents, +Goal,
%%                  -Path, -Cost) is det.
%
%  Walk parent pointers backwards from Goal to Start. Path is ordered from
%  the first move to the last and Cost is the summed move cost.
reconstruct_path(Problem, Domain, Start, Parents, Goal, Path, Cost) :-
    path_acc(Problem, Domain, Start, Parents, Goal, [], Path, Cost).

%% path_acc(+Problem, +Domain, +Start, +Parents, +State, +Acc, -Path, -Cost)
path_acc(Problem, Domain, Start, Parents, State, Acc, Path, Cost) :-
    ( State == Start ->
        Path = Acc,
        Cost = 0
    ;
        call(Domain:state_key(Problem, State, Key)),
        get_assoc(Key, Parents, parent(Prev, Action, StepCost)),
        path_acc(Problem, Domain, Start, Parents, Prev,
                 [step(Action, StepCost, State)|Acc], Path, RestCost),
        Cost is RestCost + StepCost
    ).
