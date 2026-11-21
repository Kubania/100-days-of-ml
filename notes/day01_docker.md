# Day 01 — Docker: Containerised Dev Environment

## What Docker solves

Code depends on a whole stack, and uv only controls part of it:

```
Your code                                      ← git
Python packages                                ← uv
Python itself                                  ← uv
System libraries (libomp, CUDA, openssl, gcc)  ← Docker
Operating system (Windows vs Mac vs Linux)     ← Docker
─────────────────────────────────────────────
OS kernel / hardware                           ← shared with host
```

Without Docker, the bottom layers are *whatever happens to be on each machine*, which is where
"works on my machine" bugs come from. Docker puts every layer above the kernel in a file.

**uv guarantees the packages are the same; Docker guarantees the whole machine is the same.**

## Key terms

| Term           | Meaning                                                      | Analogy           |
|----------------|--------------------------------------------------------------|-------------------|
| **Dockerfile** | Text instructions for building an environment                | Recipe            |
| **Image**      | Built, frozen snapshot: OS + Python + packages + code        | Frozen meal       |
| **Container**  | A running instance of an image; many can run from one image  | Meal on the plate |
| **Layer**      | Each Dockerfile step produces a cached layer                 |                   |
| **Tag**        | A name/version for an image, e.g. `ml-100-days:capstone1-v3` |                   |

## Why it matters for ML

1. **ML libraries need system libraries.** XGBoost/LightGBM need OpenMP, PyTorch needs
   CUDA/cuDNN, OpenCV needs image libraries. They are not Python packages, so uv can't install
   them; a Dockerfile can.
2. **ML runs on Linux.** Cloud GPUs, Kaggle/Colab, CI and production servers are Linux.
   Docker gives a real Linux environment on a Windows laptop, so problems surface early.
3. **Deployment.** SageMaker, Vertex AI, Azure ML, Kubernetes, Cloud Run and Hugging Face
   Spaces all run containers. If you can write a Dockerfile, you can deploy a model.
4. **Full experiment reproducibility.** A lockfile reproduces packages; a tagged image
   reproduces the *entire* training environment months later.
5. **Moving between machines.** Prototype on a laptop, train on a GPU machine: same image, no
   reinstalling.
6. **Disposable workspace.** Containers start clean; experiments never pollute the host.

## `.dockerignore`

Like `.gitignore`, but for what gets copied into the image:

```
.venv/
.git/
__pycache__/
project_description/
```

`.venv` is excluded because it's a **Windows** venv and the container is **Linux**. The
container builds its own from `uv.lock`.

## The Dockerfile

```dockerfile
# Start from an official image that already has Linux + Python 3.12 + uv
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# All following commands run inside /app in the container
WORKDIR /app

# Copy ONLY the dependency files first...
COPY pyproject.toml uv.lock .python-version ./

# ...and install dependencies (but not your own code yet)
RUN uv sync --frozen --no-install-project

# Now copy the rest of your code and install the project itself
COPY . .
RUN uv sync --frozen

# What runs when the container starts
CMD ["uv", "run", "ml-100-days"]
```

| Instruction | What it does                                                    |
|-------------|-----------------------------------------------------------------|
| `FROM`      | Base image to build on                                          |
| `WORKDIR`   | Sets (and creates) the working directory inside the container   |
| `COPY`      | Copies files from your machine into the image                   |
| `RUN`       | Runs a command at **build** time; result is saved as a layer    |
| `CMD`       | Default command when a container **starts**                     |

### Layer caching: why dependencies are copied first

Docker caches each step and only rebuilds from the first step whose inputs changed.
Dependencies change rarely; code changes constantly. Copying `pyproject.toml`/`uv.lock`
*before* the code means editing code reuses the cached package install (`CACHED` in the
build output) and rebuilds take seconds, not minutes.

`--frozen` installs exactly what's in `uv.lock` and never updates it.
`--no-install-project` installs the dependencies but not my own package (its code isn't
copied yet at that point).

## Commands

```powershell
docker build -t ml-100-days .              # build image from Dockerfile in this folder, name it
docker run --rm ml-100-days                # run it; --rm deletes the container afterwards
docker run --rm -it ml-100-days bash       # interactive Linux shell inside the container
docker images                              # list images
docker ps -a                               # list containers (running and stopped)
docker image prune                         # remove unused (dangling) images
```

Inside the container shell: `python --version`, `uv pip list`, `ls`, then `exit`.

## Gotchas

- **`failed to connect to the docker API ... dockerDesktopLinuxEngine`**: Docker Desktop isn't
  running. Start it and wait for "Engine running".
- **Don't copy `.venv` into the image**: Windows venvs don't work on Linux; use `.dockerignore`.
- **Order matters**: putting `COPY . .` before the dependency install breaks caching, so every
  code edit reinstalls all packages.

## How Docker fits with uv, git and GitHub

| Tool   | Guarantees                                |
|--------|-------------------------------------------|
| uv     | Same Python packages and Python version   |
| git    | Traceable history of what changed and why |
| Docker | Same whole environment on any machine     |
| GitHub | Work is visible and shareable             |
