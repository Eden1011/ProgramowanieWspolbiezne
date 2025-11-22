#!/bin/bash

GAME_DIR="/tmp/three_cards_game_lock"
FILE_P1_CHOICE="$GAME_DIR/player1_choice.txt"
FILE_P2_CHOICE="$GAME_DIR/player2_choice.txt"
PIPE_SYNC="$GAME_DIR/sync_pipe"

PLAYER_NUM=0
TOTAL_ROUNDS=3
MY_SCORE=0
OPPONENT_SCORE=0

CLEANUP_DONE=0

# Funkcja czyszcząca zasoby
cleanup() {
	# Zapobiegamy wielokrotnemu wykonaniu
	if [ $CLEANUP_DONE -eq 1 ]; then
		return
	fi
	CLEANUP_DONE=1

	if [ "$PLAYER_NUM" -eq 1 ]; then
		echo ""
		echo "Gracz 1 czyści zasoby..."
		# Wymuszamy zamknięcie pipe jeśli jest otwarty
		exec 3>&- 2>/dev/null
		exec 3<&- 2>/dev/null
		# Usuwamy cały katalog z zasobami
		rm -rf "$GAME_DIR" 2>/dev/null
		echo "Zasoby wyczyszczone."
	fi
}

# Obsługa przerwania - dla sygnałów które przerywają program
handle_interrupt() {
	cleanup
	exit $1
}

# Rejestracja funkcji czyszczącej - obsługujemy wszystkie ważne sygnały
trap cleanup EXIT
trap 'handle_interrupt 130' INT  # Ctrl+C (130 = 128 + 2)
trap 'handle_interrupt 143' TERM # kill (143 = 128 + 15)
trap 'handle_interrupt 129' HUP  # hangup (129 = 128 + 1)

# Próba utworzenia katalogu gry - pierwszy proces, któremu się uda, jest Graczem 1
if mkdir "$GAME_DIR" 2>/dev/null; then
	PLAYER_NUM=1
	echo "=========================================="
	echo "  Jesteś GRACZEM 1"
	echo "=========================================="
	echo ""

	# Tworzenie named pipe do synchronizacji
	mkfifo "$PIPE_SYNC"

	# Tworzenie plików na wybory
	touch "$FILE_P1_CHOICE"
	touch "$FILE_P2_CHOICE"

	echo "Oczekiwanie na Gracza 2..."
	# Czekamy aż Gracz 2 się podłączy (z timeoutem aby umożliwić obsługę sygnałów)
	while true; do
		if read -t 1 <"$PIPE_SYNC" 2>/dev/null; then
			break
		fi
		# Timeout pozwala na obsługę sygnałów
	done
else
	# Katalog już istnieje - jesteśmy Graczem 2
	PLAYER_NUM=2

	# Czekamy aż Gracz 1 utworzy pipes
	while [ ! -p "$PIPE_SYNC" ]; do
		sleep 0.1
	done

	echo "=========================================="
	echo "  Jesteś GRACZEM 2"
	echo "=========================================="
	echo ""

	# Sygnalizujemy Graczowi 1, że jesteśmy gotowi
	echo "ready" >"$PIPE_SYNC"
fi

# Funkcja walidująca wybór
validate_choice() {
	local choice=$1
	if [[ "$choice" =~ ^[1-3]$ ]]; then
		return 0
	else
		return 1
	fi
}

# Bezpieczny read z pipe z obsługą timeoutu (umożliwia obsługę sygnałów)
safe_read_pipe() {
	while true; do
		if read -t 1 <"$PIPE_SYNC" 2>/dev/null; then
			return 0
		fi
		# Timeout co 1s pozwala na obsługę sygnałów przerwania
	done
}

