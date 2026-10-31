% Official tournament model: lexicographic score-balanced pairing.
%
% Objective hierarchy, most important first:
%   1. minimise the number of matches between players with different scores
%      (equivalently, maximise the number of equal-score matches);
%   2. minimise the total absolute score difference of the matches;
%   3. minimise the score of the player who receives the BYE, so that the
%      lowest-standing eligible player gets the free win when the first two
%      levels leave a choice.
%
% Clingo orders weak-constraint levels by descending @priority: the level
% with the highest number is optimised first. Each tuple carries X and Y
% because identical cost values would otherwise collapse into one element.

#include "tournament_common.lp".

#minimize{1@3, X, Y : unequal_pair(X, Y)}.
#minimize{D@2, X, Y : diff(X, Y, D)}.
#minimize{S@1, P : bye_score(P, S)}.
