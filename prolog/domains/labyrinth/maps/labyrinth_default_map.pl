%% Default 10x10 labyrinth. Two reachable exits and an internal wall structure
%% that makes the geometric heuristics informative without blocking the start
%% from every exit.
:- module(labyrinth_default_map,
          [ cols/1,
            rows/1,
            start/1,
            exit/1,
            blocked/1
          ]).

cols(10).
rows(10).

start(pos(4, 2)).

exit(pos(7, 9)).
exit(pos(10, 1)).

blocked(pos(2, 5)).
blocked(pos(3, 5)).
blocked(pos(4, 5)).
blocked(pos(5, 5)).
blocked(pos(6, 5)).
blocked(pos(7, 5)).

blocked(pos(7, 1)).
blocked(pos(7, 2)).
blocked(pos(7, 3)).
blocked(pos(7, 4)).

blocked(pos(4, 7)).
blocked(pos(4, 8)).
blocked(pos(4, 9)).
blocked(pos(4, 10)).

blocked(pos(5, 7)).
blocked(pos(6, 7)).
blocked(pos(8, 7)).
