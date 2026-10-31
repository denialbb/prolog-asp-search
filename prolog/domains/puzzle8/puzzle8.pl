%% puzzle8.pl - 8-puzzle domain for the generic search engines.
%%
%% State: a flat 9-element list in row-major order, with 0 as the blank:
%%   [1,2,3,4,5,6,7,8,0]  is the goal.
%% Moves: swap the blank with an orthogonally adjacent tile, unit cost.
%%
%% The 3x3 state space has 9! = 362,880 permutations, split into two equal
%% parity classes. A row-major sequence with the blank removed is solvable iff
%% its inversion count is even; solvable_state/1 checks that invariant before
%% any search starts.
%%
%% Problem descriptor:
%%   problem(puzzle8, p8(InitialState, HeuristicName))
:- module(puzzle8,
          [ initial_state/2,
            goal_test/2,
            successors/3,
            heuristic/3,
            state_key/3,
            state_label/3,
            with_heuristic/3,
            solvable/1,
            solvable_state/1,
            valid_state/1,
            inversions/2,
            goal_state/1
          ]).

:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- use_module(heuristics, [valid_heuristic/1]).

%% goal_state(-State) is det.
goal_state([1, 2, 3, 4, 5, 6, 7, 8, 0]).

%% initial_state(+Problem, -State) is det.
initial_state(problem(puzzle8, p8(Initial, _)), Initial).

%% goal_test(+Problem, +State) is semidet.
goal_test(_, State) :-
    goal_state(Goal),
    State == Goal.

%% successors(+Problem, +State, -Moves) is det.
%
%  Moves is an ordered list of move(Action, 1, NextState). Order is up, right,
%  down, left, which keeps engine tie-breaking deterministic.
successors(_, State, Moves) :-
    blank_index(State, BlankIndex),
    findall(move(Action, 1, NextState),
            ( step(Action, RowDelta, ColumnDelta),
              neighbour_index(BlankIndex, RowDelta, ColumnDelta, TileIndex),
              swap_positions(BlankIndex, TileIndex, State, NextState) ),
            Moves).

%% step(-Action, -RowDelta, -ColumnDelta) is nondet.
step(up, -1, 0).
step(right, 0, 1).
step(down, 1, 0).
step(left, 0, -1).

%% blank_index(+State, -Index) is det.
blank_index(State, Index) :-
    nth0(Index, State, 0).

%% neighbour_index(+Index, +RowDelta, +ColumnDelta, -NeighbourIndex) is semidet.
%
%  Convert a 0-based row-major index to coordinates, apply the delta, and
%  reject moves that leave the 3x3 board.
neighbour_index(Index, RowDelta, ColumnDelta, NeighbourIndex) :-
    Row is Index // 3,
    Column is Index mod 3,
    NextRow is Row + RowDelta,
    NextColumn is Column + ColumnDelta,
    NextRow >= 0,
    NextRow < 3,
    NextColumn >= 0,
    NextColumn < 3,
    NeighbourIndex is NextRow * 3 + NextColumn.

%% swap_positions(+IndexA, +IndexB, +List, -Swapped) is det.
%
%  Swap two elements of a list in a single pass.
swap_positions(IndexA, IndexB, List, Swapped) :-
    nth0(IndexA, List, ValueA),
    nth0(IndexB, List, ValueB),
    swap_values(0, IndexA, IndexB, ValueA, ValueB, List, Swapped).

%% swap_values(+Current, +IndexA, +IndexB, +ValueA, +ValueB, +List, -Swapped)
swap_values(_, _, _, _, _, [], []).
swap_values(Current, IndexA, IndexB, ValueA, ValueB, [Value|Rest],
            [SwappedValue|SwappedRest]) :-
    ( Current =:= IndexA ->
        SwappedValue = ValueB
    ; Current =:= IndexB ->
        SwappedValue = ValueA
    ;
        SwappedValue = Value
    ),
    Next is Current + 1,
    swap_values(Next, IndexA, IndexB, ValueA, ValueB, Rest, SwappedRest).

%% heuristic(+Problem, +State, -H) is det.
heuristic(problem(puzzle8, p8(_, Name)), State, H) :-
    puzzle8_heuristics:heuristic(Name, State, H).

%% state_key(+Problem, +State, -Key) is det.
%
%  The flat list is ground and canonical, so it is used directly as the key.
state_key(_, State, State).

%% state_label(+Problem, +State, -Label) is det.
state_label(_, [A, B, C, D, E, F, G, H, I], Label) :-
    format(atom(Label), '~w ~w ~w / ~w ~w ~w / ~w ~w ~w',
           [A, B, C, D, E, F, G, H, I]).

%% with_heuristic(+Problem, +Name, -ProblemOut) is semidet.
with_heuristic(problem(puzzle8, p8(Initial, _)), Name,
               problem(puzzle8, p8(Initial, Name))) :-
    puzzle8_heuristics:valid_heuristic(Name).

%% valid_state(+State) is semidet.
%
%  State is a permutation of 0..8.
valid_state(State) :-
    is_list(State),
    length(State, 9),
    msort(State, Sorted),
    Sorted == [0, 1, 2, 3, 4, 5, 6, 7, 8].

%% solvable(+Problem) is semidet.
solvable(problem(puzzle8, p8(Initial, _))) :-
    solvable_state(Initial).

%% solvable_state(+State) is semidet.
%
%  Inversion parity with the blank omitted: even means reachable from the goal.
solvable_state(State) :-
    valid_state(State),
    delete(State, 0, Tiles),
    inversions(Tiles, Count),
    0 =:= Count mod 2.

%% inversions(+Tiles, -Count) is det.
inversions(Tiles, Count) :-
    aggregate_all(count,
                  ( nth0(I, Tiles, A),
                    nth0(J, Tiles, B),
                    I < J,
                    A > B ),
                  Count).
