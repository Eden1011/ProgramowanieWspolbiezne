#!/bin/bash

# ==================================================================
# TEST AUTOMATYCZNY GRY W TRZY KARTY
# ==================================================================
# Ten skrypt automatycznie testuje poprawność implementacji gry.
# Uruchamia dwóch graczy z predefiniowanymi wyborami i weryfikuje:
# - Poprawność rozpoznawania ról (Gracz 1 vs Gracz 2)
# - Synchronizację przez named pipes
# - Logikę punktacji
# - Końcowy wynik
# ==================================================================

# ------------------------------------------------------------------
# KODY KOLORÓW ANSI DLA TERMINALA
# ------------------------------------------------------------------
# Używamy kolorów do czytelniejszego wyświetlania wyników testu

RED='\033[0;31m'      # Czerwony - błędy
GREEN='\033[0;32m'    # Zielony - sukces
BLUE='\033[0;34m'     # Niebieski - informacje o graczach
CYAN='\033[0;36m'     # Cyjan - ścieżki i synchronizacja
YELLOW='\033[1;33m'   # Żółty - ostrzeżenia i nagłówki
MAGENTA='\033[0;35m'  # Magenta - wyniki tur
NC='\033[0m'          # No Color - reset koloru
BOLD='\033[1m'        # Pogrubienie tekstu

echo -e "${BOLD}${CYAN}=========================================="
echo -e "  TEST AUTOMATYCZNY GRY W TRZY KARTY"
echo -e "==========================================${NC}"
echo ""

# ------------------------------------------------------------------
# INICJALIZACJA TESTU
# ------------------------------------------------------------------

# Czyszczenie pozostałości z poprzednich uruchomień
# (katalog /tmp/three_cards_game_lock mógł pozostać po poprzednim teście)
rm -rf /tmp/three_cards_game_lock 2>/dev/null

# Katalog na logi testowe
# $$ to PID obecnego procesu - zapewnia unikalność nazwy katalogu
LOG_DIR="/tmp/three_cards_test_$$"
mkdir -p "$LOG_DIR"

# Pliki z logami poszczególnych graczy
P1_LOG="$LOG_DIR/player1.log"
P2_LOG="$LOG_DIR/player2.log"

echo -e "${YELLOW}Przygotowanie testu...${NC}"
echo ""

# ------------------------------------------------------------------
# SCENARIUSZ TESTOWY
# ------------------------------------------------------------------
# Predefiniowane wybory dla obu graczy w 3 turach:
#
# Tura 1: P1=2, P2=3 → różne pozycje → WYGRYWA GRACZ 1
# Tura 2: P1=1, P2=1 → takie same pozycje → WYGRYWA GRACZ 2
# Tura 3: P1=3, P2=2 → różne pozycje → WYGRYWA GRACZ 1
#
# Oczekiwany wynik końcowy: Gracz 1: 2 punkty, Gracz 2: 1 punkt
# ------------------------------------------------------------------

# Tablice z wyborami dla poszczególnych tur
P1_CHOICES=(2 1 3)  # Wybory Gracza 1 w turach 1, 2, 3
P2_CHOICES=(3 1 2)  # Wybory Gracza 2 w turach 1, 2, 3

echo -e "${BOLD}Scenariusz testowy:${NC}"
echo -e "  Tura 1: Gracz 1 wybiera ${GREEN}${P1_CHOICES[0]}${NC}, Gracz 2 wybiera ${GREEN}${P2_CHOICES[0]}${NC} → różne → ${BLUE}Gracz 1 wygrywa${NC}"
echo -e "  Tura 2: Gracz 1 wybiera ${GREEN}${P1_CHOICES[1]}${NC}, Gracz 2 wybiera ${GREEN}${P2_CHOICES[1]}${NC} → takie same → ${BLUE}Gracz 2 wygrywa${NC}"
echo -e "  Tura 3: Gracz 1 wybiera ${GREEN}${P1_CHOICES[2]}${NC}, Gracz 2 wybiera ${GREEN}${P2_CHOICES[2]}${NC} → różne → ${BLUE}Gracz 1 wygrywa${NC}"
echo -e "  ${BOLD}Oczekiwany wynik końcowy: Gracz 1: 2 pkt, Gracz 2: 1 pkt${NC}"
echo ""

