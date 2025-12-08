#!/usr/bin/env python3
"""
Program implementuje dwa podejścia:
1. Wersja podstawowa: 2 wątki
2. Wersja rozszerzona: konfigurowalna liczba wątków
"""

import threading
import time
from typing import List, Optional


def zlicz_w_fragmencie(lista: List[int], start: int, end: int, N: int) -> List[int]:
    """
    Zlicza wystąpienia liczb w fragmencie listy [start:end].

    Args:
        lista: Lista wejściowa z liczbami
        start: Indeks początkowy fragmentu
        end: Indeks końcowy fragmentu (exclusive)
        N: Maksymalna wartość liczb + 1 (rozmiar tablicy liczników)

    Returns:
        Lista liczników dla danego fragmentu
    """
    liczniki = [0] * N
    for i in range(start, end):
        liczniki[lista[i]] += 1
    return liczniki


def polacz_liczniki(liczniki_list: List[Optional[List[int]]]) -> List[int]:
    """
    Łączy listę liczników w jedną wynikową listę.

    Args:
        liczniki_list: Lista list liczników do połączenia

    Returns:
        Połączona lista liczników
    """
    # Filtruj None
    liczniki_niepuste = [l for l in liczniki_list if l is not None]

    if not liczniki_niepuste:
        return []

    N = len(liczniki_niepuste[0])
    wynik = [0] * N

    for liczniki in liczniki_niepuste:
        for i in range(N):
            wynik[i] += liczniki[i]

    return wynik


# ===== WERSJA 1: DWA WĄTKI (5 PUNKTÓW) =====


def zlicz_dwa_watki(lista: List[int], N: int) -> List[int]:
    """
    Tworzy listę liczników używając dwóch wątków.
    Każdy wątek przetwarza połowę listy.

    Args:
        lista: Lista wejściowa z liczbami 0..N-1
        N: Maksymalna wartość liczb + 1

    Returns:
        Lista liczników licz[i] = ilość wystąpień liczby i
    """
    dlugosc = len(lista)
    polowa = dlugosc // 2

    # Listy do przechowania wyników z każdego wątku
    wyniki: List[Optional[List[int]]] = [None, None]

    def watek_1():
        """Przetwarza pierwszą połowę listy"""
        wyniki[0] = zlicz_w_fragmencie(lista, 0, polowa, N)

    def watek_2():
        """Przetwarza drugą połowę listy"""
        wyniki[1] = zlicz_w_fragmencie(lista, polowa, dlugosc, N)

    # Tworzenie i uruchamianie wątków
    t1 = threading.Thread(target=watek_1)
    t2 = threading.Thread(target=watek_2)

    t1.start()
    t2.start()

    # Czekanie na zakończenie wątków
    t1.join()
    t2.join()

    # Łączenie wyników z obu wątków
    return polacz_liczniki(wyniki)


# ===== WERSJA 2: WIELE WĄTKÓW (10 PUNKTÓW) =====


def zlicz_wiele_watkow(lista: List[int], N: int, liczba_watkow: int) -> List[int]:
    """
    Tworzy listę liczników używając zadanej liczby wątków.
    Lista jest dzielona na równe fragmenty (z uwzględnieniem reszty).

    Args:
        lista: Lista wejściowa z liczbami 0..N-1
        N: Maksymalna wartość liczb + 1
        liczba_watkow: Liczba wątków do użycia

    Returns:
        Lista liczników licz[i] = ilość wystąpień liczby i
    """
    if liczba_watkow < 1:
        raise ValueError("Liczba wątków musi być >= 1")

    dlugosc = len(lista)

    # Jeśli lista jest krótsza niż liczba wątków, użyj mniej wątków
    liczba_watkow = min(liczba_watkow, dlugosc)

    if liczba_watkow == 0:
        return [0] * N

    # Oblicz rozmiar fragmentu dla każdego wątku
    rozmiar_fragmentu = dlugosc // liczba_watkow
    reszta = dlugosc % liczba_watkow

    # Lista do przechowania wyników z każdego wątku
    wyniki: List[Optional[List[int]]] = [None] * liczba_watkow
    watki = []

    def utworz_funkcje_watku(indeks_watku):
        """Tworzy funkcję dla konkretnego wątku z jego zakresem danych"""
        # Oblicz zakres dla tego wątku
        start = indeks_watku * rozmiar_fragmentu + min(indeks_watku, reszta)

        if indeks_watku < reszta:
            end = start + rozmiar_fragmentu + 1
        else:
            end = start + rozmiar_fragmentu

        def funkcja_watku():
            wyniki[indeks_watku] = zlicz_w_fragmencie(lista, start, end, N)

        return funkcja_watku

    # Tworzenie i uruchamianie wątków
    for i in range(liczba_watkow):
        watek = threading.Thread(target=utworz_funkcje_watku(i))
        watki.append(watek)
        watek.start()

    # Czekanie na zakończenie wszystkich wątków
    for watek in watki:
        watek.join()

    # Łączenie wyników ze wszystkich wątków
    return polacz_liczniki(wyniki)


# ===== WERSJA 3: REKURENCYJNA Z WIELOMA WĄTKAMI (BONUS) =====


