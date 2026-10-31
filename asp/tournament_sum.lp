% Baseline tournament model: minimise the total absolute score difference.
%
% This model keeps the same hard constraints as the official model but has a
% single objective level. It is the reference point for showing that the
% lexicographic objective is not equivalent to a plain sum: a large score gap
% can outweigh several small ones, so the baseline may sacrifice equal-score
% matches to reduce the total difference.

#include "tournament_common.lp".

#minimize{D@1, X, Y : diff(X, Y, D)}.
