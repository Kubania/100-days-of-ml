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
