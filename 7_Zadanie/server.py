import socket
import time

from game_logic import determine_winner, get_result_string
from protocol import (
    CHOICE_END,
    VALID_CHOICES,
    choice_to_name,
    decode_choice,
    encode_response,
)

# Server configuration
HOST = "127.0.0.1"
PORT = 5555
BUFFER_SIZE = 1024
TIMEOUT = 40  # seconds
WINNING_SCORE = 3


class GameServer:
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((HOST, PORT))
        self.sock.settimeout(TIMEOUT)

        # Game state
        self.players = {}  # {address: player_id}
        self.player_ids = {}  # {player_id: address}
        self.scores = {1: 0, 2: 0}
        self.current_choices = {}  # {player_id: (choice, timestamp)}
        self.game_active = False

        print(f"Server started on {HOST}:{PORT}")
        print(f"Waiting for players to connect...")
        print(
            f"Game settings: First to {WINNING_SCORE} points wins, {TIMEOUT}s timeout"
        )
        print("-" * 60)

    def reset_game(self):
        """Reset game state for a new game."""
        self.players = {}
        self.player_ids = {}
        self.scores = {1: 0, 2: 0}
        self.current_choices = {}
        self.game_active = False
        print("\nGame reset. Waiting for new players...")
        print("-" * 60)

    def register_player(self, address):
        """Register a new player."""
        if address not in self.players:
            player_id = len(self.players) + 1
            if player_id <= 2:
                self.players[address] = player_id
                self.player_ids[player_id] = address
                print(f"Player {player_id} connected from {address}")

                if len(self.players) == 2:
                    self.game_active = True
                    print("Both players connected! Game starting...")
                    print(
                        f"Score: Player 1: {self.scores[1]} | Player 2: {self.scores[2]}"
                    )
                    print("-" * 60)

                return player_id
        return self.players.get(address)

    def check_game_over(self):
        """Check if game is over (someone reached winning score)."""
        for player_id, score in self.scores.items():
            if score >= WINNING_SCORE:
                return player_id
        return None

    def handle_choice(self, address, choice):
        """Handle a player's choice."""
        # Register player if not already registered
        player_id = self.register_player(address)

        if player_id is None or player_id > 2:
            # Too many players
            return

        print(f"Player {player_id} chose: {choice_to_name(choice)}")

        # Validate choice
        if choice not in VALID_CHOICES:
            print(f"Invalid choice from Player {player_id}: {choice}")
            return

        # Handle END choice
        if choice == CHOICE_END:
            self.handle_end_game(player_id)
            return

        # Store this player's choice
        self.current_choices[player_id] = (choice, time.time())

        # Check if we have choices from both players
        if len(self.current_choices) == 2 and self.game_active:
            # Both choices received, process round
            choice1, timestamp1 = self.current_choices[1]
            choice2, timestamp2 = self.current_choices[2]

            # Check timeout - use the older timestamp
            oldest_timestamp = min(timestamp1, timestamp2)
            if time.time() - oldest_timestamp > TIMEOUT:
                print(f"Timeout! Round took too long.")
                self.handle_timeout(1)  # Doesn't matter which player
                return

            # Process the round
            self.process_round(choice1, choice2)
            self.current_choices = {}
        else:
            # Waiting for other player
            if self.game_active:
                print(f"Waiting for Player {3 - player_id}'s choice...")
            else:
                print(f"Waiting for both players to connect...")

    def process_round(self, choice1, choice2):
        """Process a complete round with both choices.

        Args:
            choice1: Player 1's choice
            choice2: Player 2's choice
        """
        # Determine winner
        winner = determine_winner(choice1, choice2)

        print(f"\nRound result:")
        print(f"  Player 1: {choice_to_name(choice1)}")
        print(f"  Player 2: {choice_to_name(choice2)}")

        # Update scores
        if winner != 0:
            self.scores[winner] += 1
            print(f"  Winner: Player {winner}")
        else:
            print(f"  Draw!")

        print(f"Score: Player 1: {self.scores[1]} | Player 2: {self.scores[2]}")

        # Check if game is over
        game_winner = self.check_game_over()
        game_status = "ended" if game_winner else "active"

        if game_winner:
            print(f"\n*** GAME OVER! Player {game_winner} wins! ***")
            print("-" * 60)
        else:
            print("-" * 60)

        # Send results to both players
        for pid in [1, 2]:
            opponent_id = 3 - pid
            result = get_result_string(winner, pid)
            opponent_choice = choice2 if pid == 1 else choice1

            message = ""
            if game_winner:
                if game_winner == pid:
                    message = f"YOU WON THE GAME! Final score: {self.scores[pid]}-{self.scores[opponent_id]}"
                else:
                    message = f"You lost the game. Final score: {self.scores[pid]}-{self.scores[opponent_id]}"
                game_status = "ended"

            response = encode_response(
                opponent_choice,
                result,
                self.scores[pid],
                self.scores[opponent_id],
                game_status,
                message,
            )

            self.sock.sendto(response, self.player_ids[pid])

        # If game is over, reset
        if game_winner:
            time.sleep(0.5)  # Give clients time to receive final message
            self.reset_game()

    def handle_end_game(self, ending_player_id):
        """Handle when a player sends END."""
        print(f"Player {ending_player_id} ended the game.")

        # Check if the other player has a pending choice
        other_player_id = 3 - ending_player_id
        if other_player_id in self.current_choices:
            # Other player sent a choice, process that round first
            other_choice, _ = self.current_choices[other_player_id]

            if ending_player_id == 1:
                self.process_round(CHOICE_END, other_choice)
            else:
                self.process_round(other_choice, CHOICE_END)
            return

        # Send end game messages to both players
        for pid in [1, 2]:
            opponent_id = 3 - pid
            message = (
                "Game ended by player."
                if pid == ending_player_id
                else "Opponent ended the game."
            )

            response = encode_response(
                CHOICE_END,
                "game_over",
                self.scores[pid],
                self.scores[opponent_id],
                "ended",
                message,
            )

            if pid in self.player_ids:
                self.sock.sendto(response, self.player_ids[pid])

        print("Game ended by player.")
        print("-" * 60)
        time.sleep(0.5)
        self.reset_game()

    def handle_timeout(self, player_id):
        """Handle timeout situation."""
        print(f"Player {player_id} timed out!")

        # Send timeout messages
        for pid in [1, 2]:
            message = "You timed out!" if pid == player_id else "Opponent timed out!"
            opponent_id = 3 - pid

            response = encode_response(
                CHOICE_END,
                "game_over",
                self.scores[pid],
                self.scores[opponent_id],
                "ended",
                message,
            )

            if pid in self.player_ids:
                self.sock.sendto(response, self.player_ids[pid])

        print("Game ended due to timeout.")
        print("-" * 60)
        time.sleep(0.5)
        self.reset_game()

    def run(self):
        """Main server loop."""
        try:
            while True:
                try:
                    data, address = self.sock.recvfrom(BUFFER_SIZE)
                    choice = decode_choice(data)
                    self.handle_choice(address, choice)

                except socket.timeout:
                    # Check if we have a pending choice that timed out
                    if len(self.current_choices) > 0:
                        # Check if any choice has timed out
                        for player_id, (
                            choice,
                            timestamp,
                        ) in self.current_choices.items():
                            if time.time() - timestamp > TIMEOUT:
                                waiting_for_player = 3 - player_id
                                print(
                                    f"Player {waiting_for_player} timed out (didn't respond)."
                                )
                                self.handle_timeout(waiting_for_player)
                                break
                    continue

        except KeyboardInterrupt:
            print("\nServer shutting down...")
        finally:
            self.sock.close()


if __name__ == "__main__":
    server = GameServer()
    server.run()
