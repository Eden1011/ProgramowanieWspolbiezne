#!/bin/bash

# ========================================================================
# GRA W TRZY KARTY - Program współbieżny z synchronizacją przez pipes
# ========================================================================
#
# OPIS GRY:
# Gra dla dwóch graczy uruchamiana w tym samym programie.
# - Gracz 1: Wybiera pozycję wygrywającej karty (1, 2 lub 3)
# - Gracz 2: Próbuje odgadnąć wybraną pozycję
# - Zasady punktacji:
#   * Jeśli pozycje są TAKIE SAME → wygrywa Gracz 2
#   * Jeśli pozycje są RÓŻNE → wygrywa Gracz 1
# - Rozgrywka: 3 tury, kto więcej wygranych tur - wygrywa całą grę
#
# MECHANIZM SYNCHRONIZACJI:
# Program wykorzystuje mechanizmy IPC (Inter-Process Communication):
# - Named pipe (FIFO) do synchronizacji momentów zapisu i odczytu
# - Pliki jako "pamięć współdzielona" (PW1 i PW2)
# - Katalog jako mutex do rozróżnienia graczy
#
# ========================================================================

# ------------------------------------------------------------------
# KONFIGURACJA ŚCIEŻEK I ZMIENNYCH GLOBALNYCH
# ------------------------------------------------------------------

# Katalog gry - tworzenie katalogu jest operacją atomową, wykorzystujemy
# to do rozróżnienia, który proces jest Graczem 1 (pierwszy tworzy), a który Graczem 2
GAME_DIR="/tmp/three_cards_game_lock"

# Pliki pełniące rolę "pamięci współdzielonej":
# - PW1 (Player Write 1): Gracz 1 zapisuje tutaj swój wybór
# - PW2 (Player Write 2): Gracz 2 zapisuje tutaj swój wybór
FILE_P1_CHOICE="$GAME_DIR/player1_choice.txt"
FILE_P2_CHOICE="$GAME_DIR/player2_choice.txt"

# Named pipe (FIFO) do synchronizacji procesów
# Służy do sygnalizowania momentów: "zapisałem już wybór", "gotowy do następnej tury" itp.
PIPE_SYNC="$GAME_DIR/sync_pipe"

# Identyfikator gracza: 1 lub 2 (ustalany podczas inicjalizacji)
PLAYER_NUM=0

# Liczba tur do rozegrania
TOTAL_ROUNDS=3

# Liczniki punktów
MY_SCORE=0       # Punkty mojego procesu (tego, który aktualnie działa)
OPPONENT_SCORE=0 # Punkty przeciwnika

# Flaga zabezpieczająca przed wielokrotnym czyszczeniem zasobów
CLEANUP_DONE=0

# ------------------------------------------------------------------
# FUNKCJE CZYSZCZĄCE I OBSŁUGA SYGNAŁÓW
# ------------------------------------------------------------------

# Funkcja czyszcząca zasoby po zakończeniu gry
# Wywołuje ją:
# - Automatycznie na końcu skryptu (trap EXIT)
# - Przy przerwaniu programu (Ctrl+C, kill, zamknięcie terminala)
cleanup() {
	# Zabezpieczenie przed wielokrotnym wywołaniem funkcji
	# (może być wywołana zarówno przez EXIT jak i przez sygnał INT/TERM)
	if [ $CLEANUP_DONE -eq 1 ]; then
		return
	fi
	CLEANUP_DONE=1

	# Tylko Gracz 1 odpowiada za czyszczenie wspólnych zasobów
	# (Gracz 1 utworzył katalog i zasoby, więc on też je usuwa)
	if [ "$PLAYER_NUM" -eq 1 ]; then
		echo ""
		echo "Gracz 1 czyści zasoby..."

		# Zamykamy deskryptory pipe (jeśli zostały otwarte)
		# 2>/dev/null - ignorujemy błędy jeśli deskryptor nie jest otwarty
		exec 3>&- 2>/dev/null # Zamknięcie zapisu (write end)
		exec 3<&- 2>/dev/null # Zamknięcie odczytu (read end)

		# Usuwamy cały katalog gry wraz z wszystkimi zasobami:
		# - named pipe (FIFO)
		# - pliki z wyborami graczy (PW1, PW2)
		rm -rf "$GAME_DIR" 2>/dev/null

		echo "Zasoby wyczyszczone."
	fi
}

# Obsługa przerwania programu przez sygnały systemowe
# Najpierw czyścimy zasoby, potem kończymy program z odpowiednim kodem wyjścia
handle_interrupt() {
	cleanup
	exit $1 # Kod wyjścia przekazany jako parametr (130, 143 lub 129)
}

