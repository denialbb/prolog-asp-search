% Round 2: one new player joins; the history is cumulative from round 1.
% Alice beat Bob, Carol beat Dave, and Erin had the BYE.

round(2).

player(alice).
player(bob).
player(carol).
player(dave).
player(erin).
player(frank).

score(alice, 4).
score(bob, 3).
score(carol, 3).
score(dave, 1).
score(erin, 1).
score(frank, 0).

played(alice, bob).
played(carol, dave).

had_bye(erin).

new_player(frank).
