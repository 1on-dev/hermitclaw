FROM python:3.11-slim

# System build tools (good to keep)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency metadata first
COPY pyproject.toml /app/

# Install uv and dependencies (no --frozen, since you don't have uv.lock yet)
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir uv \
    && uv sync --no-dev

# Now copy the rest of the project
COPY . /app

# Basic env; adjust as needed for HermitClaw
ENV PORT=8000
# HERMIT_FOLDER is where *_box/ directories live. Mount a Railway volume here
# so crab identity/memories survive redeploys.
ENV HERMIT_FOLDER=/data/hermit
RUN mkdir -p /data/hermit
VOLUME ["/data/hermit"]

# TODO: replace with the real entrypoint if different
CMD [".venv/bin/python", "-m", "hermitclaw.main"]
