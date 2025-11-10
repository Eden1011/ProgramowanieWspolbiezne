#!/bin/bash

echo "=========================================="
echo "  TEST SERWERA GEOGRAFICZNEGO"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f "server.sh" ] || [ ! -f "client.sh" ] || [ ! -f "stop.sh" ]; then
	echo -e "${RED}Błąd: Nie znaleziono wszystkich wymaganych plików!${NC}"
	exit 1
fi

chmod +x server.sh client.sh stop.sh

echo -e "${BLUE}[TEST]${NC} Czyszczę stare kolejki..."
rm -f /tmp/geo_queue_* 2>/dev/null

echo -e "${GREEN}[TEST]${NC} Uruchamiam serwer..."
./server.sh >server.log 2>&1 &
SERVER_PID=$!
echo -e "${GREEN}[TEST]${NC} Serwer uruchomiony (PID=$SERVER_PID)"

sleep 2

if ! ps -p $SERVER_PID >/dev/null; then
	echo -e "${RED}[TEST]${NC} Błąd: Serwer nie uruchomił się!"
	cat server.log
	exit 1
fi

echo ""
echo "=========================================="
echo "  FAZA 1: Test z dwoma klientami"
echo "=========================================="
echo ""

echo -e "${YELLOW}[TEST]${NC} Uruchamiam Klienta 1 (Polska)..."
./client.sh Polska >client1.log 2>&1 &
CLIENT1_PID=$!

sleep 0.5

echo -e "${YELLOW}[TEST]${NC} Uruchamiam Klienta 2 (Niemcy)..."
./client.sh Niemcy >client2.log 2>&1 &
CLIENT2_PID=$!

echo ""
echo -e "${BLUE}[TEST]${NC} Czekam na zakończenie klientów (max 20 sekund)..."

# Czekaj z timeoutem
timeout=20
elapsed=0
while ps -p $CLIENT1_PID >/dev/null 2>&1 || ps -p $CLIENT2_PID >/dev/null 2>&1; do
	sleep 1
	((elapsed++))
	echo -ne "\r${BLUE}[TEST]${NC} Upłynęło ${elapsed}s..."
	if [ $elapsed -ge $timeout ]; then
		echo ""
		echo -e "${RED}[TEST]${NC} TIMEOUT! Klienci nie zakończyli się w $timeout sekund"
		echo "Killing processes..."
		kill $CLIENT1_PID $CLIENT2_PID 2>/dev/null
		break
	fi
done

echo ""
echo ""

echo "=========================================="
echo "  KLIENT 1 (Polska)"
echo "=========================================="
cat client1.log
echo ""

echo "=========================================="
echo "  KLIENT 2 (Niemcy)"
echo "=========================================="
cat client2.log
echo ""

echo "=========================================="
echo "  FAZA 2: Test pojedynczego klienta"
echo "=========================================="
echo ""

./client.sh Japonia >client3.log 2>&1
cat client3.log
echo ""

echo "=========================================="
echo "  FAZA 3: Test nieznanego kraju"
echo "=========================================="
echo ""

./client.sh Australia >client4.log 2>&1
cat client4.log
echo ""

echo "=========================================="
echo "  FAZA 4: Zatrzymanie serwera"
echo "=========================================="
echo ""

./stop.sh
sleep 2

if ps -p $SERVER_PID >/dev/null 2>&1; then
	echo -e "${RED}[TEST]${NC} Serwer nie zatrzymał się, wymuszam..."
	kill $SERVER_PID 2>/dev/null
	sleep 1
fi

echo ""
echo "=========================================="
echo "  LOG SERWERA"
echo "=========================================="
tail -30 server.log
echo ""

echo "=========================================="
echo "  WERYFIKACJA"
echo "=========================================="
echo ""

if ls /tmp/geo_queue_* 2>/dev/null; then
	echo -e "${RED}[TEST]${NC} Kolejki nie zostały usunięte:"
	ls -la /tmp/geo_queue_*
else
	echo -e "${GREEN}[TEST]${NC} ✓ Wszystkie kolejki usunięte"
fi

if ps -p $SERVER_PID >/dev/null 2>&1; then
	echo -e "${RED}[TEST]${NC} Serwer nadal działa!"
else
	echo -e "${GREEN}[TEST]${NC} ✓ Serwer zatrzymany"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  TEST ZAKOŃCZONY"
echo -e "==========================================${NC}"

read -p "Usunąć logi? (t/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Tt]$ ]]; then
	rm -f server.log client*.log
	echo "Logi usunięte"
fi