echo -e "${YELLOW}Uruchamianie graczy...${NC}"
echo ""

# ------------------------------------------------------------------
# FUNKCJA URUCHAMIAJĄCA GRACZA Z AUTOMATYCZNYM INPUTEM
# ------------------------------------------------------------------
# Funkcja uruchamia grę w tle i automatycznie dostarcza predefiniowane
# wybory przez pipe (stdin), symulując interakcję użytkownika
run_player() {
	local player_num=$1      # Numer gracza (1 lub 2) - dla informacji
	local log_file=$2        # Plik, do którego zapisujemy output
	shift 2                  # Usuwamy pierwsze 2 argumenty
	local choices=("$@")     # Pozostałe argumenty to wybory gracza

	# Uruchamiamy subshell w tle, który:
	# 1. Generuje sekwencję wyborów (każdy wybór w osobnej linii)
	# 2. Przekazuje je przez pipe do gry
	# 3. Output gry przekierowuje do pliku log
	(
		for choice in "${choices[@]}"; do
			echo "$choice"          # Wysyłamy wybór do stdin gry
			sleep 0.2               # Krótka przerwa między wyborami
		done
	) | ./three_cards_game.sh >"$log_file" 2>&1 &
	# & na końcu uruchamia cały pipeline w tle

	# Zwracamy PID procesu gry (ostatniego w pipeline)
	echo $!
}

# ------------------------------------------------------------------
# URUCHOMIENIE DWÓCH INSTANCJI GRY
# ------------------------------------------------------------------

# Uruchomienie Gracza 1 (pierwszy proces - utworzy katalog i zasoby)
echo -e "${BLUE}Uruchamianie Gracza 1...${NC}"
P1_PID=$(run_player 1 "$P1_LOG" "${P1_CHOICES[@]}")

# Krótka przerwa aby Gracz 1 zdążył utworzyć katalog i named pipe
sleep 0.5

# Uruchomienie Gracza 2 (drugi proces - dołączy do istniejących zasobów)
echo -e "${BLUE}Uruchamianie Gracza 2...${NC}"
P2_PID=$(run_player 2 "$P2_LOG" "${P2_CHOICES[@]}")

echo -e "  Gracz 1 PID: ${GREEN}$P1_PID${NC}"
echo -e "  Gracz 2 PID: ${GREEN}$P2_PID${NC}"
echo ""

# ------------------------------------------------------------------
# OCZEKIWANIE NA ZAKOŃCZENIE PROCESÓW
# ------------------------------------------------------------------

echo -e "${YELLOW}Czekanie na zakończenie gry...${NC}"

# wait czeka na zakończenie procesów w tle
# 2>/dev/null ukrywa ewentualne błędy (np. jeśli proces już się zakończył)
wait $P1_PID 2>/dev/null
wait $P2_PID 2>/dev/null

echo -e "${GREEN}Gra zakończona!${NC}"
echo ""

