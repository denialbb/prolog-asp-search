%% Sealed 5x5 labyrinth used to test the unsolvable precheck. The start cell
%% is surrounded by blocked cells, so neither exit is reachable even though
%% the map itself is structurally valid.
:- module(labyrinth_sealed_map,
          [ cols/1,
            rows/1,
            start/1,
            exit/1,
            blocked/1
          ]).

cols(5).
rows(5).

start(pos(3, 3)).

exit(pos(1, 1)).
exit(pos(1, 5)).

blocked(pos(2, 2)).
blocked(pos(2, 3)).
blocked(pos(2, 4)).
blocked(pos(3, 2)).
blocked(pos(3, 4)).
blocked(pos(4, 2)).
blocked(pos(4, 3)).
blocked(pos(4, 4)).
