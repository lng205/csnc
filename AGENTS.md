# Repository Guidelines

## Sandbox Layout & Responsibilities
The `algo/` workspace holds forward-error-correction research utilities outside the C++ pipeline. `encoder.py` sketches packetization using the `Matrix` abstraction, `mock_data_frame.py` emits reproducible frame payloads, and `matrix/` packages finite-field helpers (`vandermonde.py`, `cyc_matrix.py`, `helper_matrix.py`) plus the pipeline test bench `matrix_test.py`. `framework.md` illustrates the processing flow. Add new experiments alongside these modules and keep reusable math in `matrix/` so it can be imported from multiple entry points.

## Environment Setup
Target Python 3.10+. Create an isolated environment inside `algo/` before running any script:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
Update `requirements.txt` whenever you introduce new dependencies, and document OS quirks (e.g., needing a C compiler for `galois`).

## Development Commands
Run commands from the `algo/` directory so relative imports resolve:
- `python matrix/matrix_test.py` – exercises the bitwise cyclic FEC pipeline.
- `python mock_data_frame.py` – inspects bitrate variability for simulated video frames.
- `python encoder.py` – integrates the mock frames with the Matrix-based encoder.
Use deterministic RNG seeds (see `matrix_test.py`) when sharing output, and redirect verbose matrices to log files when needed (`python matrix/matrix_test.py > dump.txt`).

## Coding Style & Naming Conventions
Follow PEP 8 with four-space indents, `snake_case` for functions/constants, and `CamelCase` for classes such as `Matrix` or `CyclicMatrix`. Keep modules importable (e.g., maintain `matrix/__init__.py`) and annotate public APIs with type hints. Favor short docstrings over inline comments unless a transformation is especially subtle.

## Validation & Extension Guidelines
`matrix_test.py` is both a regression harness and documentation; augment it with assert-based checks when you extend the algorithm. If you add new drivers, expose their core logic as pure functions so they can be unit-tested without network I/O. Capture significant scenarios in `framework.md` or a dedicated design note within `algo/` and keep sample datasets outside the repository, linking to public sources instead.

## Commit & Review Process
Mirror the concise, imperative commit subjects already in the repo (e.g., `refine matrix pipeline`). Group Python-only changes per commit and confirm `python matrix/matrix_test.py` passes before sending a PR. Summaries should describe intent, list validation commands, and include representative metrics or logs. Surface any security-sensitive findings following the guidance in `../SECURITY.md`.
