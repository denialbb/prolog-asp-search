%% labyrinth_heuristics.pl - geometric heuristics for the grid labyrinth.
%%
%% Both heuristics take the minimum over every exit of the map, including
%% exits that are not reachable from the start. An unreachable exit has a
%% finite geometric distance, so it can only lower the estimate; it never
%% makes the heuristic inadmissible.
%%
%% On a four-connected unit-cost grid:
%%   * Manhattan is admissible and consistent. One orthogonal move changes the
%%     distance to any fixed cell by exactly one, and the minimum of 1-Lipschitz
%%     functions is 1-Lipschitz.
%%   * Euclidean is admissible and consistent as well, but it is dominated by
%%     Manhattan and therefore expands at least as many nodes.
%% Manhattan would lose admissibility if diagonal unit-cost moves were allowed;
%% the move model stays explicitly orthogonal.
:- module(labyrinth_heuristics,
          [ heuristic/4,
            valid_heuristic/1
          ]).

:- use_module(library(lists)).

%% valid_heuristic(+Name) is semidet.
valid_heuristic(manhattan).
valid_heuristic(euclidean).

%% heuristic(+Name, +MapModule, +State, -H) is det.
%
%  State is pos(Row, Column) with 1-based coordinates.
heuristic(manhattan, Map, pos(Row, Column), H) :-
    findall(D, ( call(Map:exit(pos(ExitRow, ExitColumn))),
                 D is abs(Row - ExitRow) + abs(Column - ExitColumn) ),
            Distances),
    min_list(Distances, H).
heuristic(euclidean, Map, pos(Row, Column), H) :-
    findall(D, ( call(Map:exit(pos(ExitRow, ExitColumn))),
                 RowDelta is Row - ExitRow,
                 ColumnDelta is Column - ExitColumn,
                 D is sqrt(RowDelta * RowDelta + ColumnDelta * ColumnDelta) ),
            Distances),
    min_list(Distances, H).
