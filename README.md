# Algorithm Design Sandbox

This standalone Python workspace hosts the FEC algorithm experiments that used to
live under `scripts/` in the main Ringmaster tree. Treat it as an independent
project dedicated to rapid prototyping, without impacting the C++ codebase.

## Quickstart

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python matrix/matrix_test.py
```

## Project Layout

- `matrix/` – finite-field helpers and the end-to-end cyclic-shift test harness.
- `encoder.py` – WIP packetization/FEC pipeline using mocked video frames.
- `mock_data_frame.py` – reproducible byte-stream generator for encoder tests.
- `framework.md` – mermaid diagram capturing the algorithmic data flow.
- `AGENTS.md` – contributor guide focused on this sandbox.

Add new research utilities alongside these modules and keep reusable helpers
inside the `matrix/` package so they can be shared across entry points.
