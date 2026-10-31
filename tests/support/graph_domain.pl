%% Tiny directed graphs used by the engine tests. The config argument selects
%% one of two scenarios:
%%
%%   reopen: the heuristic is admissible but inconsistent (h(a) = 2 while
%%           a -> b costs 1 and h(b) = 0). A* must reopen b and still return
%%           the optimal cost 3; b reaches g with cost 4 first, which also
%%           checks that the goal is tested on pop rather than generation.
%%
%%   stale:  all heuristic values are zero. The direct edge s -> x costs 5,
%%           while s -> a -> x costs 4, so the old x entry stays in the heap
%%           and is discarded lazily before the goal at cost 6 is popped.
:- module(graph_domain,
          [ initial_state/2,
            goal_test/2,
            successors/3,
            heuristic/3,
            state_key/3,
            state_label/3
          ]).

initial_state(problem(graph, _), s).

goal_test(_, g).

successors(problem(graph, reopen), s, [move(a, 1, a), move(b, 3, b)]).
successors(problem(graph, reopen), a, [move(b, 1, b), move(g, 4, g)]).
successors(problem(graph, reopen), b, [move(g, 1, g)]).
successors(problem(graph, reopen), g, []).

successors(problem(graph, stale), s, [move(a, 1, a), move(x, 5, x)]).
successors(problem(graph, stale), a, [move(x, 3, x)]).
successors(problem(graph, stale), x, [move(g, 2, g)]).
successors(problem(graph, stale), g, []).

heuristic(problem(graph, reopen), s, 0).
heuristic(problem(graph, reopen), a, 2).
heuristic(problem(graph, reopen), b, 0).
heuristic(problem(graph, reopen), g, 0).
heuristic(problem(graph, stale), _, 0).

state_key(_, State, State).

state_label(_, State, State).
