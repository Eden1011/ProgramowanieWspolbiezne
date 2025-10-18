#!/bin/bash

SERVER_NAME="SERVER"
LOG_NAME="[$SERVER_NAME]"
LOG_ERROR="[ERROR]"
LOG_WARN="[WARN]"
SERVER_BUFFER="server_buffer.txt"
SERVER_PID_FILE="server.pid"
LOCKFILE_DIR="server.lock"
END_MARKER="<<<END>>>"

cleanup() {
	echo "$LOG_NAME preparing to cleanup..."
	if [ -d "$LOCKFILE_DIR" ]; then
		rmdir "$LOCKFILE_DIR" 2>/dev/null
	fi
	rm -f "$SERVER_BUFFER"
	rm -f "$SERVER_PID_FILE"
	echo "$LOG_NAME stopped..."
	exit 0
}

trap cleanup SIGINT SIGTERM EXIT

if [ -f "$SERVER_PID_FILE" ]; then
	OLD_PID=$(cat "$SERVER_PID_FILE")
	if kill -0 "$OLD_PID" 2>/dev/null; then
		echo "$LOG_ERROR Server already exists (PID: $OLD_PID)"
		exit 1
	else
		echo "$LOG_WARN Found old server pid file, deleting..."
		rm -f "$SERVER_PID_FILE"
	fi
fi

echo $$ >"$SERVER_PID_FILE"

echo "$LOG_NAME working (PID: $$)"
echo "$LOG_NAME awaiting signals from clients"
echo "$LOG_NAME press CTRL+C to stop and run cleanup"

NEW_DATA=0

handle_sigusr1() {
	NEW_DATA=1
}

trap handle_sigusr1 SIGUSR1

while true; do
	if [ $NEW_DATA -eq 1 ]; then
		NEW_DATA=0
		if [ -f "$SERVER_BUFFER" ] && [ -s "$SERVER_BUFFER" ]; then
			echo "$LOG_NAME recieved new client signal"
			CLIENT_FILE=$(head -n 1 "$SERVER_BUFFER")
			echo "CLIENT RESPONSE:"
			tail -n +2 "$SERVER_BUFFER" | sed "/$END_MARKER/d"
			echo -n "$LOG_NAME your response to client (end with empty line): > "
			RESPONSE=""
			while IFS= read -r line; do
				if [ -z "$line" ]; then
					break
				fi
				if [ -z "$RESPONSE" ]; then
					RESPONSE="$line"
				else
					RESPONSE="$RESPONSE"$'\n'"$line"
				fi
			done
			{
				echo "$RESPONSE"
				echo "$END_MARKER"
			} >"$CLIENT_FILE"

			echo "$LOG_NAME sent response to: $CLIENT_FILE" >"$SERVER_BUFFER"
			if [ -d "$LOCKFILE_DIR" ]; then
				rmdir "$LOCKFILE_DIR" 2>/dev/null
				echo "$LOG_NAME lockfile deleted"
			fi
			echo "$LOG_NAME awaiting new signals"
		fi
	fi
	sleep 1
done
