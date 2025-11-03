#!/bin/bash

# server.sh - Serwer prostej bazy danych z kolejkami FIFO

SERVER_FIFO="/tmp/server_fifo"

# Baza danych - tablica asocjacyjna (ID -> nazwisko)
declare -A DATABASE
DATABASE[1]="Kowalski"
DATABASE[2]="Nowak"
DATABASE[3]="Wiśniewski"
DATABASE[4]="Wójcik"
DATABASE[5]="Kowalczyk"

# Funkcja obsługi sygnału SIGUSR1 - kończy działanie serwera
handle_sigusr1() {
	echo "[SERWER] Otrzymano SIGUSR1 - kończę działanie"
	# Zamykamy deskryptor FIFO
	exec 3<&-
	# Zamykamy FIFO i kończymy proces
	if [ -p "$SERVER_FIFO" ]; then
		rm -f "$SERVER_FIFO"
	fi
	echo "[SERWER] Zakończono przez SIGUSR1"
	exit 0
}

# Funkcja do ignorowania sygnałów SIGHUP i SIGTERM
handle_ignore() {
	echo "[SERWER] Zignorowano sygnał $1"
}

# Ustawienie obsługi sygnałów
trap 'handle_sigusr1' SIGUSR1
trap 'handle_ignore SIGHUP' SIGHUP
trap 'handle_ignore SIGTERM' SIGTERM

# Funkcja czyszcząca przy wyjściu
cleanup() {
	echo "[SERWER] Sprzątam zasoby..."
	# Zamykamy deskryptor jeśli jest otwarty
	exec 3<&- 2>/dev/null
	if [ -p "$SERVER_FIFO" ]; then
		rm -f "$SERVER_FIFO"
	fi
}

trap cleanup EXIT

# Utworzenie kolejki FIFO serwera
if [ -p "$SERVER_FIFO" ]; then
	rm -f "$SERVER_FIFO"
fi

mkfifo "$SERVER_FIFO"
echo "[SERWER] Utworzono kolejkę: $SERVER_FIFO"
echo "[SERWER] PID serwera: $$"
echo "[SERWER] Baza danych zawiera ${#DATABASE[@]} rekordów"
echo "[SERWER] Oczekuję na zapytania..."

# Otwieramy FIFO raz na deskryptorze 3 dla czytania
exec 3<"$SERVER_FIFO"

# Główna pętla serwera
while true; do
	# Czytanie z deskryptora FIFO (blokujące)
	# Używamy timeout aby móc obsługiwać sygnały
	if read -t 1 -r message <&3; then

		echo "[SERWER] Otrzymano zapytanie: $message"

		# Parsowanie komunikatu: długość|ID|ścieżka_kolejki_klienta
		IFS='|' read -r msg_len request_id client_fifo <<<"$message"

		# Walidacja danych
		if [[ -z "$request_id" || -z "$client_fifo" ]]; then
			echo "[SERWER] BŁĄD: Nieprawidłowy format komunikatu"
			continue
		fi

		# Symulacja opóźnienia (dla testowania wielodostępu)
		echo "[SERWER] Przetwarzam zapytanie ID=$request_id..."
		sleep 2

		# Wyszukanie w bazie danych
		if [[ -v "DATABASE[$request_id]" ]]; then
			response="${DATABASE[$request_id]}"
			echo "[SERWER] Znaleziono: $response"
		else
			response="Nie ma"
			echo "[SERWER] Brak rekordu dla ID=$request_id"
		fi

		# Przygotowanie odpowiedzi: długość|odpowiedź
		response_len=${#response}
		full_response="${response_len}|${response}"

		# Wysłanie odpowiedzi do kolejki klienta (atomowo)
		if [ -p "$client_fifo" ]; then
			# Używamy deskryptora pliku dla atomowości
			exec 4>"$client_fifo"
			echo "$full_response" >&4
			exec 4>&-
			echo "[SERWER] Wysłano odpowiedź do $client_fifo"
		else
			echo "[SERWER] BŁĄD: Kolejka klienta $client_fifo nie istnieje"
		fi
	fi
done
