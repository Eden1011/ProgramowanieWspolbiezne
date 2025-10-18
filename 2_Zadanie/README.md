Pliki blokujące (zamkowe), komunikacja przez pliki.

Napisać parę programów klient-serwer składającą się na prosty komunikator tekstowy, działający zgodnie z poniższym opisem. (Do zrozumienia tego opisu pomocny może być następujący szkic.)

Serwer działa w pętli nieskończonej, klient tylko jednorazowo (pytanie - odpowiedź). Program klienta otrzymuje nazwę pliku z danymi wejściowymi dla serwera (na rysunku nazywa się to "bufor serwera") jako parametr wywołania lub ustala to konwersacyjnie lub po prostu wpisany jest na sztywno w kod (tylko nazwa pliku, jeżeli klienta i serwera uruchamiamy w tym samym katalogu, w przeciwnym razie trzeba podać całą ścieżkę do pliku). Serwer jest jeden, klientów może być wielu, działających równocześnie, np. z różnych okien.

Klient wstawia do bufora serwera:

nazwę swojego pliku (ewentualnie całą ścieżkę) do którego ma być przesłana odpowiedź (każdy klient ma swój osobny plik). Ta nazwa może być np. ustalana konwersacyjnie bądź parametrem wywołania klienta.

kolejne linie swojego tekstu wprowadzonego przez użytkownika (dowolnie dużo linii);

jakiś znacznik końca tekstu (np. kod znaku Esc).

Serwer (działający w innym oknie) czyta z pliku "bufor serwera" i wyświetla cały tekst klienta w swoim oknie. Następnie pobiera odpowiedź od użytkownika siedzącego przy oknie serwera i wstawia ją do pliku, którego nazwę otrzymał w pierwszej linii komunikatu od klienta. Wstawiony tekst kończy jakimś znacznikiem końca tekstu.

Dostęp do bufora serwera powinien być synchronizowany plikiem zamkowym (lockfile) tworzonym przez klienta w katalogu roboczym serwera. Jeżeli serwer czasowo nie jest dostępny, klient wyświetla w pętli co kilka sekund informację: "Serwer zajęty, proszę czekać". Po udzieleniu odpowiedzi serwer utworzony przez klienta plik lockfile powinien być usunięty

UWAGI

Żeby przetestować sytuację, że serwer może być zajęty, należy utworzyć dwóch klientów: jeden wysyła do serwera dane, a drugi, jeszcze przed odpowiedzią serwera do pierwszego też próbuje się skomunikować z serwerem.

Niedopuszczalnym błędem jest rozdzielenie operacji sprawdzenie czy plik zamkowy istnieje i utworzenie go. Poprawne niepodzielnie wykonanie tych operacji jest opisane we wskazówkach poniżej.

WSKAZÓWKI dotyczące używania plików zamkowych (plików blokujących, lockfile)

konstrukcja w C umożliwiająca wykonanie niepodzielnej operacji utworzenia pliku zamkowego pod warunkiem, że go nie ma:

while (open("ścieżka_dostępu/lockfile",O_CREAT|O_EXCL,0)==-1) {
printf("Serwer zajety, prosze czekac\n");
sleep( ... );
}
rozwiązania Pythonowe omawiane na wykładzie:

przykład z wykładu, wykład o plikach blokujących
