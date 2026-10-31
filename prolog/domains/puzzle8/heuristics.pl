%% puzzle8_heuristics.pl - misplaced-tiles and Manhattan heuristics.
%%
%% The goal layout is fixed:
%%   [1,2,3,4,5,6,7,8,0]
%% where 0 is the blank, in row-major order.
%%
%% Both heuristics ignore the blank. A move swaps the blank with one
%% orthogonally adjacent tile, so it changes the position of exactly one tile
%% by one grid step:
%%   * misplaced tiles changes by at most 1 per move, hence it is consistent
%%     and admissible;
%%   * Manhattan changes by at most 1 per move, hence it is consistent and
%%     admissible, and it dominates misplaced tiles on every state.
:- module(puzzle8_heuristics,
          [ heuristic/3,
            valid_heuristic/1
          ]).

:- use_module(library(lists)).
:- use_module(library(aggregate)).

%% valid_heuristic(+Name) is semidet.
valid_heuristic(misplaced).
valid_heuristic(manhattan).

%% heuristic(+Name, +State, -H) is det.
%
%  State is a flat 9-element list in row-major order with 0 as the blank.
heuristic(misplaced, State, H) :-
    aggregate_all(count,
                  ( nth0(Index, State, Tile),
                    Tile =\= 0,
                    goal_tile(Index, GoalTile),
                    Tile =\= GoalTile ),
                  H).
heuristic(manhattan, State, H) :-
    findall(Distance,
            ( nth0(Index, State, Tile),
              Tile =\= 0,
              goal_tile(GoalIndex, Tile),
              Distance is abs(Index // 3 - GoalIndex // 3) +
                          abs(Index mod 3 - GoalIndex mod 3) ),
            Distances),
    sum_list(Distances, H).

%% goal_tile(?Index, ?Tile) is nondet.
%
%  Goal tile at a 0-based row-major index.
goal_tile(0, 1).
goal_tile(1, 2).
goal_tile(2, 3).
goal_tile(3, 4).
goal_tile(4, 5).
goal_tile(5, 6).
goal_tile(6, 7).
goal_tile(7, 8).
goal_tile(8, 0).
