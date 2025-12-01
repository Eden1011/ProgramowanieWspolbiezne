from protocol import CHOICE_PAPER, CHOICE_ROCK, CHOICE_SCISSORS


def determine_winner(choice1, choice2):
    # Draw
    if choice1 == choice2:
        return 0

    # Player 1 wins
    if (
        (choice1 == CHOICE_ROCK and choice2 == CHOICE_SCISSORS)
        or (choice1 == CHOICE_SCISSORS and choice2 == CHOICE_PAPER)
        or (choice1 == CHOICE_PAPER and choice2 == CHOICE_ROCK)
    ):
        return 1

    # Player 2 wins
    return 2


def get_result_string(winner_id, player_id):
    if winner_id == 0:
        return "draw"
    elif winner_id == player_id:
        return "win"
    else:
        return "lose"