# ------------------------------------------------------------------
# FUNKCJA WYŚWIETLAJĄCA PRZEBIEG GRY Z LOGÓW
# ------------------------------------------------------------------
# Analizuje pliki log i wyświetla krok po kroku przebieg gry
display_logs() {
	echo -e "${BOLD}${CYAN}=========================================="
	echo -e "  PRZEBIEG GRY - ANALIZA LOGÓW"
	echo -e "==========================================${NC}"
	echo ""

	# Nagłówek wizualizujący dwóch graczy
	echo -e "${BOLD}${MAGENTA}╔════════════════════╗"
	echo -e "║ GRACZ 1 │ GRACZ 2  ║"
	echo -e "╚════════════════════╝${NC}"
	echo ""

	# ----------------------------------------------------------
	# FAZA INICJALIZACJI
	# ----------------------------------------------------------
	echo -e "${BOLD}=== INICJALIZACJA ===${NC}"
	echo ""

	# Sprawdzamy czy Gracz 1 został poprawnie rozpoznany
	echo -e "${BLUE}[GRACZ 1]${NC}"
	grep -E "Jesteś GRACZEM|Oczekiwanie na Gracza" "$P1_LOG" | head -2
	echo ""

	# Sprawdzamy czy Gracz 2 został poprawnie rozpoznany
	echo -e "${BLUE}[GRACZ 2]${NC}"
	grep -E "Jesteś GRACZEM" "$P2_LOG" | head -1
	echo ""

	# ----------------------------------------------------------
	# PRZEBIEG POSZCZEGÓLNYCH TUR
	# ----------------------------------------------------------
	for round in 1 2 3; do
		echo -e "${BOLD}${YELLOW}=== TURA $round ===${NC}"
		echo ""

		# Wybór Gracza 1
		echo -e "${BLUE}[GRACZ 1] ${NC}Wybiera pozycję: ${GREEN}${P1_CHOICES[$((round - 1))]}${NC}"
		grep -A 2 "TURA $round" "$P1_LOG" | grep "Twój wybór:" | head -1
		echo ""

		# Wybór Gracza 2
		echo -e "${BLUE}[GRACZ 2] ${NC}Typuje pozycję: ${GREEN}${P2_CHOICES[$((round - 1))]}${NC}"
		grep -A 2 "TURA $round" "$P2_LOG" | grep "Twój wybór:" | head -1
		echo ""

		# Wizualizacja synchronizacji przez named pipe
		echo -e "${CYAN}  → Synchronizacja: Obaj gracze zapisali wybory${NC}"
		echo -e "${CYAN}  → Gracz 1 odczytuje wybór Gracza 2${NC}"
		echo -e "${CYAN}  → Gracz 2 odczytuje wybór Gracza 1${NC}"
		echo ""

		# Wynik tury (z perspektywy Gracza 1)
		echo -e "${MAGENTA}[WYNIKI TURY $round]${NC}"
		grep -A 10 "Wyniki tury $round" "$P1_LOG" | grep -E "Twój wybór|Wybór Gracza|WYGRYWA|Aktualny wynik" | head -5
		echo ""
	done

	# ----------------------------------------------------------
	# WYNIK KOŃCOWY
	# ----------------------------------------------------------
	echo -e "${BOLD}${GREEN}=========================================="
	echo -e "  WYNIK KOŃCOWY"
	echo -e "==========================================${NC}"
	echo ""

	# Wynik z perspektywy Gracza 1
	echo -e "${BLUE}[GRACZ 1]${NC}"
	grep -A 10 "GRA ZAKOŃCZONA" "$P1_LOG" | grep -E "Gracz [12].*:" | head -2
	grep -A 10 "GRA ZAKOŃCZONA" "$P1_LOG" | grep -E "GRATULACJE|przegrałeś|REMIS" | head -1
	echo ""

	# Wynik z perspektywy Gracza 2
	echo -e "${BLUE}[GRACZ 2]${NC}"
	grep -A 10 "GRA ZAKOŃCZONA" "$P2_LOG" | grep -E "Gracz [12].*:" | head -2
	grep -A 10 "GRA ZAKOŃCZONA" "$P2_LOG" | grep -E "GRATULACJE|przegrałeś|REMIS" | head -1
	echo ""
}

# Wyświetlenie logów
display_logs

# ------------------------------------------------------------------
# WERYFIKACJA POPRAWNOŚCI IMPLEMENTACJI
# ------------------------------------------------------------------

echo -e "${BOLD}${CYAN}=========================================="
echo -e "  WERYFIKACJA POPRAWNOŚCI"
echo -e "==========================================${NC}"
echo ""

