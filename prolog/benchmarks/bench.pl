%% bench.pl - reproducible benchmark matrix for A* and IDA*.
%%
%% Run from the repository root:
%%
%%   swipl -g "bench:main" -t halt prolog/benchmarks/bench.pl
%%
%% Optional arguments:
%%
%%   swipl -g "bench:main([repetitions(3),timeout(30)])" -t halt \
%%         prolog/benchmarks/bench.pl
%%
%% The matrix is:
%%   * three labyrinth maps x {manhattan, euclidean} x {a_star, ida_star};
%%   * twelve solvable 8-puzzle instances x {misplaced, manhattan}
%%     x {a_star, ida_star}.
%%
%% Each configuration is run five times. The script writes:
%%   results/runs.csv     one row per repetition, including repetition number;
%%   results/summary.csv  one row per configuration with median counters.
%%
%% peak_rss_kb is intentionally empty: statistics/2 reports current memory, not
%% peak. Peak RSS must be measured in a fresh process (for example with
%% /usr/bin/time -v), so it is not mixed into the in-process timings.
:- module(bench, [main/0, main/1]).

:- use_module(library(lists)).
:- use_module('../search/a_star').
:- use_module('../search/ida_star').
:- use_module('../domains/labyrinth/labyrinth', []).
:- use_module('../domains/labyrinth/maps/labyrinth_default_map', []).
:- use_module('../domains/labyrinth/maps/labyrinth_multi_exit_map', []).
:- use_module('../domains/labyrinth/maps/labyrinth_open_map', []).
:- use_module('../domains/puzzle8/puzzle8', []).
:- use_module('../domains/puzzle8/instances/puzzle8_instances').

%% main is det.
main :-
    main([]).

%% main(+Options) is det.
%
%  Options: repetitions(N), default 5; timeout(Seconds), default 60.
main(Options) :-
    bench_option(Options, repetitions, 5, Repetitions),
    bench_option(Options, timeout, 60, Timeout),
    labyrinth_configs(LabyrinthConfigs),
    puzzle_configs(PuzzleConfigs),
    append(LabyrinthConfigs, PuzzleConfigs, Configs),
    length(Configs, Count),
    format('Running ~w configurations x ~w repetitions~n',
           [Count, Repetitions]),
    findall(Config-Rows,
            ( member(Config, Configs),
              run_config(Config, Repetitions, Timeout, Rows) ),
            Results),
    findall(Row, ( member(_-Rows, Results), member(Row, Rows) ), AllRows),
    findall(Summary,
            ( member(Config-Rows, Results),
              summarize(Config, Rows, Summary) ),
            Summaries),
    results_dir(Dir),
    run_header(RunHeader),
    summary_header(SummaryHeader),
    write_csv_file(Dir, 'runs.csv', RunHeader, AllRows),
    write_csv_file(Dir, 'summary.csv', SummaryHeader, Summaries),
    forall(member(Summary, Summaries), print_summary(Summary)),
    format('Wrote ~w/runs.csv and ~w/summary.csv~n', [Dir, Dir]).

%% labyrinth_configs(-Configs) is det.
labyrinth_configs(Configs) :-
    findall(cfg(labyrinth, Name, Solver, Heuristic,
                problem(labyrinth, lab(Map, Heuristic))),
            ( labyrinth_map(Name, Map),
              member(Heuristic, [manhattan, euclidean]),
              member(Solver, [a_star, ida_star]) ),
            Configs).

%% puzzle_configs(-Configs) is det.
puzzle_configs(Configs) :-
    findall(cfg(puzzle8, Name, Solver, Heuristic,
                problem(puzzle8, p8(State, Heuristic))),
            ( puzzle8_instances:instance(Name, _, State),
              member(Heuristic, [misplaced, manhattan]),
              member(Solver, [a_star, ida_star]) ),
            Configs).

%% labyrinth_map(?Name, ?Module) is nondet.
labyrinth_map(default_map, labyrinth_default_map).
labyrinth_map(multi_exit, labyrinth_multi_exit_map).
labyrinth_map(open_map, labyrinth_open_map).

%% run_config(+Config, +Repetitions, +Timeout, -Rows) is det.
run_config(Config, Repetitions, Timeout, Rows) :-
    Config = cfg(Domain, Instance, Solver, Heuristic, Problem),
    Options = [heuristic(Heuristic), max_expansions(1000000),
               timeout(Timeout)],
    findall(Row,
            ( between(1, Repetitions, Repetition),
              run_once(Domain, Instance, Solver, Heuristic, Problem,
                       Options, Repetition, Row) ),
            Rows).

%% run_once(+Domain, +Instance, +Solver, +Heuristic, +Problem, +Options,
%%          +Repetition, -Row) is det.
run_once(Domain, Instance, Solver, Heuristic, Problem, Options, Repetition,
         Row) :-
    garbage_collect,
    solve(Solver, Problem, Options, _Result, Stats),
    Cost = Stats.solution_cost,
    CpuMs is Stats.cpu * 1000,
    Status = Stats.status,
    Row = _{ domain: Domain,
             instance: Instance,
             solver: Solver,
             heuristic: Heuristic,
             repetition: Repetition,
             status: Status,
             cost: Cost,
             path_length: Stats.path_length,
             expanded: Stats.expanded,
             generated: Stats.generated,
             stale: Stats.stale,
             reopened: Stats.reopened,
             max_frontier: Stats.max_frontier,
             iterations: Stats.iterations,
             cpu_ms: CpuMs,
             peak_rss_kb: '' }.

