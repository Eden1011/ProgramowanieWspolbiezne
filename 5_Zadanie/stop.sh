#!/bin/bash

QUEUE_IN="/tmp/geo_queue_in"

if [ ! -p "$QUEUE_IN" ]; then
	echo "Błąd: Kolejka nie istnieje. Czy serwer działa?"
	exit 1
fi

# Wyślij komendę stop (PID nie ma znaczenia, ale musi być format PID:komenda)
echo "$$:stop" >"$QUEUE_IN"
echo "Wysłano komendę stop do serwera"