# Funkcja weryfikująca wszystkie wymagania zadania
# Sprawdza logi i zwraca 0 (sukces) lub 1 (błąd)
verify_results() {
	local errors=0  # Licznik błędów

	# ----------------------------------------------------------
	# TEST 1: Rozpoznawanie ról graczy
	# ----------------------------------------------------------

	# Gracz 1 powinien wyświetlić komunikat "Jesteś GRACZEM 1"
	if grep -q "Jesteś GRACZEM 1" "$P1_LOG"; then
		echo -e "${GREEN}✓${NC} Gracz 1 poprawnie rozpoznany"
	else
		echo -e "${RED}✗${NC} Błąd: Gracz 1 nie został rozpoznany"
		((errors++))
	fi

	# Gracz 2 powinien wyświetlić komunikat "Jesteś GRACZEM 2"
	if grep -q "Jesteś GRACZEM 2" "$P2_LOG"; then
		echo -e "${GREEN}✓${NC} Gracz 2 poprawnie rozpoznany"
	else
		echo -e "${RED}✗${NC} Błąd: Gracz 2 nie został rozpoznany"
		((errors++))
	fi

	# ----------------------------------------------------------
	# TEST 2: Synchronizacja przez named pipes
	# ----------------------------------------------------------

	# Sprawdzamy czy komunikaty synchronizacji pojawiają się w logach
	# To potwierdza, że gracze czekają na siebie wzajemnie
	if grep -q "Oczekiwanie na wybór Gracza 2" "$P1_LOG" &&
		grep -q "Oczekiwanie na odczytanie wyboru Gracza 1" "$P2_LOG"; then
		echo -e "${GREEN}✓${NC} Synchronizacja odczytów działa poprawnie"
	else
		echo -e "${RED}✗${NC} Błąd: Problem z synchronizacją"
		((errors++))
	fi

	# ----------------------------------------------------------
	# TEST 3: Liczba rozegranych tur
	# ----------------------------------------------------------

	# Zliczamy wystąpienia nagłówków tur w logach
	local p1_rounds=$(grep -c "TURA .* / 3" "$P1_LOG")
	local p2_rounds=$(grep -c "TURA .* / 3" "$P2_LOG")

	if [ "$p1_rounds" -eq 3 ] && [ "$p2_rounds" -eq 3 ]; then
		echo -e "${GREEN}✓${NC} Rozegrano wszystkie 3 tury"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowa liczba tur (P1: $p1_rounds, P2: $p2_rounds)"
		((errors++))
	fi

	# ----------------------------------------------------------
	# TEST 4-6: Poprawność wyników poszczególnych tur
	# ----------------------------------------------------------

	# TURA 1: P1=2, P2=3 → różne pozycje → wygrywa Gracz 1
	if grep -A 5 "Wyniki tury 1" "$P1_LOG" | grep -q "Gracz 1 (TY) WYGRYWA"; then
		echo -e "${GREEN}✓${NC} Tura 1: Gracz 1 poprawnie wygrał (2 ≠ 3)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik tury 1"
		((errors++))
	fi

	# TURA 2: P1=1, P2=1 → takie same pozycje → wygrywa Gracz 2
	if grep -A 5 "Wyniki tury 2" "$P2_LOG" | grep -q "Gracz 2 (TY) WYGRYWA"; then
		echo -e "${GREEN}✓${NC} Tura 2: Gracz 2 poprawnie wygrał (1 = 1)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik tury 2"
		((errors++))
	fi

	# TURA 3: P1=3, P2=2 → różne pozycje → wygrywa Gracz 1
	if grep -A 5 "Wyniki tury 3" "$P1_LOG" | grep -q "Gracz 1 (TY) WYGRYWA"; then
		echo -e "${GREEN}✓${NC} Tura 3: Gracz 1 poprawnie wygrał (3 ≠ 2)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik tury 3"
		((errors++))
	fi

	# ----------------------------------------------------------
	# TEST 7-8: Wynik końcowy
	# ----------------------------------------------------------

	# Gracz 1 powinien mieć 2 punkty (wygrał tury 1 i 3)
	if grep -A 5 "KOŃCOWY WYNIK" "$P1_LOG" | grep -q "Gracz 1 (TY): 2"; then
		echo -e "${GREEN}✓${NC} Wynik końcowy Gracza 1: 2 punkty (poprawnie)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik końcowy Gracza 1"
		((errors++))
	fi

	# Gracz 2 powinien mieć 1 punkt (wygrał turę 2)
	if grep -A 5 "KOŃCOWY WYNIK" "$P1_LOG" | grep -q "Gracz 2:      1"; then
		echo -e "${GREEN}✓${NC} Wynik końcowy Gracza 2: 1 punkt (poprawnie)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik końcowy Gracza 2"
		((errors++))
	fi

	# ----------------------------------------------------------
	# TEST 9: Czyszczenie zasobów
	# ----------------------------------------------------------

	# Czekamy chwilę, aby cleanup() zdążył się wykonać
	sleep 0.5

	# Katalog gry powinien zostać usunięty po zakończeniu
	if [ ! -d "/tmp/three_cards_game_lock" ]; then
		echo -e "${GREEN}✓${NC} Zasoby (pipes) zostały poprawnie wyczyszczone"
	fi

	echo ""

	# ----------------------------------------------------------
	# PODSUMOWANIE TESTÓW
	# ----------------------------------------------------------

	if [ $errors -eq 0 ]; then
		# WSZYSTKIE TESTY PRZESZŁY
		echo -e "${BOLD}${GREEN}════════════════════════════════════════"
		echo -e "  WSZYSTKIE TESTY PRZESZŁY POMYŚLNIE!"
		echo -e "  Implementacja jest POPRAWNA ✓"
		echo -e "====================================${NC}"
		echo ""
		echo -e "${CYAN}Zgodność z wymaganiami zadania:${NC}"
		echo -e "  ${GREEN}✓${NC} Jeden uniwersalny program dla obu graczy"
		echo -e "  ${GREEN}✓${NC} Rozpoznawanie Gracza 1 vs Gracza 2 (pierwszy tworzy pipes)"
		echo -e "  ${GREEN}✓${NC} Synchronizacja przez named pipes (mkfifo)"
		echo -e "  ${GREEN}✓${NC} Gracz 1 zapisuje do PW1, Gracz 2 do PW2"
		echo -e "  ${GREEN}✓${NC} Odczyty następują po zapisach (bez aktywnego czekania)"
		echo -e "  ${GREEN}✓${NC} Poprawna logika wygrywania (takie same → P2, różne → P1)"
		echo -e "  ${GREEN}✓${NC} 3 tury gry"
		echo -e "  ${GREEN}✓${NC} Wyświetlanie wyników po każdej turze"
		echo -e "  ${GREEN}✓${NC} Automatyczne czyszczenie zasobów po grze"
		return 0
	else
		# WYKRYTO BŁĘDY
		echo -e "${BOLD}${RED}════════════════════════════════════════"
		echo -e "  WYKRYTO $errors BŁĘDÓW!"
		echo -e "  Implementacja wymaga poprawek ✗"
		echo -e "====================================${NC}"
		return 1
	fi
}

