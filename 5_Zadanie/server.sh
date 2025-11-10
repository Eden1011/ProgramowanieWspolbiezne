#!/bin/bash

QUEUE_IN="/tmp/geo_queue_in"

get_capital() {
	case "$1" in
	"Polska") echo "Warszawa" ;;
	"Niemcy") echo "Berlin" ;;
	"Francja") echo "Paryż" ;;
	"Hiszpania") echo "Madryt" ;;
	"Włochy") echo "Rzym" ;;
	"Anglia") echo "Londyn" ;;
	"USA") echo "Waszyngton" ;;
	"Japonia") echo "Tokio" ;;
	*) echo "Nie wiem" ;;
	esac
}

cleanup() {
	echo ""
	echo "[SERWER] Sprzątam..."
	rm -f "$QUEUE_IN"
	rm -f /tmp/geo_queue_out_*
	# Poczekaj na procesy w tle
	wait
	echo "[SERWER] Zakończono"
	exit 0
}

trap cleanup SIGINT SIGTERM EXIT

rm -f "$QUEUE_IN"
mkfifo "$QUEUE_IN"

echo "[SERWER] Uruchomiony"
echo "[SERWER] Naciśnij Ctrl+C aby zakończyć"

while true; do
	if read -r line <"$QUEUE_IN"; then
		client_pid="${line%%:*}"
		country="${line#*:}"

		if [[ "$country" == "stop" ]]; then
			echo "[SERWER] Otrzymano komendę stop"
			cleanup
		fi

		echo "[SERWER] Zapytanie od PID=$client_pid: $country"

		# Przetwarzanie w tle, żeby nie blokować kolejnych zapytań
		(
			sleep 2

			capital=$(get_capital "$country")

			client_queue="/tmp/geo_queue_out_$client_pid"
			if [ -p "$client_queue" ]; then
				# Zapis do FIFO w podprocesie który już jest w tle
				echo "$capital" >"$client_queue"
				echo "[SERWER] Odpowiedź do PID=$client_pid: $capital"
			else
				echo "[SERWER] UWAGA: Kolejka klienta $client_pid nie istnieje"
			fi
		) &
	fi
done
