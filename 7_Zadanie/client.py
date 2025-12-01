import socket
import sys

from protocol import (
    CHOICE_END,
    CHOICE_PAPER,
    CHOICE_ROCK,
    CHOICE_SCISSORS,
    choice_to_name,
    decode_response,
    encode_choice,
)

# Server configuration
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 5555
BUFFER_SIZE = 1024
TIMEOUT = 45  # seconds (slightly longer than server timeout)


class GameClient:
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(TIMEOUT)
        self.server_address = (SERVER_HOST, SERVER_PORT)
        self.my_score = 0
        self.opponent_score = 0

        print("=" * 60)
        print("         ROCK-PAPER-SCISSORS GAME")
        print("=" * 60)
        print(f"Connected to server at {SERVER_HOST}:{SERVER_PORT}")
        print("\nControls:")
        print("  R - Rock")
        print("  P - Paper")
        print("  S - Scissors")
        print("  E - End game")
        print("\nFirst to 3 points wins!")
        print("=" * 60)

    def get_user_choice(self):
        """Get user input for their choice."""
        while True:
            try:
                choice = input("\nYour choice (R/P/S/E): ").strip().upper()

                if choice in ["R", "P", "S"]:
                    return choice
                elif choice == "E":
                    return CHOICE_END
                else:
                    print(
                        "Invalid input! Use R (Rock), P (Paper), S (Scissors), or E (End)"
                    )
            except EOFError:
                return CHOICE_END
            except KeyboardInterrupt:
                print("\nExiting...")
                return CHOICE_END

    def display_result(self, response):
        """Display round result to user."""
        opponent_choice = response["opponent_choice"]
        result = response["result"]
        self.my_score = response["your_score"]
        self.opponent_score = response["opponent_score"]
        game_status = response["game_status"]
        message = response.get("message", "")

        print("\n" + "-" * 60)
        print("ROUND RESULT:")
        print(f"  Opponent chose: {choice_to_name(opponent_choice)}")

        if result == "win":
            print("  >>> YOU WON THIS ROUND! <<<")
        elif result == "lose":
            print("  >>> You lost this round <<<")
        elif result == "draw":
            print("  >>> DRAW <<<")

        print(f"\nCurrent Score: You {self.my_score} - {self.opponent_score} Opponent")

        if message:
            print(f"\n{message}")

        print("-" * 60)

        return game_status

    def run(self):
        """Main client loop."""
        try:
            while True:
                # Get user choice
                choice = self.get_user_choice()

                # Send choice to server
                message = encode_choice(choice)
                self.sock.sendto(message, self.server_address)

                if choice == CHOICE_END:
                    print("\nYou ended the game. Waiting for server response...")
                else:
                    print(f"Sent: {choice_to_name(choice)}")
                    print("Waiting for opponent...")

                # Wait for server response
                try:
                    data, _ = self.sock.recvfrom(BUFFER_SIZE)
                    response = decode_response(data)

                    game_status = self.display_result(response)

                    # Check if game ended
                    if game_status == "ended":
                        print("\nGame over. Disconnecting...")
                        break

                except socket.timeout:
                    print("\nTimeout! Server not responding.")
                    print("Game ended.")
                    break

        except KeyboardInterrupt:
            print("\n\nGame interrupted by user.")
        except Exception as e:
            print(f"\nError: {e}")
        finally:
            self.sock.close()
            print("Disconnected from server.")


if __name__ == "__main__":
    client = GameClient()
    client.run()
