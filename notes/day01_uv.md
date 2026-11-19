# Day 01 — uv: Python Environments & Dependency Management

## What uv is

uv is a single tool that replaces `venv` + `pip` + `pip-tools` + `pyenv`. It creates the
environment, installs packages, locks exact versions and even installs Python itself.
Underneath it still uses a normal venv (`.venv`), it just manages it for you.

| Task                  | venv + pip                              | uv                                        |
|-----------------------|-----------------------------------------|-------------------------------------------|
| Create env            | `python -m venv .venv`, then activate   | `uv sync` (creates `.venv` automatically) |
| Add a package         | `pip install pandas`, then `pip freeze` | `uv add pandas`                           |
| Reproducible versions | `requirements.txt` (often stale)        | `uv.lock` (always in sync)                |
| Python version        | whatever is installed on the machine    | `.python-version`, downloaded if missing  |
| Run code              | activate, then `python x.py`            | `uv run x.py` (no activation needed)      |

## The project files

| File              | Purpose                                                       | Commit to git? |
|-------------------|---------------------------------------------------------------|----------------|
| `pyproject.toml`  | What the project needs: **allowed** version ranges            | Yes            |
| `uv.lock`         | What is **actually installed**: exact versions + hashes of every package, including sub-dependencies | Yes |
| `.python-version` | Which Python the project uses                                 | Yes            |
| `.venv/`          | The environment itself, disposable, rebuilt from the lockfile | **No**         |

Key idea: **`.venv` is disposable, the lockfile is the source of truth.**
Delete `.venv` and run `uv sync`, and you get the identical environment back.

Why both `pyproject.toml` and `uv.lock`? `pyproject.toml` says `pandas>=3.1` (flexibility
for upgrades); `uv.lock` pins `pandas==3.1.x` so a new release can't silently break the
project for a teammate.

## Core commands

```powershell
uv init --name ml-100-days --python 3.12   # create project (pyproject.toml, .python-version)
uv sync                                     # create/update .venv to match uv.lock
uv add numpy pandas scikit-learn            # add runtime dependencies
uv add --dev pytest ruff ipykernel          # add development dependencies
uv remove <package>                         # remove a dependency
uv run python script.py                     # run inside the env (syncs first)
uv python list --only-installed             # Pythons uv can see
```

Undoing `uv init`: there is no undo command, just delete what it created
(`pyproject.toml`, `.python-version`, `README.md`, `main.py` or `src/`, plus `.venv`/`uv.lock`
if you synced). Only delete `.git` if uv created it.

## Updating the lockfile

Anyone can update `uv.lock`, but **only through uv, never by hand**:

| Command                              | Effect                                                   |
|--------------------------------------|----------------------------------------------------------|
| `uv add` / `uv remove`               | Re-resolves the lock for that change                     |
| `uv lock --upgrade-package pandas`   | Bumps only pandas to the newest allowed version          |
| `uv lock --upgrade`                  | Bumps everything to the newest allowed versions          |
| `uv sync` / `uv run`                 | Re-locks only if `pyproject.toml` changed                |
| `uv sync --locked`                   | Fails if lock is out of date (use in CI)                 |
| `uv sync --frozen`                   | Installs exactly the lock, never updates it (use in Docker) |

On a team, lockfile changes go through pull requests so version bumps get reviewed.

## Dependency groups

A **dependency group** is a named list of extra packages needed to *work on* the project,
but not to *run* it. Standardised in PEP 735.

- **Runtime** (`[project] dependencies`): what your code imports: pandas, scikit-learn.
- **Development** (`[dependency-groups] dev`): tools around the code: pytest, ruff, ipykernel.

Analogy: ingredients go in the dish (runtime); knives and chopping boards stay in the
kitchen (dev).

```toml
[dependency-groups]
dev  = ["ruff", "ipykernel"]
test = ["pytest", "pytest-cov"]
```

```powershell
uv add --group test pytest    # --dev is shorthand for --group dev
uv sync                       # runtime + dev (dev is on by default)
uv sync --no-dev              # runtime only (production image)
uv sync --only-group test     # only that group (CI job)
```

Rule of thumb: **if your code imports it, it's a dependency; if only you use it while
developing, it's `--dev`.**

## Gotcha: `VIRTUAL_ENV ... does not match the project environment`

```
warning: `VIRTUAL_ENV=...\portfolio` does not match the project environment path `.venv` and will be ignored
```

Another venv is activated in the terminal. uv ignores it and correctly uses the project's
`.venv`. Fix: run `deactivate`, and in VS Code choose *Python: Select Interpreter* →
`.venv\Scripts\python.exe`. Don't use `--active`, which installs into the *other* env.

## What uv does NOT do

uv reproduces the **Python layer** only. It does not install system libraries, compilers or
drivers (e.g. `libomp` for LightGBM on macOS, the CUDA runtime). Homebrew/apt are still
needed for those, which is one reason to use Docker.

## uv vs Docker

```
┌────────────────────────────────────┐
│  Your code                         │
│  Python packages                   │ ◄── uv
│  Python interpreter                │ ◄── uv
├────────────────────────────────────┤
│  System libraries (libomp, CUDA)   │
│  OS packages, file layout          │ ◄── Docker (and everything above)
│  Env vars, ports, start command    │
├────────────────────────────────────┤
│  OS kernel / hardware              │ ◄── neither (shared with host)
└────────────────────────────────────┘
```

|                       | uv                         | Docker                                 |
|-----------------------|----------------------------|----------------------------------------|
| Isolates              | Python packages & version  | A whole Linux filesystem and processes |
| Runs on               | Your actual OS             | A Linux container on any OS            |
| Non-Python deps       | No                         | Yes                                    |
| Weight                | A folder, instant          | Image of hundreds of MB, needs Docker running |

They are **complementary**: uv decides and locks *which* Python packages; Docker freezes the
*whole machine* around them. In a Dockerfile, `uv sync --frozen` installs exactly the lockfile.

Use uv day to day; use Docker for deployment, system-level dependencies, or when
"works on my machine" must become "works on every machine".
