#!/usr/bin/env python3

import threading
import time
from threading import Barrier, Lock

# Parametry
l = 2
r = 20
liczba_watkow = 4

# Wspólna lista liczb pierwszych (wymaga synchronizacji)
pierwsze = []
# Lock do wzajemnego wykluczania przy dodawaniu do listy
lock = Lock()


def pierwsza(k):
    """Sprawdzenie, czy k jest liczbą pierwszą"""
    if k < 2:
        return False
    if k == 2:
        return True
    if k % 2 == 0:
        return False

    for i in range(3, k, 2):
        if i * i > k:
            return True
        if k % i == 0:
            return False
    return True


def szukaj_pierwszych(poczatek, koniec, barrier, id_watku):
    """
    Funkcja wątku szukająca liczb pierwszych w swoim podprzedziale.

    Args:
        poczatek: początek podprzedziału
        koniec: koniec podprzedziału (włącznie)
        barrier: bariera synchronizacyjna
        id_watku: identyfikator wątku (do logowania)
    """
    print(
        f"Wątek {id_watku}: rozpoczynam przeszukiwanie zakresu [{poczatek}, {koniec}]"
    )

    # Lista lokalna dla tego wątku
    lokalne_pierwsze = []

    # Szukanie liczb pierwszych w przydzielonym podprzedziale
    for i in range(poczatek, koniec + 1):
        if pierwsza(i):
            lokalne_pierwsze.append(i)

    # Sekcja krytyczna - dodawanie do wspólnej listy (wzajemne wykluczanie)
    with lock:
        pierwsze.extend(lokalne_pierwsze)
        print(
            f"Wątek {id_watku}: znalazłem {len(lokalne_pierwsze)} liczb pierwszych: {lokalne_pierwsze}"
        )

    # Sygnalizacja zakończenia obliczeń przez wątek
    print(f"Wątek {id_watku}: czekam na barierze...")
    barrier.wait()
    print(f"Wątek {id_watku}: przeszedłem przez barierę!")


def main():
    """Główna funkcja programu"""
    print(f"=== Wyszukiwanie liczb pierwszych w zakresie [{l}, {r}] ===")
    print(f"Liczba wątków: {liczba_watkow}\n")

    # Obliczenie rozmiaru przedziału na wątek
    zakres = r - l + 1
    rozmiar_podprzedzialu = zakres // liczba_watkow

    # Utworzenie bariery - liczba uczestników to liczba wątków + 1 (wątek główny)
    barrier = Barrier(liczba_watkow + 1)

    # Lista wątków
    watki = []

    # Tworzenie i uruchamianie wątków
    for i in range(liczba_watkow):
        # Obliczenie granic podprzedziału dla tego wątku
        poczatek = l + i * rozmiar_podprzedzialu

        # Ostatni wątek obejmuje pozostałą część (uwzględnia resztę z dzielenia)
        if i == liczba_watkow - 1:
            koniec = r
        else:
            koniec = poczatek + rozmiar_podprzedzialu - 1

        # Utworzenie i uruchomienie wątku
        watek = threading.Thread(
            target=szukaj_pierwszych, args=(poczatek, koniec, barrier, i)
        )
        watki.append(watek)
        watek.start()

    # Wątek główny czeka na barierze, aby zsynchronizować się z wszystkimi wątkami
    print("Wątek główny: czekam na wszystkie wątki na barierze...\n")
    start_time = time.time()
    barrier.wait()
    end_time = time.time()

    print("\n=== Wszystkie wątki zakończyły obliczenia! ===")
    print(f"Czas wykonania: {end_time - start_time:.4f} sekund")

    # Opcjonalnie: join() aby upewnić się, że wszystkie wątki zakończyły się
    for watek in watki:
        watek.join()

    # Sortowanie wyniku (wątki mogły dodawać liczby w różnej kolejności)
    pierwsze.sort()

    print(f"\nZnalezione liczby pierwsze: {pierwsze}")
    print(f"Liczba znalezionych liczb pierwszych: {len(pierwsze)}")


if __name__ == "__main__":
    main()
