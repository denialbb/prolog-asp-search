%% Multi-exit 9x9 labyrinth. The exit in the sealed top-right room is a
%% deliberate unreachable exit: it lowers the nearest-exit geometric estimate
%% but must not affect correctness or admissibility.
:- module(labyrinth_multi_exit_map,
          [ cols/1,
            rows/1,
            start/1,
            exit/1,
            blocked/1
          ]).

cols(9).
rows(9).

start(pos(1, 1)).

exit(pos(9, 9)).
exit(pos(9, 5)).
exit(pos(1, 9)).

% Walls of the sealed top-right room containing exit(pos(1, 9)).
blocked(pos(1, 8)).
blocked(pos(2, 8)).
blocked(pos(2, 9)).

% Internal walls on the open part of the grid.
blocked(pos(4, 3)).
blocked(pos(5, 3)).
blocked(pos(6, 3)).
blocked(pos(6, 4)).
blocked(pos(6, 5)).
blocked(pos(6, 6)).
