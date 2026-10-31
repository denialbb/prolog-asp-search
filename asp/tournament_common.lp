% Tournament round scheduling: shared generate-test core.
%
% Input facts supplied by the round instance:
%   round(N).              % round number, informational
%   player(P).             % active player
%   score(P, W).           % current wins of P, exactly one fact per player
%   played(X, Y).          % X and Y have already met (unordered)
%   had_bye(P).            % P received a BYE in an earlier round
%   new_player(P).         % P joined this round (also listed in player/1)
%
% Output:
%   match(X, Y)            % canonical pairing with X < Y
%   bye(P)                 % player without a match
%
% A round is a matching of the active players: every player has at most one
% opponent, and the unmatched player, if any, receives the BYE. Finding a
% matching is polynomial in general graphs; ASP is used here because the
% constraints are declarative and optimisation is built in, not because a
% single round is computationally hard. This file is the generate-test part;
% each objective model adds its own #minimize statements.

% A pairing is allowed unless the two players have already met. Both
% orientations are checked because played/2 is unordered.
candidate(X, Y) :-
    player(X), player(Y), X < Y,
    relax_repeat_pair.
candidate(X, Y) :-
    player(X), player(Y), X < Y,
    not relax_repeat_pair,
    not played(X, Y),
    not played(Y, X).

% Generate canonical pairs only: the guard X < Y makes match(a, b) and
% match(b, a) the same decision, never two independent ones.
{match(X, Y) : candidate(X, Y)}.

% incident(P, Q) is true when P is paired with Q, regardless of which
% identifier is smaller. This lets the next constraint count both
% orientations of every match.
incident(P, Q) :- match(P, Q).
incident(P, Q) :- match(Q, P).

:- player(P), 2 {incident(P, Q) : player(Q)}.

has_match(P) :- incident(P, _).
bye(P) :- player(P), not has_match(P).

nplayers(N) :- N = #count{P : player(P)}.
odd_field :- nplayers(N), N \ 2 = 1.
even_field :- nplayers(N), N \ 2 = 0.

bye_count(N) :- N = #count{P : bye(P)}.

% An odd field has exactly one BYE; an even field has none. Together with
% "at most one incident match" this also guarantees that every non-BYE
% player is paired.
:- odd_field, bye_count(N), N != 1.
:- even_field, bye_count(N), N != 0.

% A player may receive the BYE at most once in the whole tournament.
:- not relax_bye, bye(P), had_bye(P).

% The input contract is enforced explicitly so that a malformed instance is
% rejected instead of silently producing a schedule from missing data.
:- #count{P : player(P)} = 0.
:- new_player(P), not player(P).
:- player(P), not score(P, _).
:- player(P), score(P, S1), score(P, S2), S1 != S2.

% Absolute score difference, one rule per guard. A signed subtraction would
% let negative and positive gaps cancel in the objective.
diff(X, Y, D) :-
    match(X, Y), score(X, SX), score(Y, SY), SX >= SY, D = SX - SY.
diff(X, Y, D) :-
    match(X, Y), score(X, SX), score(Y, SY), SX < SY, D = SY - SX.

unequal_pair(X, Y) :- match(X, Y), diff(X, Y, D), D > 0.

bye_score(P, S) :- bye(P), score(P, S).

% Diagnostic switches, false unless the driver explicitly assigns them.
% They are used only by the UNSAT relaxation ladder, never by the official
% model: relaxing a rule changes feasibility, not the published schedule.
#external relax_bye.
#external relax_repeat_pair.

#show match/2.
#show bye/1.
#show unequal_pair/2.
