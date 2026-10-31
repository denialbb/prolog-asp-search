# Linee Guida di Sviluppo e Standard di Progetto

Documento interno per lo sviluppo del progetto e criteri di qualità del codice da consegnare per la valutazione d'esame.

---

## 1. Standard di Codice e Commenti

- **Stile dichiarativo e modulare**:
  - Prolog: separare chiaramente il motore di ricerca agnostico (`prolog/search/`) dalla logica dei domini (`prolog/domains/`). Predicati con clausole concise, uso corretto del cut verde, denominazione standard in italiano/inglese coerente.
  - ASP (Clingo): struttura formale `generate-test-optimize`, minimi accoppiamenti e vincoli espliciti.
- **Commenti descrittivi e non storici**:
  - Documentare la semantica dei predicati (argomenti, modalità `+`, `-`, `?`) e la razionale teorica delle euristiche (ammissibilità, consistenza).
  - **Vietati commenti storici o cronologie modifiche nel codice sorgente** (es. "risolto bug con... ", "modificato da...", "tentativo precedente commentato"). Il versionamento spetta unicamente alla cronologia Git.
  - Rimuovere blocchi di codice non utilizzati.

---

## 2. Test-Driven Development (TDD) e Complessità Ciclomatica

- **Flusso Red-Green**:
  - Definire casi di test preliminari in `tests/` per domini, euristiche e vincoli di torneo.
  - Validare il passaggio da test in stato *failing* (Red) a *passing* (Green) man mano che i moduli algoritmici vengono integrati.
- **Complessità Ciclomatica**:
  - Mantenere la complessità logica di ciascun componente entro limiti stringenti (complessità per funzione $\le 10$).
  - I test automatici (`tests/test_complexity.py` via `radon` e `flake8`) verificano che il codice di supporto e benchmark rispetti la soglia massima $B$.

---

## 3. Automazione CI (GitHub Actions)

La pipeline CI (`.github/workflows/ci.yml`) viene eseguita ad ogni commit su `main`:
1. Esecuzione dei test unitari Prolog con `plunit` su SWI-Prolog (`swipl -g run_tests -t halt ...`).
2. Verifica vincoli ASP con Clingo via suite `pytest`.
3. Validazione della complessità ciclomatica e linting sintattico con `radon` e `flake8`.

Per eseguire localmente prima del push:
```bash
swipl -g run_tests -t halt tests/test_labyrinth.pl
swipl -g run_tests -t halt tests/test_puzzle8.pl
pytest -v tests/
radon cc -s -a -nb tests/
```

---

## 4. Integrità della Consegna Accademica

Il codice sorgente e la relazione/slide saranno esaminati dai docenti:
- Assenza assoluta di marcatori, boilerplate o pattern riconducibili a generatori automatici o intelligenze artificiali.
- Struttura dei commit pulita, atomica e descrittiva con convenzione standard (`feat:`, `fix:`, `test:`, `docs:`).
- Documentazione e commenti redatti con rigore accademico e piena padronanza concettuale degli algoritmi.