# Główna pętla gry - 3 tury
for round in $(seq 1 $TOTAL_ROUNDS); do
	echo ""
	echo "=========================================="
	echo "  TURA $round / $TOTAL_ROUNDS"
	echo "=========================================="

	if [ "$PLAYER_NUM" -eq 1 ]; then
		# ===== GRACZ 1 =====

		# 1. Gracz 1 ustala pozycję wygrywającej karty
		while true; do
			echo -n "Wybierz pozycję wygrywającej karty (1, 2 lub 3): "
			read my_choice
			if validate_choice "$my_choice"; then
				break
			else
				echo "Błędny wybór! Wybierz 1, 2 lub 3."
			fi
		done

		echo "Twój wybór: $my_choice"
		echo "Zapisywanie wyboru do pamięci współdzielonej PW1..."

		# Zapisujemy wybór do pliku
		echo "$my_choice" >"$FILE_P1_CHOICE"

		# Sygnalizujemy, że zapisaliśmy wybór
		echo "sync_p1_wrote" >"$PIPE_SYNC"

		# 2. Czekamy aż Gracz 2 też zapisze swój wybór
		echo "Oczekiwanie na wybór Gracza 2..."
		safe_read_pipe # Czekamy na sygnał od P2

		# 3. Odczytujemy wybór Gracza 2
		opponent_choice=$(cat "$FILE_P2_CHOICE")

		# 4. Wyświetlamy wyniki
		echo ""
		echo "--- Wyniki tury $round ---"
		echo "Twój wybór (Gracz 1): $my_choice"
		echo "Wybór Gracza 2: $opponent_choice"

		if [ "$my_choice" -eq "$opponent_choice" ]; then
			echo "Pozycje SĄ TAKIE SAME - Gracz 2 WYGRYWA tę turę!"
			((OPPONENT_SCORE++))
		else
			echo "Pozycje SĄ RÓŻNE - Gracz 1 (TY) WYGRYWA tę turę!"
			((MY_SCORE++))
		fi

		echo ""
		echo "Aktualny wynik:"
		echo "  Gracz 1 (TY): $MY_SCORE"
		echo "  Gracz 2:      $OPPONENT_SCORE"

		# Synchronizacja przed następną turą - Gracz 1 sygnalizuje że wyświetlił wyniki
		if [ $round -lt $TOTAL_ROUNDS ]; then
			echo "sync_p1_displayed" >"$PIPE_SYNC"
			# Czekamy aż Gracz 2 też wyświetli
			safe_read_pipe
		fi

	else
		# ===== GRACZ 2 =====

		# Czekamy aż Gracz 1 zapisze swój wybór
		safe_read_pipe # Czekamy na sygnał od P1

		# 1. Gracz 2 próbuje odgadnąć pozycję (nie znając wyboru Gracza 1)
		while true; do
			echo -n "Typuj pozycję wygrywającej karty (1, 2 lub 3): "
			read my_choice
			if validate_choice "$my_choice"; then
				break
			else
				echo "Błędny wybór! Wybierz 1, 2 lub 3."
			fi
		done

		echo "Twój wybór: $my_choice"
		echo "Zapisywanie wyboru do pamięci współdzielonej PW2..."

		# Zapisujemy wybór do pliku
		echo "$my_choice" >"$FILE_P2_CHOICE"

		# Sygnalizujemy, że zapisaliśmy wybór
		echo "sync_p2_wrote" >"$PIPE_SYNC"

		# 2. Odczytujemy wybór Gracza 1
		echo "Oczekiwanie na odczytanie wyboru Gracza 1..."
		opponent_choice=$(cat "$FILE_P1_CHOICE")

		# 3. Wyświetlamy wyniki
		echo ""
		echo "--- Wyniki tury $round ---"
		echo "Twój wybór (Gracz 2): $my_choice"
		echo "Wybór Gracza 1: $opponent_choice"

		if [ "$my_choice" -eq "$opponent_choice" ]; then
			echo "Pozycje SĄ TAKIE SAME - Gracz 2 (TY) WYGRYWA tę turę!"
			((MY_SCORE++))
		else
			echo "Pozycje SĄ RÓŻNE - Gracz 1 WYGRYWA tę turę!"
			((OPPONENT_SCORE++))
		fi

		echo ""
		echo "Aktualny wynik:"
		echo "  Gracz 1:      $OPPONENT_SCORE"
		echo "  Gracz 2 (TY): $MY_SCORE"

		# Synchronizacja przed następną turą - czekamy aż Gracz 1 wyświetli
		if [ $round -lt $TOTAL_ROUNDS ]; then
			safe_read_pipe
			# Sygnalizujemy że my też wyświetliliśmy
			echo "sync_p2_displayed" >"$PIPE_SYNC"
		fi
	fi
done

# Wyświetlenie końcowego wyniku
echo ""
echo "=========================================="
echo "  GRA ZAKOŃCZONA!"
echo "=========================================="
echo ""
echo "KOŃCOWY WYNIK:"
if [ "$PLAYER_NUM" -eq 1 ]; then
	echo "  Gracz 1 (TY): $MY_SCORE"
	echo "  Gracz 2:      $OPPONENT_SCORE"
	echo ""
	if [ $MY_SCORE -gt $OPPONENT_SCORE ]; then
		echo "GRATULACJE! WYGRAŁEŚ GRĘ!"
	elif [ $MY_SCORE -lt $OPPONENT_SCORE ]; then
		echo "Niestety przegrałeś. Spróbuj ponownie!"
	else
		echo "REMIS!"
	fi
else
	echo "  Gracz 1:      $OPPONENT_SCORE"
	echo "  Gracz 2 (TY): $MY_SCORE"
	echo ""
	if [ $MY_SCORE -gt $OPPONENT_SCORE ]; then
		echo "GRATULACJE! WYGRAŁEŚ GRĘ!"
	elif [ $MY_SCORE -lt $OPPONENT_SCORE ]; then
		echo "Niestety przegrałeś. Spróbuj ponownie!"
	else
		echo "REMIS!"
	fi
fi

echo "=========================================="

# Krótkie opóźnienie przed czyszczeniem (żeby obaj gracze zobaczyli wyniki)
sleep 1
