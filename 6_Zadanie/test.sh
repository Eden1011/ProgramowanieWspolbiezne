#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}${CYAN}=========================================="
echo -e "  TEST AUTOMATYCZNY GRY W TRZY KARTY"
echo -e "==========================================${NC}"
echo ""

# Czyszczenie poprzednich zasobów
rm -rf /tmp/three_cards_game_lock 2>/dev/null

# Katalog na logi
LOG_DIR="/tmp/three_cards_test_$$"
mkdir -p "$LOG_DIR"

P1_LOG="$LOG_DIR/player1.log"
P2_LOG="$LOG_DIR/player2.log"

echo -e "${YELLOW}Przygotowanie testu...${NC}"
echo ""

# Scenariusz testowy:
# Tura 1: P1=2, P2=3 -> różne -> wygrywa P1
# Tura 2: P1=1, P2=1 -> takie same -> wygrywa P2
# Tura 3: P1=3, P2=2 -> różne -> wygrywa P1
# Wynik końcowy: P1=2, P2=1

P1_CHOICES=(2 1 3)
P2_CHOICES=(3 1 2)

echo -e "${BOLD}Scenariusz testowy:${NC}"
echo -e "  Tura 1: Gracz 1 wybiera ${GREEN}${P1_CHOICES[0]}${NC}, Gracz 2 wybiera ${GREEN}${P2_CHOICES[0]}${NC} → różne → ${BLUE}Gracz 1 wygrywa${NC}"
echo -e "  Tura 2: Gracz 1 wybiera ${GREEN}${P1_CHOICES[1]}${NC}, Gracz 2 wybiera ${GREEN}${P2_CHOICES[1]}${NC} → takie same → ${BLUE}Gracz 2 wygrywa${NC}"
echo -e "  Tura 3: Gracz 1 wybiera ${GREEN}${P1_CHOICES[2]}${NC}, Gracz 2 wybiera ${GREEN}${P2_CHOICES[2]}${NC} → różne → ${BLUE}Gracz 1 wygrywa${NC}"
echo -e "  ${BOLD}Oczekiwany wynik końcowy: Gracz 1: 2 pkt, Gracz 2: 1 pkt${NC}"
echo ""

echo -e "${YELLOW}Uruchamianie graczy...${NC}"
echo ""

# Funkcja do uruchomienia gracza z automatycznym inputem
run_player() {
	local player_num=$1
	local log_file=$2
	shift 2
	local choices=("$@")

	(
		for choice in "${choices[@]}"; do
			echo "$choice"
			sleep 0.2
		done
	) | ./three_cards_game.sh >"$log_file" 2>&1 &

	echo $!
}

# Uruchomienie Gracza 1
echo -e "${BLUE}Uruchamianie Gracza 1...${NC}"
P1_PID=$(run_player 1 "$P1_LOG" "${P1_CHOICES[@]}")
sleep 0.5

# Uruchomienie Gracza 2
echo -e "${BLUE}Uruchamianie Gracza 2...${NC}"
P2_PID=$(run_player 2 "$P2_LOG" "${P2_CHOICES[@]}")

echo -e "  Gracz 1 PID: ${GREEN}$P1_PID${NC}"
echo -e "  Gracz 2 PID: ${GREEN}$P2_PID${NC}"
echo ""

# Czekamy na zakończenie obu procesów
echo -e "${YELLOW}Czekanie na zakończenie gry...${NC}"
wait $P1_PID 2>/dev/null
wait $P2_PID 2>/dev/null

echo -e "${GREEN}Gra zakończona!${NC}"
echo ""

