% Round 3: one new player joins an odd field with two rounds of history.
% Erin already had a BYE in round 1, so the new BYE must go to someone else.

round(3).

player(alice).
player(bob).
player(carol).
player(dave).
player(erin).
player(frank).
player(grace).

score(alice, 5).
score(bob, 4).
score(carol, 3).
score(dave, 2).
score(erin, 1).
score(frank, 0).
score(grace, 0).

played(alice, bob).
played(alice, frank).
played(bob, carol).
played(carol, dave).
played(dave, erin).

had_bye(erin).

new_player(grace).
