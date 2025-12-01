import json

# Message types
CHOICE_ROCK = "R"
CHOICE_PAPER = "P"
CHOICE_SCISSORS = "S"
CHOICE_END = "END"

# Valid choices
VALID_CHOICES = [CHOICE_ROCK, CHOICE_PAPER, CHOICE_SCISSORS, CHOICE_END]


def encode_choice(choice):
    return choice.upper().encode("utf-8")


def decode_choice(data):
    return data.decode("utf-8").strip()


def encode_response(
    opponent_choice, result, player_score, opponent_score, game_status, message=""
):
    response = {
        "opponent_choice": opponent_choice,
        "result": result,
        "your_score": player_score,
        "opponent_score": opponent_score,
        "game_status": game_status,
        "message": message,
    }
    return json.dumps(response).encode("utf-8")


def decode_response(data):
    return json.loads(data.decode("utf-8"))


def choice_to_name(choice):
    mapping = {
        CHOICE_ROCK: "Rock",
        CHOICE_PAPER: "Paper",
        CHOICE_SCISSORS: "Scissors",
        CHOICE_END: "End",
    }
    return mapping.get(choice, "Unknown")