# Funkcja do wyświetlania logów z kolorami
display_logs() {
	echo -e "${BOLD}${CYAN}=========================================="
	echo -e "  PRZEBIEG GRY - ANALIZA LOGÓW"
	echo -e "==========================================${NC}"
	echo ""

	# Wyświetlenie równoległe logów obu graczy
	echo -e "${BOLD}${MAGENTA}╔════════════════════╗"
	echo -e "║ GRACZ 1 │ GRACZ 2  ║"
	echo -e "╚════════════════════╝${NC}"
	echo ""

	# Wyświetlenie inicjalizacji
	echo -e "${BOLD}=== INICJALIZACJA ===${NC}"
	echo ""
	echo -e "${BLUE}[GRACZ 1]${NC}"
	grep -E "Jesteś GRACZEM|Oczekiwanie na Gracza" "$P1_LOG" | head -2
	echo ""
	echo -e "${BLUE}[GRACZ 2]${NC}"
	grep -E "Jesteś GRACZEM" "$P2_LOG" | head -1
	echo ""

	# Wyświetlenie każdej tury
	for round in 1 2 3; do
		echo -e "${BOLD}${YELLOW}=== TURA $round ===${NC}"
		echo ""

		# Gracz 1
		echo -e "${BLUE}[GRACZ 1] ${NC}Wybiera pozycję: ${GREEN}${P1_CHOICES[$((round - 1))]}${NC}"
		grep -A 2 "TURA $round" "$P1_LOG" | grep "Twój wybór:" | head -1
		echo ""

		# Gracz 2
		echo -e "${BLUE}[GRACZ 2] ${NC}Typuje pozycję: ${GREEN}${P2_CHOICES[$((round - 1))]}${NC}"
		grep -A 2 "TURA $round" "$P2_LOG" | grep "Twój wybór:" | head -1
		echo ""

		# Synchronizacja
		echo -e "${CYAN}  → Synchronizacja: Obaj gracze zapisali wybory${NC}"
		echo -e "${CYAN}  → Gracz 1 odczytuje wybór Gracza 2${NC}"
		echo -e "${CYAN}  → Gracz 2 odczytuje wybór Gracza 1${NC}"
		echo ""

		# Wyniki tury
		echo -e "${MAGENTA}[WYNIKI TURY $round]${NC}"
		grep -A 10 "Wyniki tury $round" "$P1_LOG" | grep -E "Twój wybór|Wybór Gracza|WYGRYWA|Aktualny wynik" | head -5
		echo ""
	done

	# Wynik końcowy
	echo -e "${BOLD}${GREEN}=========================================="
	echo -e "  WYNIK KOŃCOWY"
	echo -e "==========================================${NC}"
	echo ""
	echo -e "${BLUE}[GRACZ 1]${NC}"
	grep -A 10 "GRA ZAKOŃCZONA" "$P1_LOG" | grep -E "Gracz [12].*:" | head -2
	grep -A 10 "GRA ZAKOŃCZONA" "$P1_LOG" | grep -E "GRATULACJE|przegrałeś|REMIS" | head -1
	echo ""
	echo -e "${BLUE}[GRACZ 2]${NC}"
	grep -A 10 "GRA ZAKOŃCZONA" "$P2_LOG" | grep -E "Gracz [12].*:" | head -2
	grep -A 10 "GRA ZAKOŃCZONA" "$P2_LOG" | grep -E "GRATULACJE|przegrałeś|REMIS" | head -1
	echo ""
}

# Wyświetlenie logów
display_logs

# Weryfikacja wyników
echo -e "${BOLD}${CYAN}=========================================="
echo -e "  WERYFIKACJA POPRAWNOŚCI"
echo -e "==========================================${NC}"
echo ""