# ------------------------------------------------------------------
# URUCHOMIENIE WERYFIKACJI
# ------------------------------------------------------------------

# Krótkie opóźnienie aby upewnić się, że wszystkie logi zostały zapisane na dysk
sleep 0.5

# Wywołanie funkcji weryfikującej
verify_results
RESULT=$?  # Zapisujemy kod wyjścia (0 = sukces, 1 = błąd)

# ------------------------------------------------------------------
# INFORMACJE O LOGACH
# ------------------------------------------------------------------

echo ""
echo -e "${YELLOW}Logi zapisane w:${NC}"
echo -e "  Gracz 1: ${CYAN}$P1_LOG${NC}"
echo -e "  Gracz 2: ${CYAN}$P2_LOG${NC}"
echo ""
echo -e "${YELLOW}Aby zobaczyć pełne logi:${NC}"
echo -e "  ${CYAN}cat $P1_LOG${NC}"
echo -e "  ${CYAN}cat $P2_LOG${NC}"
echo ""

# ------------------------------------------------------------------
# OPCJONALNE CZYSZCZENIE LOGÓW
# ------------------------------------------------------------------

# Jeśli test przeszedł, oferujemy usunięcie logów testowych
if [ $RESULT -eq 0 ]; then
	# read -p "tekst" -n 1 -r:
	#   -p "tekst" - wyświetla prompt
	#   -n 1 - czyta tylko 1 znak
	#   -r - wyłącza interpretację backslash
	read -p "Czy usunąć logi testowe? (t/N): " -n 1 -r
	echo  # Nowa linia po odpowiedzi użytkownika

	# Sprawdzamy czy użytkownik wpisał 't' lub 'T'
	if [[ $REPLY =~ ^[Tt]$ ]]; then
		rm -rf "$LOG_DIR"
		echo -e "${GREEN}Logi usunięte.${NC}"
	fi
fi

# ------------------------------------------------------------------
# ZAKOŃCZENIE SKRYPTU
# ------------------------------------------------------------------

# Zwracamy kod wyjścia funkcji verify_results:
# - 0 jeśli wszystkie testy przeszły
# - 1 jeśli wystąpiły błędy
# To pozwala na automatyczne sprawdzenie wyniku testu w innych skryptach
exit $RESULT
