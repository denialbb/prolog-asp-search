%% search_common.pl - shared plumbing for the generic search engines.
%%
%% The engines talk to a domain through the fixed problem-descriptor
%% contract:
%%
%%   Problem = problem(DomainModule, Config)
%%   DomainModule:initial_state(+Problem, -State)
%%   DomainModule:goal_test(+Problem, +State)
%%   DomainModule:successors(+Problem, +State, -Moves)
%%   DomainModule:heuristic(+Problem, +State, -H)
%%   DomainModule:state_key(+Problem, +State, -Key)
%%   DomainModule:state_label(+Problem, +State, -Label)
%%
%% This module owns option handling, optional domain hooks, timing, and the
%% shape of the statistics dict returned by both engines.
:- module(search_common,
          [ option_or/4,
            problem_with_heuristic/3,
            precheck_unsolvable/1,
            time_now/1,
            time_exceeded/1,
            new_counters/1,
            result_stats/5
          ]).

:- use_module(library(lists)).

%% option_or(+Options, +Name, +Default, -Value) is det.
%
%  Read Name(Value) from the option list, falling back to Default.
option_or(Options, Name, Default, Value) :-
    ( member(Option, Options),
      Option =.. [Name, Value0] ->
        Value = Value0
    ;
        Value = Default
    ).

%% problem_with_heuristic(+Problem, +Options, -ProblemOut) is det.
%
%  Apply the engine-level heuristic(Name) option when the domain offers the
%  optional with_heuristic/3 hook. Domains that keep the heuristic in their
%  own configuration simply ignore the option.
problem_with_heuristic(Problem0, Options, Problem) :-
    ( memberchk(heuristic(Name), Options) ->
        Problem0 = problem(Domain, _),
        ( current_predicate(Domain:with_heuristic/3) ->
            call(Domain:with_heuristic(Problem0, Name, Problem))
        ;
            Problem = Problem0
        )
    ;
        Problem = Problem0
    ).

%% precheck_unsolvable(+Problem) is semidet.
%
%  Domains may export solvable/1 to reject instances before the search
%  starts. The hook is optional, so the engine stays domain-agnostic.
precheck_unsolvable(Problem) :-
    Problem = problem(Domain, _),
    current_predicate(Domain:solvable/1),
    \+ call(Domain:solvable(Problem)).

%% time_now(-Seconds) is det.
%
%  Wall-clock time in seconds, used only for timeout enforcement.
time_now(Seconds) :-
    get_time(Seconds).

%% time_exceeded(+Deadline) is semidet.
time_exceeded(Deadline) :-
    time_now(Now),
    Now >= Deadline.

%% new_counters(-Counters) is det.
%
%  Mutable-free counter bundle threaded through both engines. Iterations and
%  max_frontier are filled in by the engine as soon as it knows them.
new_counters(counters{expanded: 0,
                      generated: 0,
                      stale: 0,
                      reopened: 0,
                      max_frontier: 0,
                      iterations: 0,
                      max_depth: 0}).

%% result_stats(+Result, +Counters, +Cpu, +Wall, -Stats) is det.
%
%  Build the public statistics dict. Unsolved results carry solution_cost:none
%  and path_length:0 so callers can distinguish them from a zero-cost path.
result_stats(Result, Counters, Cpu, Wall, Stats) :-
    result_summary(Result, Status, Cost, PathLength),
    Stats = _{ expanded: Counters.expanded,
               generated: Counters.generated,
               stale: Counters.stale,
               reopened: Counters.reopened,
               max_frontier: Counters.max_frontier,
               iterations: Counters.iterations,
               max_depth: Counters.max_depth,
               cpu: Cpu,
               wall: Wall,
               solution_cost: Cost,
               path_length: PathLength,
               status: Status }.

%% result_summary(+Result, -Status, -Cost, -PathLength) is det.
result_summary(solved(Path, Cost), solved, Cost, Length) :-
    length(Path, Length).
result_summary(no_path, no_path, none, 0).
result_summary(limit_exceeded, limit_exceeded, none, 0).