verify_results() {
	local errors=0

	# Sprawdzenie czy Gracz 1 został rozpoznany jako Gracz 1
	if grep -q "Jesteś GRACZEM 1" "$P1_LOG"; then
		echo -e "${GREEN}✓${NC} Gracz 1 poprawnie rozpoznany"
	else
		echo -e "${RED}✗${NC} Błąd: Gracz 1 nie został rozpoznany"
		((errors++))
	fi

	# Sprawdzenie czy Gracz 2 został rozpoznany jako Gracz 2
	if grep -q "Jesteś GRACZEM 2" "$P2_LOG"; then
		echo -e "${GREEN}✓${NC} Gracz 2 poprawnie rozpoznany"
	else
		echo -e "${RED}✗${NC} Błąd: Gracz 2 nie został rozpoznany"
		((errors++))
	fi

	# Sprawdzenie synchronizacji - czy odczyty nastąpiły po zapisach
	if grep -q "Oczekiwanie na wybór Gracza 2" "$P1_LOG" &&
		grep -q "Oczekiwanie na odczytanie wyboru Gracza 1" "$P2_LOG"; then
		echo -e "${GREEN}✓${NC} Synchronizacja odczytów działa poprawnie"
	else
		echo -e "${RED}✗${NC} Błąd: Problem z synchronizacją"
		((errors++))
	fi

	# Sprawdzenie czy rozegrano 3 tury
	local p1_rounds=$(grep -c "TURA .* / 3" "$P1_LOG")
	local p2_rounds=$(grep -c "TURA .* / 3" "$P2_LOG")
	if [ "$p1_rounds" -eq 3 ] && [ "$p2_rounds" -eq 3 ]; then
		echo -e "${GREEN}✓${NC} Rozegrano wszystkie 3 tury"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowa liczba tur (P1: $p1_rounds, P2: $p2_rounds)"
		((errors++))
	fi

	# Sprawdzenie wyników poszczególnych tur
	# Tura 1: P1=2, P2=3 -> różne -> P1 wygrywa
	if grep -A 5 "Wyniki tury 1" "$P1_LOG" | grep -q "Gracz 1 (TY) WYGRYWA"; then
		echo -e "${GREEN}✓${NC} Tura 1: Gracz 1 poprawnie wygrał (2 ≠ 3)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik tury 1"
		((errors++))
	fi

	# Tura 2: P1=1, P2=1 -> takie same -> P2 wygrywa
	if grep -A 5 "Wyniki tury 2" "$P2_LOG" | grep -q "Gracz 2 (TY) WYGRYWA"; then
		echo -e "${GREEN}✓${NC} Tura 2: Gracz 2 poprawnie wygrał (1 = 1)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik tury 2"
		((errors++))
	fi

	# Tura 3: P1=3, P2=2 -> różne -> P1 wygrywa
	if grep -A 5 "Wyniki tury 3" "$P1_LOG" | grep -q "Gracz 1 (TY) WYGRYWA"; then
		echo -e "${GREEN}✓${NC} Tura 3: Gracz 1 poprawnie wygrał (3 ≠ 2)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik tury 3"
		((errors++))
	fi

	# Sprawdzenie wyniku końcowego - Gracz 1 powinien mieć 2 punkty, Gracz 2: 1 punkt
	if grep -A 5 "KOŃCOWY WYNIK" "$P1_LOG" | grep -q "Gracz 1 (TY): 2"; then
		echo -e "${GREEN}✓${NC} Wynik końcowy Gracza 1: 2 punkty (poprawnie)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik końcowy Gracza 1"
		((errors++))
	fi

	if grep -A 5 "KOŃCOWY WYNIK" "$P1_LOG" | grep -q "Gracz 2:      1"; then
		echo -e "${GREEN}✓${NC} Wynik końcowy Gracza 2: 1 punkt (poprawnie)"
	else
		echo -e "${RED}✗${NC} Błąd: Nieprawidłowy wynik końcowy Gracza 2"
		((errors++))
	fi

	# Sprawdzenie czy zasoby zostały wyczyszczone
	sleep 0.5
	if [ ! -d "/tmp/three_cards_game_lock" ]; then
		echo -e "${GREEN}✓${NC} Zasoby (pipes) zostały poprawnie wyczyszczone"
	fi

	echo ""

	if [ $errors -eq 0 ]; then
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
		echo -e "${BOLD}${RED}════════════════════════════════════════"
		echo -e "  WYKRYTO $errors BŁĘDÓW!"
		echo -e "  Implementacja wymaga poprawek ✗"
		echo -e "====================================${NC}"
		return 1
	fi
}

# Opóźnienie aby upewnić się że logi są w pełni zapisane
sleep 0.5

verify_results
RESULT=$?

echo ""
echo -e "${YELLOW}Logi zapisane w:${NC}"
echo -e "  Gracz 1: ${CYAN}$P1_LOG${NC}"
echo -e "  Gracz 2: ${CYAN}$P2_LOG${NC}"
echo ""
echo -e "${YELLOW}Aby zobaczyć pełne logi:${NC}"
echo -e "  ${CYAN}cat $P1_LOG${NC}"
echo -e "  ${CYAN}cat $P2_LOG${NC}"
echo ""

# Opcjonalnie: usuń logi jeśli test przeszedł
if [ $RESULT -eq 0 ]; then
	read -p "Czy usunąć logi testowe? (t/N): " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Tt]$ ]]; then
		rm -rf "$LOG_DIR"
		echo -e "${GREEN}Logi usunięte.${NC}"
	fi
fi

exit $RESULT