# ------------------------------------------------------------------
# REJESTRACJA PUŁAPEK SYGNAŁÓW (Signal Traps)
# ------------------------------------------------------------------
# Pułapki zapewniają, że funkcje czyszczące zawsze zostaną wykonane,
# niezależnie od sposobu zakończenia programu

# EXIT - wykonuje się przy każdym zakończeniu (normalnym lub przez exit)
trap cleanup EXIT

# INT (SIGINT) - Ctrl+C - użytkownik przerywa program z klawiatury
# Kod wyjścia 130 = 128 + 2 (gdzie 2 to numer sygnału INT)
trap 'handle_interrupt 130' INT

# TERM (SIGTERM) - standardowe polecenie kill (domyślny sygnał)
# Kod wyjścia 143 = 128 + 15 (gdzie 15 to numer sygnału TERM)
trap 'handle_interrupt 143' TERM

# HUP (SIGHUP) - zamknięcie terminala lub utrata połączenia
# Kod wyjścia 129 = 128 + 1 (gdzie 1 to numer sygnału HUP)
trap 'handle_interrupt 129' HUP

# ------------------------------------------------------------------
# INICJALIZACJA GRACZY - ROZPOZNAWANIE GRACZ 1 vs GRACZ 2
# ------------------------------------------------------------------
# MECHANIZM: mkdir jest operacją atomową - albo się uda, albo nie.
# Pierwszy proces, któremu uda się utworzyć katalog → Gracz 1
# Drugi proces, któremu NIE uda się (katalog już istnieje) → Gracz 2

if mkdir "$GAME_DIR" 2>/dev/null; then
	# ============================================================
	# GRACZ 1 - INICJALIZACJA
	# ============================================================
	# Ten proces jako pierwszy utworzył katalog, więc jest Graczem 1
	PLAYER_NUM=1

	echo "=========================================="
	echo "  Jesteś GRACZEM 1"
	echo "=========================================="
	echo ""

	# Gracz 1 tworzy wszystkie zasoby komunikacji międzyprocesowej:

	# 1. Named pipe (FIFO) do synchronizacji
	#    mkfifo tworzy specjalny plik, który działa jak kolejka FIFO
	#    Operacje zapisu blokują się dopóki ktoś nie odczyta danych
	mkfifo "$PIPE_SYNC"

	# 2. Pliki do przechowywania wyborów graczy (symulacja pamięci współdzielonej)
	touch "$FILE_P1_CHOICE"
	touch "$FILE_P2_CHOICE"

	echo "Oczekiwanie na Gracza 2..."

	# Czekamy na sygnał "ready" od Gracza 2
	# Używamy read z timeoutem (-t 1), aby:
	# - Nie blokować się na zawsze
	# - Umożliwić obsługę sygnałów przerwania (Ctrl+C)
	# Bez timeoutu sygnały mogłyby nie być obsługiwane natychmiast
	while true; do
		if read -t 1 <"$PIPE_SYNC" 2>/dev/null; then
			# Gracz 2 wysłał sygnał - możemy rozpocząć grę
			break
		fi
		# Timeout pozwala na obsługę sygnałów co 1 sekundę
	done

else
	# ============================================================
	# GRACZ 2 - INICJALIZACJA
	# ============================================================
	# Katalog już istnieje, więc ten proces jest Graczem 2
	PLAYER_NUM=2

	# Czekamy aż Gracz 1 utworzy named pipe
	# Sprawdzamy czy plik jest pipe'em (-p test)
	while [ ! -p "$PIPE_SYNC" ]; do
		sleep 0.1 # Krótki aby nie obciążać procesora
	done

	echo "=========================================="
	echo "  Jesteś GRACZEM 2"
	echo "=========================================="
	echo ""

	# Sygnalizujemy Graczowi 1, że jesteśmy gotowi do gry
	# Zapis do pipe odblokowuje czytającego Gracza 1
	echo "ready" >"$PIPE_SYNC"
fi

# ------------------------------------------------------------------
# FUNKCJE POMOCNICZE
# ------------------------------------------------------------------

# Funkcja walidująca wybór gracza
# Akceptuje tylko liczby 1, 2 lub 3
validate_choice() {
	local choice=$1

	# Regex ^[1-3]$ oznacza:
	# ^ - początek stringa
	# [1-3] - dokładnie jedna cyfra z zakresu 1-3
	# $ - koniec stringa
	if [[ "$choice" =~ ^[1-3]$ ]]; then
		return 0 # Poprawny wybór
	else
		return 1 # Niepoprawny wybór
	fi
}

