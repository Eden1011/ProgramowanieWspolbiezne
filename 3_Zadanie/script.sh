#!/bin/bash
if [ $# -ne 2 ]; then
	echo "Użycie: $0 <plik_startowy> <szukane_słowo>"
	exit 1
fi
PLIK="$1"
SLOWO="$2"
if [ ! -f "$PLIK" ]; then
	echo "Błąd: Plik '$PLIK' nie istnieje"
	exit 1
fi
przetworz_plik() {
	local plik="$1"
	local slowo="$2"
	local licznik_lokalny=0
	local licznik_dzieci=0
	if [ ! -f "$plik" ]; then
		exit 0
	fi
	licznik_lokalny=$(grep -o -w "$slowo" "$plik" 2>/dev/null | wc -l)
	declare -a pids
	declare -a tempfiles
	while IFS= read -r linia; do
		if [[ "$linia" =~ \\input\{([^}]+)\} ]]; then
			plik_input="${BASH_REMATCH[1]}"
			tempfile=$(mktemp)
			tempfiles+=("$tempfile")
			(
				licznik_dziecka=$(przetworz_plik "$plik_input" "$slowo")
				echo "$licznik_dziecka" >"$tempfile"
				exit $((licznik_dziecka % 256))
			) &
			pids+=($!)
		fi
	done < <(grep -o '\\input{[^}]*}' "$plik" 2>/dev/null)
	for i in "${!pids[@]}"; do
		pid="${pids[$i]}"
		tempfile="${tempfiles[$i]}"
		wait "$pid"
		exit_code=$?
		if [ -f "$tempfile" ]; then
			wynik=$(cat "$tempfile")
			if [[ "$wynik" =~ ^[0-9]+$ ]]; then
				licznik_dzieci=$((licznik_dzieci + wynik))
			fi
			rm -f "$tempfile"
		fi
	done
	local suma=$((licznik_lokalny + licznik_dzieci))
	echo "$suma"
}
wynik=$(przetworz_plik "$PLIK" "$SLOWO")
echo "Słowo '$SLOWO' wystąpiło $wynik razy w pliku '$PLIK' i wszystkich dołączonych plikach."
exit $((wynik % 256))
echo "Słowo '$SLOWO' wystąpiło łącznie $wynik razy"
echo "w pliku '$PLIK' i wszystkich dołączonych plikach."
echo
exit $((wynik % 256))
