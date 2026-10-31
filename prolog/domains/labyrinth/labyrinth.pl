%% labyrinth.pl - grid labyrinth domain for the generic search engines.
%%
%% A map is a module exporting cols/1, rows/1, start/1, exit/1, and blocked/1.
%% States are pos(Row, Column) with 1-based coordinates. Moves are the four
%% orthogonal neighbours with unit cost; a move is legal inside the bounds and
%% when the target cell is not blocked. Multiple exit/1 facts are allowed and
%% reaching any of them is a goal.
%%
%% Problem descriptor:
%%   problem(labyrinth, lab(MapModule, HeuristicName))
:- module(labyrinth,
          [ initial_state/2,
            goal_test/2,
            successors/3,
            heuristic/3,
            state_key/3,
            state_label/3,
            with_heuristic/3,
            solvable/1,
            reachable/2,
            map_valid/1
          ]).

:- use_module(library(lists)).
:- use_module(heuristics, [valid_heuristic/1]).

%% initial_state(+Problem, -State) is det.
initial_state(problem(labyrinth, lab(Map, _)), State) :-
    call(Map:start(State)).

%% goal_test(+Problem, +State) is semidet.
%
%  Succeeds when State is any exit of the map, so the goal set is the union of
%  all exit/1 facts.
goal_test(problem(labyrinth, lab(Map, _)), State) :-
    call(Map:exit(State)).

%% successors(+Problem, +State, -Moves) is det.
%
%  Moves is an ordered list of move(Action, 1, NextState). The order up, right,
%  down, left is fixed so that tie-breaking in the engines stays deterministic.
successors(problem(labyrinth, lab(Map, _)), pos(Row, Column), Moves) :-
    findall(move(Action, 1, pos(NextRow, NextColumn)),
            ( step(Action, RowDelta, ColumnDelta),
              NextRow is Row + RowDelta,
              NextColumn is Column + ColumnDelta,
              cell_in_bounds(Map, pos(NextRow, NextColumn)),
              \+ call(Map:blocked(pos(NextRow, NextColumn))) ),
            Moves).

%% step(-Action, -RowDelta, -ColumnDelta) is nondet.
step(up, -1, 0).
step(right, 0, 1).
step(down, 1, 0).
step(left, 0, -1).

%% heuristic(+Problem, +State, -H) is det.
%
%  Dispatch to labyrinth_heuristics. Both available heuristics are admissible
%  and consistent on this move model.
heuristic(problem(labyrinth, lab(Map, Name)), State, H) :-
    labyrinth_heuristics:heuristic(Name, Map, State, H).

%% state_key(+Problem, +State, -Key) is det.
%
%  pos/2 is already ground and canonical, so it is used directly as the key.
state_key(_, State, State).

%% state_label(+Problem, +State, -Label) is det.
state_label(_, pos(Row, Column), Label) :-
    format(atom(Label), 'row ~w, col ~w', [Row, Column]).

%% with_heuristic(+Problem, +Name, -ProblemOut) is semidet.
%
%  Optional engine hook used by the heuristic(Name) option.
with_heuristic(problem(labyrinth, lab(Map, _)), Name,
               problem(labyrinth, lab(Map, Name))) :-
    labyrinth_heuristics:valid_heuristic(Name).

%% solvable(+Problem) is semidet.
%
%  Succeeds when at least one exit is reachable from the start. Used by the
%  engines as a fast precheck for sealed maps.
solvable(Problem) :-
    Problem = problem(labyrinth, lab(Map, _)),
    findall(Exit, call(Map:exit(Exit)), Exits),
    member(Exit, Exits),
    reachable(Problem, Exit),
    !.

%% reachable(+Problem, +Target) is semidet.
%
%  Breadth-first reachability over legal moves, independent of any search
%  heuristic. Exposed for diagnostics and tests.
reachable(Problem, Target) :-
    initial_state(Problem, Start),
    state_key(Problem, Target, TargetKey),
    bfs(Problem, [Start], [], TargetKey).

%% bfs(+Problem, +Open, +Visited, +TargetKey) is semidet.
bfs(Problem, [State|Open], Visited, TargetKey) :-
    state_key(Problem, State, Key),
    ( Key == TargetKey ->
        true
    ; memberchk(Key, Visited) ->
        bfs(Problem, Open, Visited, TargetKey)
    ;
        successors(Problem, State, Moves),
        findall(Next, member(move(_, _, Next), Moves), NextStates),
        append(Open, NextStates, Open1),
        bfs(Problem, Open1, [Key|Visited], TargetKey)
    ).

%% map_valid(+MapModule) is semidet.
%
%  Structural invariants shared by every map: positive dimensions, exactly one
%  start, at least two exits, and all start/exit/blocked cells inside bounds
%  with start and exits free.
map_valid(Map) :-
    call(Map:cols(Cols)),
    integer(Cols),
    Cols > 0,
    call(Map:rows(Rows)),
    integer(Rows),
    Rows > 0,
    findall(Start, call(Map:start(Start)), [Start]),
    cell_in_bounds(Map, Start),
    \+ call(Map:blocked(Start)),
    findall(Exit, call(Map:exit(Exit)), Exits),
    length(Exits, ExitCount),
    ExitCount >= 2,
    forall(member(Exit, Exits),
           ( cell_in_bounds(Map, Exit),
             \+ call(Map:blocked(Exit)) )),
    forall(call(Map:blocked(Blocked)), cell_in_bounds(Map, Blocked)).

%% cell_in_bounds(+MapModule, +State) is semidet.
cell_in_bounds(Map, pos(Row, Column)) :-
    call(Map:cols(Cols)),
    call(Map:rows(Rows)),
    integer(Row),
    integer(Column),
    Row >= 1,
    Row =< Rows,
    Column >= 1,
    Column =< Cols.