# Bezpieczna funkcja odczytu z pipe z obsługą timeoutu
# - Bez timeoutu operacja read może zablokować proces i zignorować sygnały (Ctrl+C)
# - Z timeoutem możemy co 1 sekundę sprawdzać czy dostaliśmy sygnał przerwania
safe_read_pipe() {
	while true; do
		# read -t 1 - timeout 1 sekunda
		# Jeśli w ciągu 1s przychodzą dane z pipe, zwracamy 0 (sukces)
		if read -t 1 <"$PIPE_SYNC" 2>/dev/null; then
			return 0
		fi
		# Jeśli timeout - pętla się powtarza, co pozwala na obsługę sygnałów
		# (trap sprawdza sygnały między iteracjami pętli)
	done
}

# ==================================================================
# GŁÓWNA PĘTLA GRY - 3 TURY
# ==================================================================
# PROTOKÓŁ SYNCHRONIZACJI W KAŻDEJ TURZE:
# 1. Gracz 1 zapisuje wybór do PW1, wysyła sygnał "sync_p1_wrote"
# 2. Gracz 2 czeka na sygnał, wpisuje wybór, zapisuje do PW2, wysyła "sync_p2_wrote"
# 3. Gracz 1 czeka na sygnał, odczytuje PW2
# 4. Gracz 2 odczytuje PW1
# 5. Obaj wyświetlają wyniki
# 6. Synchronizacja przed następną turą (aby obaj widzieli wyniki przed kontynuacją)
# ==================================================================

for round in $(seq 1 $TOTAL_ROUNDS); do
	echo ""
	echo "=========================================="
	echo "  TURA $round / $TOTAL_ROUNDS"
	echo "=========================================="

	if [ "$PLAYER_NUM" -eq 1 ]; then
		# ============================================================
		# LOGIKA GRACZA 1 (USTALA POZYCJĘ WYGRYWAJĄCEJ KARTY)
		# ============================================================

		# KROK 1: Gracz 1 wybiera pozycję wygrywającej karty (1, 2 lub 3)
		while true; do
			echo -n "Wybierz pozycję wygrywającej karty (1, 2 lub 3): "
			read my_choice

			# Walidacja - czy wybór to 1, 2 lub 3
			if validate_choice "$my_choice"; then
				break # Poprawny wybór - wychodzimy z pętli
			else
				echo "Błędny wybór! Wybierz 1, 2 lub 3."
			fi
		done

		echo "Twój wybór: $my_choice"
		echo "Zapisywanie wyboru do pamięci współdzielonej PW1..."

		# Zapisujemy wybór do pliku PW1 (Player Write 1)
		# Gracz 2 odczyta to później
		echo "$my_choice" >"$FILE_P1_CHOICE"

		# SYNCHRONIZACJA: Wysyłamy sygnał przez pipe, że zapisaliśmy wybór
		# To odblokowuje Gracza 2, który czeka na ten sygnał
		echo "sync_p1_wrote" >"$PIPE_SYNC"

		# KROK 2: Czekamy aż Gracz 2 też zapisze swój wybór
		echo "Oczekiwanie na wybór Gracza 2..."
		safe_read_pipe # Blokujemy się na odczycie z pipe (czekamy na "sync_p2_wrote")

		# KROK 3: Odczytujemy wybór Gracza 2 z pliku PW2
		opponent_choice=$(cat "$FILE_P2_CHOICE")

		# KROK 4: Obliczamy wynik tury i wyświetlamy
		echo ""
		echo "--- Wyniki tury $round ---"
		echo "Twój wybór (Gracz 1): $my_choice"
		echo "Wybór Gracza 2: $opponent_choice"

		# ZASADY PUNKTACJI:
		# - Jeśli pozycje SĄ TAKIE SAME → Gracz 2 wygrywa
		# - Jeśli pozycje SĄ RÓŻNE → Gracz 1 wygrywa
		if [ "$my_choice" -eq "$opponent_choice" ]; then
			echo "Pozycje SĄ TAKIE SAME - Gracz 2 WYGRYWA tę turę!"
			((OPPONENT_SCORE++)) # Zwiększamy wynik przeciwnika
		else
			echo "Pozycje SĄ RÓŻNE - Gracz 1 (TY) WYGRYWA tę turę!"
			((MY_SCORE++)) # Zwiększamy nasz wynik
		fi

		echo ""
		echo "Aktualny wynik:"
		echo "  Gracz 1 (TY): $MY_SCORE"
		echo "  Gracz 2:      $OPPONENT_SCORE"

		# SYNCHRONIZACJA PRZED NASTĘPNĄ TURĄ
		# Zapewniamy, że obaj gracze zobaczą wyniki przed rozpoczęciem kolejnej tury
		if [ $round -lt $TOTAL_ROUNDS ]; then
			echo "sync_p1_displayed" >"$PIPE_SYNC" # Sygnał: wyświetliłem wyniki
			safe_read_pipe                         # Czekamy aż Gracz 2 też wyświetli
		fi

	else
		# ============================================================
		# LOGIKA GRACZA 2 (PRÓBUJE ODGADNĄĆ POZYCJĘ)
		# ============================================================

		# KROK 1: Czekamy aż Gracz 1 zapisze swój wybór
		# To zapewnia, że Gracz 2 nie może podejrzeć wyboru przed podjęciem decyzji
		safe_read_pipe # Blokujemy się na "sync_p1_wrote"

		# KROK 2: Gracz 2 próbuje odgadnąć pozycję (nie znając wyboru Gracza 1)
		while true; do
			echo -n "Typuj pozycję wygrywającej karty (1, 2 lub 3): "
			read my_choice

			# Walidacja - czy wybór to 1, 2 lub 3
			if validate_choice "$my_choice"; then
				break # Poprawny wybór - wychodzimy z pętli
			else
				echo "Błędny wybór! Wybierz 1, 2 lub 3."
			fi
		done

		echo "Twój wybór: $my_choice"
		echo "Zapisywanie wyboru do pamięci współdzielonej PW2..."

		# Zapisujemy wybór do pliku PW2 (Player Write 2)
		# Gracz 1 odczyta to później
		echo "$my_choice" >"$FILE_P2_CHOICE"

		# SYNCHRONIZACJA: Wysyłamy sygnał przez pipe, że zapisaliśmy wybór
		# To odblokowuje Gracza 1, który czeka na nasz wybór
		echo "sync_p2_wrote" >"$PIPE_SYNC"

		# KROK 3: Odczytujemy wybór Gracza 1 z pliku PW1
		echo "Oczekiwanie na odczytanie wyboru Gracza 1..."
		opponent_choice=$(cat "$FILE_P1_CHOICE")

		# KROK 4: Obliczamy wynik tury i wyświetlamy
		echo ""
		echo "--- Wyniki tury $round ---"
		echo "Twój wybór (Gracz 2): $my_choice"
		echo "Wybór Gracza 1: $opponent_choice"

		# ZASADY PUNKTACJI (z perspektywy Gracza 2):
		# - Jeśli pozycje SĄ TAKIE SAME → Gracz 2 (TY) wygrywa
		# - Jeśli pozycje SĄ RÓŻNE → Gracz 1 wygrywa
		if [ "$my_choice" -eq "$opponent_choice" ]; then
			echo "Pozycje SĄ TAKIE SAME - Gracz 2 (TY) WYGRYWA tę turę!"
			((MY_SCORE++)) # Zwiększamy nasz wynik
		else
			echo "Pozycje SĄ RÓŻNE - Gracz 1 WYGRYWA tę turę!"
			((OPPONENT_SCORE++)) # Zwiększamy wynik przeciwnika
		fi

		echo ""
		echo "Aktualny wynik:"
		echo "  Gracz 1:      $OPPONENT_SCORE"
		echo "  Gracz 2 (TY): $MY_SCORE"

		# SYNCHRONIZACJA PRZED NASTĘPNĄ TURĄ
		# Zapewniamy, że obaj gracze zobaczą wyniki przed rozpoczęciem kolejnej tury
		if [ $round -lt $TOTAL_ROUNDS ]; then
			safe_read_pipe                         # Czekamy aż Gracz 1 wyświetli wyniki
			echo "sync_p2_displayed" >"$PIPE_SYNC" # Sygnał: my też wyświetliliśmy
		fi
	fi
