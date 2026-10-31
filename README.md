# prolog-asp-search — State-Space Search & Tournament Scheduler

Progetto d'esame di **Intelligenza Artificiale e Laboratorio** (a.a. 2025–2026), parte *Programmazione Logica e Answer Set Programming* (Prof. Pozzato).

Il repository include le due attività richieste dalle specifiche di progetto:
1. **Prolog**: implementazione e analisi comparativa di **A\*** e **IDA\*** in due domini (Labirinto con uscite multiple e Puzzle dell'8).
2. **ASP (Clingo)**: generatore di calendari per tornei di Lega Pokémon con arrivi dinamici, gestione del BYE e massimizzazione degli spareggi a parità di punteggio.

---

## 1. Attività 1: Ricerca nello Spazio degli Stati in Prolog

Confronto sperimentale tra **A\*** e **IDA\*** (Iterative Deepening A\*) eseguito sugli stessi casi di test.

### Domini
- **Labirinto**: griglia con ostacoli, cella iniziale e almeno 2 uscite (non necessariamente tutte raggiungibili). Euristiche: distanza di Manhattan/Euclidea verso l'uscita più vicina.
- **Puzzle dell'8**: griglia 3×3 con 8 tessere numerate e cella vuota, con obiettivo ordinato. Euristiche: numero di tessere fuori posto (misplaced tiles), somma delle distanze di Manhattan, opzionali Pattern Databases (PDB).

### Metriche di confronto
- Nodi espansi / generati
- Tempo di esecuzione (CPU time)
- Consumo di memoria / profondità frontiera
- Costo e lunghezza del cammino trovato

*Riferimento implementativo precedente*: [`denialbb/labyrinth`](https://github.com/denialbb/labyrinth).

---

## 2. Attività 2: Answer Set Programming con Clingo (Lega Pokémon)

Generazione incrementale del turno di un torneo per $n$ partecipanti a partire da:
- Elenco partecipanti (giocatori già presenti + nuovi iscritti al turno)
- Storico degli incontri già disputati
- Classifica parziale attuale

### Vincoli
- **Partecipanti dispari**: esattamente un partecipante ottiene il **BYE** (+1 vittoria automatica per il turno).
- **BYE univoco**: nessun giocatore può ricevere il BYE più di una volta nell'intero torneo.
- **Unicità scontri**: due giocatori si possono affrontare al massimo una volta.
- **Nessun ritiro**: i giocatori che entrano restano attivi per i turni successivi.

### Ottimizzazione
- Prediligere incontri tra giocatori con il medesimo punteggio in classifica (**massimizzare gli spareggi**, es. minimizzazione della differenza di punti tra avversari accoppiati via `#minimize`).

*Riferimento implementativo precedente*: [`denialbb/academic-calendar-solver`](https://github.com/denialbb/academic-calendar-solver).

---

## 3. Struttura del Progetto

```
prolog-asp-search/
├── prolog/
│   ├── search/               # A* e IDA* (motori di ricerca agnostici)
│   ├── domains/
│   │   ├── labyrinth/        # Definizione stato, mosse, euristiche e mappe
│   │   └── puzzle8/          # Definizione stato 3x3, mosse e euristiche
│   └── benchmarks/           # Suite di test automatizzati per confronto metriche
├── asp/
│   ├── tournament.lp         # Modello logico Clingo (generate-test-optimize)
│   └── instances/            # Casi di test (es. turni progressivi con nuovi ingressi)
└── docs/                     # Slide e analisi per presentazione (~10 min)
```

---

## 4. Setup & Esecuzione

### Prolog (SWI-Prolog)
```bash
swipl
?- [prolog/search/a_star].
?- [prolog/domains/labyrinth/labyrinth].
?- solve_labyrinth(AStarPath, Stats).
```

### Clingo (ASP)
```bash
clingo asp/tournament.lp asp/instances/round1.lp --opt-mode=optN
```

---

## 5. Deliverable d'Esame

- Codice sorgente completo e commentato per entrambe le attività.
- Presentazione (~10 min) con slide illustrative su scelte architetturali, euristiche adottate e analisi critica tabellare delle prove sperimentali.
