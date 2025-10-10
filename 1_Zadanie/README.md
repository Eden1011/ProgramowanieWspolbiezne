Utworzyć prostą parę programów klient - serwer, komunikujące się przez dwa pliki

(plik dla danych i plik dla wyników), działając na zasadzie ciągłego odpytywania plików (w pętli aktywnego czekania).

```text
               wczytanie                  zapis/odczyt do plików
|------------| ---------> |--------------| ---> |dane| ----> |--------------|
| użytkownik |            |proces klienta|                   |proces serwera|
|------------| <--------- |--------------| <-- |wyniki| <--- |--------------|
               wyświetlenie               zapis/odczyt do plików
``` 

Klient pobiera z klawiatury i zapisuje do pliku "dane": pojedynczą liczbę całkowitą. 

Serwer pobiera liczbę z pliku, oblicza jakąś prostą funkcję arytmetyczną (np. nieduży wielomian) i wynik zapisuje do pliku "wyniki" . Klient odbiera odpowiedź z pliku, wyświetla i kończy działanie. Serwer działa nadal w pętli oczekując na kolejne zgłoszenia.

UWAGI:

    Dowolny język programowania (Python, C, bash, ...)
    Zakładamy, że tylko jest tylko  jeden klient w czasie każdej komunikacji (pomijamy przypadek wielu klientów działających równocześnie).
     Przetestować kilkukrotne uruchomienie klienta dla tego samego serwera - może pojawić się konieczność opróżniania plików po stronie serwera i po stronie klienta zaraz po odczytaniu wiadomości z pliku.
    Uruchamiać najpierw serwer, a potem dopiero klienta.

WSKAZÓWKA: trzeba znaleźć sposób na sprawdzenie, czy w pliku pojawił się jakiś zapis i w pętli powtarzać to sprawdzenie, może z jakimś drobnym odstępem czasu