CLIENT_NAME="CLIENT"
LOG_NAME="[$CLIENT_NAME]"
LOG_ERROR="[ERROR]"
LOG_WARN="[WARN]"
SERVER_BUFFER="server_buffer.txt"
SERVER_PID_FILE="server.pid"
LOCKFILE_DIR="server.lock"
END_MARKER="<<<END>>>"
CLIENT_RESPONSE_FILE="client_$$_response.txt"

cleanup() {
	echo "$LOG_NAME stopping and cleaning up..."
	rm -f "$CLIENT_RESPONSE_FILE"
	if [ -d "$LOCKFILE_DIR" ]; then
		rmdir "$LOCKFILE_DIR" 2>/dev/null
	fi

	exit 0
}

trap cleanup SIGINT SIGTERM EXIT

echo "$LOG_NAME client running (PID: $$)"
if [ ! -f "$SERVER_PID_FILE" ]; then
	echo "$LOG_ERROR server is not running. Consider starting it first..."
	exit 1
fi

SERVER_PID=$(cat "$SERVER_PID_FILE")
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
	echo "$LOG_ERROR server is not responding (PID: $SERVER_PID doesn't exist)"
	exit 1
fi

if [ -f "$CLIENT_RESPONSE_FILE" ]; then
	echo "$LOG_ERROR response file $CLIENT_RESPONSE_FILE already exists."
	echo "$LOG_ERROR a client with this PID is already running, or the previous one encountered an error during shutdown"
	exit 1
fi

echo "Your message to server (end with empty line): > "
MESSAGE=""
while IFS= read -r line; do
	if [ -z "$line" ]; then
		break
	fi
	if [ -z "$MESSAGE" ]; then
		MESSAGE="$line"
	else
		MESSAGE="$MESSAGE"$'\n'"$line"
	fi
done

if [ -z "$MESSAGE" ]; then
	echo "$LOG_NAME didn't recieve a message to send. Stopping..."
	exit 0
fi

echo "$LOG_NAME trying to connect to the server..."
ATTEMPTS=0
MAX_ATTEMPTS=60

while ! mkdir "$LOCKFILE_DIR" 2>/dev/null; do
	ATTEMPTS=$((ATTEMPTS + 1))

	if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
		echo "$LOG_ERROR already used up all of the retries, the server might be busy..."
		exit 1
	fi

	echo "$LOG_NAME reconnecting to server, please wait... (attempt - $ATTEMPTS)"
	sleep 2
done

echo "$LOG_NAME connected to server."

{
	echo "$CLIENT_RESPONSE_FILE"
	echo "$MESSAGE"
	echo "$END_MARKER"
} >"$SERVER_BUFFER"

kill -SIGUSR1 "$SERVER_PID"

echo "$LOG_NAME message sent to server..."

WAIT_TIME=0
MAX_WAIT=120

while [ ! -f "$CLIENT_RESPONSE_FILE" ]; do
	sleep 1
	WAIT_TIME=$((WAIT_TIME + 1))

	if [ $WAIT_TIME -ge $MAX_WAIT ]; then
		echo "$LOG_ERROR used up all of the available time while waiting to get a response from the server"
		exit 1
	fi

	if ! kill -0 "$SERVER_PID" 2>/dev/null; then
		echo "$LOG_ERROR server stopped working."
		exit 1
	fi
done

echo "SERVER RESPONSE:"
sed "/$END_MARKER/d" "$CLIENT_RESPONSE_FILE"

echo "$LOG_NAME communication has been successfull. Closing..."
