#!/bin/bash

if [ $# -ne 1 ]; then
	echo "Użycie: $0 <nazwa_kraju>"
	exit 1
fi

QUEUE_IN="/tmp/geo_queue_in"
QUEUE_OUT_MY="/tmp/geo_queue_out_$$"
COUNTRY="$1"
MY_PID=$$
NUM_REQUESTS=2

mkfifo "$QUEUE_OUT_MY"
trap "rm -f $QUEUE_OUT_MY" EXIT

if [ ! -p "$QUEUE_IN" ]; then
	echo "[KLIENT] Błąd: Kolejka wejściowa nie istnieje. Czy serwer działa?"
	exit 1
fi

echo "[KLIENT PID=$MY_PID] Rozpoczynam wysyłanie $NUM_REQUESTS zapytań..."

# Proces odbierający w tle
(
	for i in $(seq 1 $NUM_REQUESTS); do
		if read -r capital <"$QUEUE_OUT_MY"; then
			echo "[KLIENT PID=$MY_PID] Odpowiedź #$i: $capital"
		fi
	done
) &
RECEIVER_PID=$!

sleep 0.2

# Wysyłanie zapytań
for i in $(seq 1 $NUM_REQUESTS); do
	echo "$MY_PID:$COUNTRY" >"$QUEUE_IN"
	echo "[KLIENT PID=$MY_PID] Wysłano zapytanie #$i: $COUNTRY"
	sleep 1
done

echo "[KLIENT PID=$MY_PID] Wszystkie zapytania wysłane, czekam na odpowiedzi..."

wait $RECEIVER_PID

echo "[KLIENT PID=$MY_PID] Zakończono"
