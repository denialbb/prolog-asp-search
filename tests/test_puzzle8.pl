:- begin_tests(puzzle8_rules).

% Manhattan distance between two coordinates
manhattan(pos(R1, C1), pos(R2, C2), D) :-
    D is abs(R1 - R2) + abs(C1 - C2).

test(manhattan_zero_for_same_pos) :-
    manhattan(pos(2, 2), pos(2, 2), 0).

test(manhattan_correct_distance) :-
    manhattan(pos(1, 1), pos(3, 3), 4),
    manhattan(pos(1, 2), pos(2, 1), 2).

% Goal state definition: tiles 1-8 ordered row-wise, blank (0) in pos(3,3)
goal_tile(pos(1, 1), 1).
goal_tile(pos(1, 2), 2).
goal_tile(pos(1, 3), 3).
goal_tile(pos(2, 1), 4).
goal_tile(pos(2, 2), 5).
goal_tile(pos(2, 3), 6).
goal_tile(pos(3, 1), 7).
goal_tile(pos(3, 2), 8).
goal_tile(pos(3, 3), 0).

test(goal_tiles_complete) :-
    findall(T, goal_tile(_, T), Tiles),
    sort(Tiles, Sorted),
    Sorted == [0, 1, 2, 3, 4, 5, 6, 7, 8].

:- end_tests(puzzle8_rules).