%% solve(+Solver, +Problem, +Options, -Result, -Stats) is det.
solve(a_star, Problem, Options, Result, Stats) :-
    a_star(Problem, Options, Result, Stats).
solve(ida_star, Problem, Options, Result, Stats) :-
    ida_star(Problem, Options, Result, Stats).

%% summarize(+Config, +Rows, -Summary) is det.
%
%  Status and cost must agree across repetitions; the numeric counters are
%  reduced with the median so occasional GC jitter does not dominate.
summarize(cfg(Domain, Instance, Solver, Heuristic, _), Rows, Summary) :-
    Rows = [First|_],
    forall(member(Row, Rows), Row.status == First.status),
    median_field(path_length, Rows, PathLength),
    median_field(expanded, Rows, Expanded),
    median_field(generated, Rows, Generated),
    median_field(stale, Rows, Stale),
    median_field(reopened, Rows, Reopened),
    median_field(max_frontier, Rows, MaxFrontier),
    median_field(iterations, Rows, Iterations),
    median_field(cpu_ms, Rows, CpuMs),
    Summary = _{ domain: Domain,
                 instance: Instance,
                 solver: Solver,
                 heuristic: Heuristic,
                 status: First.status,
                 cost: First.cost,
                 path_length: PathLength,
                 expanded: Expanded,
                 generated: Generated,
                 stale: Stale,
                 reopened: Reopened,
                 max_frontier: MaxFrontier,
                 iterations: Iterations,
                 cpu_ms: CpuMs,
                 peak_rss_kb: '' }.

%% median_field(+Key, +Rows, -Median) is det.
median_field(Key, Rows, Median) :-
    findall(Value, ( member(Row, Rows), get_dict(Key, Row, Value) ), Values),
    median(Values, Median).

%% median(+Values, -Median) is det.
median(Values, Median) :-
    msort(Values, Sorted),
    length(Sorted, Count),
    Half is Count // 2,
    ( Count mod 2 =:= 1 ->
        nth0(Half, Sorted, Median)
    ;
        Previous is Half - 1,
        nth0(Half, Sorted, Upper),
        nth0(Previous, Sorted, Lower),
        Median is (Lower + Upper) / 2
    ).

%% bench_option(+Options, +Name, +Default, -Value) is det.
bench_option(Options, Name, Default, Value) :-
    ( member(Option, Options),
      Option =.. [Name, Value0] ->
        Value = Value0
    ;
        Value = Default
    ).

%% results_dir(-Dir) is det.
results_dir(Dir) :-
    module_property(bench, file(File)),
    file_directory_name(File, BenchDir),
    atomic_list_concat([BenchDir, '/results'], Dir),
    ( exists_directory(Dir) ->
        true
    ;
        make_directory_path(Dir)
    ).

%% write_csv_file(+Dir, +Name, +Header, +Rows) is det.
write_csv_file(Dir, Name, Header, Rows) :-
    atomic_list_concat([Dir, '/', Name], Path),
    setup_call_cleanup(open(Path, write, Stream),
                       ( csv_line(Stream, Header),
                         forall(member(Row, Rows),
                                csv_line(Stream, Row)) ),
                       close(Stream)).

%% csv_line(+Stream, +Row) is det.
%
%  Row is a dict for data rows or a plain list for the header. Values are
%  simple atoms, numbers, or '' and never contain commas.
csv_line(Stream, Row) :-
    ( is_list(Row) ->
        Fields = Row
    ; get_dict(repetition, Row, _) ->
        row_fields(Row, Fields)
    ;
        summary_fields(Row, Fields)
    ),
    maplist(csv_value, Fields, Values),
    atomic_list_concat(Values, ',', Line),
    format(Stream, '~w~n', [Line]).

%% run_header(-Header) is det.
run_header([domain, instance, solver, heuristic, repetition, status, cost,
            path_length, expanded, generated, stale, reopened, max_frontier,
            iterations, cpu_ms, peak_rss_kb]).

%% summary_header(-Header) is det.
summary_header([domain, instance, solver, heuristic, status, cost,
                path_length, expanded, generated, stale, reopened,
                max_frontier, iterations, cpu_ms, peak_rss_kb]).

%% row_fields(+Row, -Fields) is det.
row_fields(Row, [Row.domain, Row.instance, Row.solver, Row.heuristic,
                 Row.repetition, Row.status, Row.cost, Row.path_length,
                 Row.expanded, Row.generated, Row.stale, Row.reopened,
                 Row.max_frontier, Row.iterations, Row.cpu_ms,
                 Row.peak_rss_kb]).

%% summary_fields(+Summary, -Fields) is det.
summary_fields(Summary, [Summary.domain, Summary.instance, Summary.solver,
                         Summary.heuristic, Summary.status, Summary.cost,
                         Summary.path_length, Summary.expanded,
                         Summary.generated, Summary.stale, Summary.reopened,
                         Summary.max_frontier, Summary.iterations,
                         Summary.cpu_ms, Summary.peak_rss_kb]).

%% csv_value(+Value, -Atom) is det.
csv_value(none, '') :- !.
csv_value(Value, Atom) :- atom(Value), !, Atom = Value.
csv_value(Value, Atom) :- float(Value), !, format(atom(Atom), '~3f', [Value]).
csv_value(Value, Atom) :- format(atom(Atom), '~w', [Value]).

%% print_summary(+Summary) is det.
print_summary(Summary) :-
    format('~w ~w ~w ~w: ~w cost=~w expanded=~w cpu=~2fms~n',
           [Summary.domain, Summary.instance, Summary.solver,
            Summary.heuristic, Summary.status, Summary.cost,
            Summary.expanded, Summary.cpu_ms]).
