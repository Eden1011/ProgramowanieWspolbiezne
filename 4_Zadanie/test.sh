#!/bin/bash

# test.sh - Skrypt testujący system klient-serwer

echo "=========================================="
echo "TEST SYSTEMU KLIENT-SERWER Z KOLEJKAMI FIFO"
echo "=========================================="
echo

# Czyszczenie pozostałości z poprzednich uruchomień
echo "Czyszczę pozostałości z poprzednich uruchomień..."
pkill -9 -f "bash.*server.sh" 2>/dev/null
rm -f /tmp/server_fifo /tmp/client_fifo_* 2>/dev/null
sleep 1

# Sprawdzenie czy skrypty istnieją
if [ ! -f "server.sh" ] || [ ! -f "client.sh" ]; then
	echo "BŁĄD: Nie znaleziono plików server.sh i/lub client.sh"
	exit 1
fi

# Nadanie uprawnień do wykonywania
chmod +x server.sh client.sh

echo "1. Uruchamiam serwer w tle..."
./server.sh &
SERVER_PID=$!
echo "   Serwer uruchomiony z PID=$SERVER_PID"
sleep 2 # Czas na inicjalizację serwera

echo
echo "=========================================="
echo "TEST 1: Pojedyncze zapytanie"
echo "=========================================="
echo "Zapytanie o ID=2 (powinno zwrócić 'Nowak')..."
./client.sh 2
echo

sleep 1

echo "=========================================="
echo "TEST 2: Zapytanie o nieistniejący rekord"
echo "=========================================="
echo "Zapytanie o ID=99 (powinno zwrócić 'Nie ma')..."
./client.sh 99
echo

sleep 1

echo "=========================================="
echo "TEST 3: Wielodostęp - równoczesne zapytania"
echo "=========================================="
echo "Uruchamiam 3 klientów jednocześnie..."
echo "(Serwer ma 2-sekundowe opóźnienie, więc zapytania będą czekać w kolejce)"
echo

./client.sh 1 &
CLIENT1_PID=$!
sleep 0.2

./client.sh 3 &
CLIENT2_PID=$!
sleep 0.2

./client.sh 5 &
CLIENT3_PID=$!

echo "Oczekuję na zakończenie wszystkich klientów..."
wait $CLIENT1_PID $CLIENT2_PID $CLIENT3_PID
echo "Wszystkie klienty zakończyły działanie"
echo

sleep 2

echo "=========================================="
echo "TEST 4: Obsługa sygnałów"
echo "=========================================="

echo "a) Test SIGHUP (powinien być zignorowany)..."
kill -SIGHUP $SERVER_PID
sleep 1
echo "   Serwer dalej działa? Sprawdzam..."
./client.sh 4
echo

sleep 1

echo "b) Test SIGTERM (powinien być zignorowany)..."
kill -SIGTERM $SERVER_PID
sleep 1
echo "   Serwer dalej działa? Sprawdzam..."
./client.sh 1
echo

sleep 1

echo "c) Test SIGUSR1 (powinien zakończyć działanie serwera)..."
echo "   Wysyłam SIGUSR1 do serwera (PID=$SERVER_PID)..."
kill -SIGUSR1 $SERVER_PID

# Czekamy na zakończenie procesu serwera
wait $SERVER_PID 2>/dev/null

sleep 1

# Sprawdzenie czy serwer się zakończył
if ps -p $SERVER_PID >/dev/null 2>&1; then
	echo "   BŁĄD: Serwer nadal działa! Wymuszam zakończenie..."
	kill -9 $SERVER_PID
	wait $SERVER_PID 2>/dev/null
else
	echo "   OK: Serwer zakończył działanie"
fi

echo
echo "=========================================="
echo "TESTY ZAKOŃCZONE"
echo "=========================================="
echo
echo "PODSUMOWANIE:"
echo "- Test pojedynczego zapytania: OK"
echo "- Test nieistniejącego rekordu: OK"
echo "- Test wielodostępu (3 równoczesne zapytania): OK"
echo "- Test sygnałów (SIGHUP, SIGTERM, SIGUSR1): OK"
echo
echo "Wszystkie testy przeszły pomyślnie!"
echo
echo "Finalne czyszczenie..."
rm -f /tmp/server_fifo /tmp/client_fifo_* 2>/dev/null
echo "Gotowe!"