done

echo ""
echo "=========================================="
echo "  GRA ZAKOŃCZONA!"
echo "=========================================="
echo ""
echo "KOŃCOWY WYNIK:"

# Wyświetlamy wynik z odpowiedniej perspektywy (Gracz 1 vs Gracz 2)
if [ "$PLAYER_NUM" -eq 1 ]; then
	# Perspektywa Gracza 1
	echo "  Gracz 1 (TY): $MY_SCORE"
	echo "  Gracz 2:      $OPPONENT_SCORE"
	echo ""

	# Określamy zwycięzcę
	if [ $MY_SCORE -gt $OPPONENT_SCORE ]; then
		echo "GRATULACJE! WYGRAŁEŚ GRĘ!"
	elif [ $MY_SCORE -lt $OPPONENT_SCORE ]; then
		echo "Niestety przegrałeś. Spróbuj ponownie!"
	else
		echo "REMIS!"
	fi

else
	# Perspektywa Gracza 2
	echo "  Gracz 1:      $OPPONENT_SCORE"
	echo "  Gracz 2 (TY): $MY_SCORE"
	echo ""

	# Określamy zwycięzcę
	if [ $MY_SCORE -gt $OPPONENT_SCORE ]; then
		echo "GRATULACJE! WYGRAŁEŚ GRĘ!"
	elif [ $MY_SCORE -lt $OPPONENT_SCORE ]; then
		echo "Niestety przegrałeś. Spróbuj ponownie!"
	else
		echo "REMIS!"
	fi
fi

echo "=========================================="

sleep 1