def zlicz_rekurencyjnie(
    lista: List[int], N: int, max_watkow: int, start: int = 0, end: Optional[int] = None
) -> List[int]:
    """
    Rekurencyjna wersja zliczania z podziałem na wątki.

    Rekurencyjnie dzieli listę na pół, aż osiągnie minimalny rozmiar fragmentu
    lub wyczerpie dostępne wątki.

    Args:
        lista: Lista wejściowa z liczbami 0..N-1
        N: Maksymalna wartość liczb + 1
        max_watkow: Maksymalna liczba wątków do użycia w tym wywołaniu
        start: Indeks początkowy fragmentu
        end: Indeks końcowy fragmentu (exclusive)

    Returns:
        Lista liczników dla danego fragmentu
    """
    if end is None:
        end = len(lista)

    dlugosc = end - start

    # Warunek bazowy: mały fragment lub brak dostępnych wątków
    if dlugosc < 2 or max_watkow <= 1:
        return zlicz_w_fragmencie(lista, start, end, N)

    # Podziel fragment na dwie części
    srodek = start + dlugosc // 2
    polowa_watkow = max_watkow // 2

    wyniki: List[Optional[List[int]]] = [None, None]

    def lewa_polowa():
        wyniki[0] = zlicz_rekurencyjnie(lista, N, polowa_watkow, start, srodek)

    def prawa_polowa():
        wyniki[1] = zlicz_rekurencyjnie(lista, N, polowa_watkow, srodek, end)

    # Uruchom dwa wątki dla lewej i prawej połowy
    t1 = threading.Thread(target=lewa_polowa)
    t2 = threading.Thread(target=prawa_polowa)

    t1.start()
    t2.start()

    t1.join()
    t2.join()

    # Połącz wyniki
    return polacz_liczniki(wyniki)


# ===== FUNKCJA TESTUJĄCA =====


def test_zliczanie():
    """Testuje wszystkie implementacje zliczania"""
    print("=" * 60)
    print("TEST ZLICZANIA WYSTĄPIEŃ LICZB")
    print("=" * 60)

    # Test 1: Przykład z zadania
    print("\n--- Test 1: Przykład z zadania ---")
    N = 3
    L = [2, 0, 1, 2, 1, 1, 1]
    print(f"N = {N}")
    print(f"L = {L}")

    wynik_2 = zlicz_dwa_watki(L, N)
    print(f"\nWynik (2 wątki): {wynik_2}")
    print(f"  licz[0] = {wynik_2[0]} (oczekiwano: 1)")
    print(f"  licz[1] = {wynik_2[1]} (oczekiwano: 4)")
    print(f"  licz[2] = {wynik_2[2]} (oczekiwano: 2)")

    # Test 2: Większa lista
    print("\n--- Test 2: Większa lista ---")
    import random

    random.seed(42)
    N = 10
    L = [random.randint(0, N - 1) for _ in range(100)]
    print(f"N = {N}")
    print(f"Długość listy: {len(L)}")

    # Zliczanie sekwencyjne (referencyjne)
    oczekiwane = [0] * N
    for x in L:
        oczekiwane[x] += 1

    print(f"\nOczekiwane: {oczekiwane}")

    wynik_2 = zlicz_dwa_watki(L, N)
    print(f"2 wątki:     {wynik_2}")
    print(f"Poprawne: {wynik_2 == oczekiwane}")

    wynik_4 = zlicz_wiele_watkow(L, N, 4)
    print(f"4 wątki:     {wynik_4}")
    print(f"Poprawne: {wynik_4 == oczekiwane}")

    wynik_8 = zlicz_wiele_watkow(L, N, 8)
    print(f"8 wątków:    {wynik_8}")
    print(f"Poprawne: {wynik_8 == oczekiwane}")

    wynik_rek = zlicz_rekurencyjnie(L, N, 8)
    print(f"Rekurencja:  {wynik_rek}")
    print(f"Poprawne: {wynik_rek == oczekiwane}")

    # Test 3: Bardzo duża lista (test wydajności)
    print("\n--- Test 3: Bardzo duża lista (pomiar czasu) ---")
    N = 20
    rozmiar = 10_000_000
    print(f"N = {N}")
    print(f"Rozmiar listy: {rozmiar:,}")

    random.seed(42)
    L = [random.randint(0, N - 1) for _ in range(rozmiar)]

    # Sekwencyjnie
    start_time = time.time()
    oczekiwane = [0] * N
    for x in L:
        oczekiwane[x] += 1
    czas_sekwencyjny = time.time() - start_time
    print(f"\nSekwencyjnie: {czas_sekwencyjny:.4f}s")

    # 2 wątki
    start_time = time.time()
    wynik_2 = zlicz_dwa_watki(L, N)
    czas_2 = time.time() - start_time
    print(f"2 wątki:      {czas_2:.4f}s (poprawne: {wynik_2 == oczekiwane})")

    # 4 wątki
    start_time = time.time()
    wynik_4 = zlicz_wiele_watkow(L, N, 4)
    czas_4 = time.time() - start_time
    print(f"4 wątki:      {czas_4:.4f}s (poprawne: {wynik_4 == oczekiwane})")

    # 8 wątków
    start_time = time.time()
    wynik_8 = zlicz_wiele_watkow(L, N, 8)
    czas_8 = time.time() - start_time
    print(f"8 wątków:     {czas_8:.4f}s (poprawne: {wynik_8 == oczekiwane})")

    print("\n" + "=" * 60)
    print("=" * 60)


if __name__ == "__main__":
    test_zliczanie()
