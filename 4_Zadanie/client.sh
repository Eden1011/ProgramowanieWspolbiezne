#!/bin/bash

# client.sh - Klient bazy danych

if [ $# -ne 1 ]; then
	echo "Użycie: $0 <ID>"
	echo "Przykład: $0 3"
	exit 1
fi

REQUEST_ID="$1"
SERVER_FIFO="/tmp/server_fifo"
CLIENT_FIFO="/tmp/client_fifo_$$" # Unikalna kolejka dla każdego klienta (PID)

# Funkcja czyszcząca
cleanup() {
	if [ -p "$CLIENT_FIFO" ]; then
		rm -f "$CLIENT_FIFO"
	fi
}

trap cleanup EXIT

# Sprawdzenie czy serwer działa
if [ ! -p "$SERVER_FIFO" ]; then
	echo "[KLIENT] BŁĄD: Serwer nie działa (brak $SERVER_FIFO)"
	exit 1
fi

# Utworzenie kolejki klienta
mkfifo "$CLIENT_FIFO"
echo "[KLIENT] PID: $$, utworzono kolejkę: $CLIENT_FIFO"

# Przygotowanie zapytania: długość|ID|ścieżka_kolejki
query_body="${REQUEST_ID}|${CLIENT_FIFO}"
query_len=${#query_body}
full_query="${query_len}|${query_body}"

echo "[KLIENT] Wysyłam zapytanie o ID=$REQUEST_ID..."

# Wysłanie zapytania do serwera (atomowo przez deskryptor pliku)
# Otwieramy FIFO, piszemy i zamykamy w jednej operacji
exec 3>"$SERVER_FIFO"
echo "$full_query" >&3
exec 3>&-

echo "[KLIENT] Oczekuję na odpowiedź..."

# Oczekiwanie na odpowiedź (blokujące z timeout)
if read -t 10 -r response <"$CLIENT_FIFO"; then
	# Parsowanie odpowiedzi: długość|treść
	IFS='|' read -r resp_len resp_data <<<"$response"

	echo "[KLIENT] Otrzymano odpowiedź: $resp_data"

	if [ "$resp_data" = "Nie ma" ]; then
		echo "[KLIENT] Rekord o ID=$REQUEST_ID nie istnieje w bazie"
		exit 1
	else
		echo "[KLIENT] Nazwisko dla ID=$REQUEST_ID: $resp_data"
		exit 0
	fi
else
	echo "[KLIENT] BŁĄD: Timeout - brak odpowiedzi od serwera"
	exit 1
fi
