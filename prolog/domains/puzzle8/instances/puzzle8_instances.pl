%% Named 8-puzzle benchmark instances.
%%
%% All instances are solvable (even inversion parity) and were built from the
%% goal by random legal walks with a fixed seed; the recorded optimal costs
%% are 2, 4, 6, 8 and 10 to 16 moves, so the suite stays in the easy/medium
%% range where IDA* is a meaningful comparison rather than a timeout test.
:- module(puzzle8_instances,
          [ instance/3,
            instance/2
          ]).

%% instance(?Name, ?Difficulty, ?State) is nondet.
%
%  Difficulty is easy or medium. State is the initial 8-puzzle configuration.
instance(easy_2, easy, [1, 2, 3, 4, 5, 6, 0, 7, 8]).
instance(easy_4, easy, [1, 2, 3, 4, 8, 5, 7, 6, 0]).
instance(easy_6, easy, [1, 2, 3, 5, 6, 8, 4, 7, 0]).
instance(easy_8, easy, [0, 1, 2, 5, 6, 3, 4, 7, 8]).

instance(medium_10, medium, [0, 1, 2, 4, 7, 3, 8, 5, 6]).
instance(medium_11, medium, [1, 0, 3, 4, 7, 6, 5, 2, 8]).
instance(medium_12, medium, [0, 1, 2, 3, 5, 6, 4, 7, 8]).
instance(medium_13, medium, [1, 5, 4, 0, 3, 2, 7, 8, 6]).
instance(medium_14, medium, [0, 7, 2, 5, 1, 3, 8, 4, 6]).
instance(medium_15, medium, [1, 0, 5, 4, 3, 7, 8, 2, 6]).
instance(medium_16, medium, [1, 5, 6, 2, 3, 8, 0, 4, 7]).
instance(medium_16b, medium, [3, 4, 6, 2, 7, 8, 1, 5, 0]).

%% instance(?Name, ?State) is nondet.
instance(Name, State) :-
    instance(Name, _, State).
