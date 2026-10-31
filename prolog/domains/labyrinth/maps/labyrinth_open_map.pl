%% Sparse 8x8 labyrinth. The direct paths to both exits are open, so the
%% comparison between Manhattan and Euclidean heuristics is not distorted by
%% long detours.
:- module(labyrinth_open_map,
          [ cols/1,
            rows/1,
            start/1,
            exit/1,
            blocked/1
          ]).

cols(8).
rows(8).

start(pos(4, 4)).

exit(pos(1, 8)).
exit(pos(8, 1)).

blocked(pos(2, 2)).
blocked(pos(2, 3)).
blocked(pos(3, 2)).
blocked(pos(6, 6)).
blocked(pos(6, 7)).
blocked(pos(7, 6)).
