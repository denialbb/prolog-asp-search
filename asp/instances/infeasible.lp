% Infeasible round: an odd field where every player already had a BYE.
% The BYE-uniqueness rule makes this round genuinely unsatisfiable; the
% driver's relaxation ladder reports that a repeated BYE is the only way out.

round(4).

player(alice).
player(bob).
player(carol).
player(dave).
player(erin).

score(alice, 4).
score(bob, 3).
score(carol, 2).
score(dave, 1).
score(erin, 0).

had_bye(alice).
had_bye(bob).
had_bye(carol).
had_bye(dave).
had_bye(erin).
