# Build stage
FROM python:3.13.1-slim as builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    DEBIAN_FRONTEND=noninteractive \
    POETRY_VERSION=1.7.1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_CREATE=false

WORKDIR /src

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gettext \
    gcc \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install poetry
RUN curl -sSL https://install.python-poetry.org | python3 - && \
    cd /usr/local/bin && \
    ln -s /opt/poetry/bin/poetry

# Install dependencies
COPY pyproject.toml poetry.lock* ./
RUN poetry install --no-root --no-interaction --no-ansi

# Runtime stage
FROM python:3.13.1-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8

WORKDIR /src

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gettext \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" tgbot_app

# Copy dependencies from builder
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages

# Copy application
COPY ./scripts /src/scripts
RUN chmod +x /src/scripts/*

COPY ./app /src/app

RUN pybabel compile -d /src/app/locales -D messages

RUN mkdir -p /src/logs && \
    chown -R tgbot_app:tgbot_app /src && \
    chmod -R 755 /src && \
    chmod 777 /src/logs

USER tgbot_app

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT ["sh", "/src/scripts/docker-entrypoint.prod.sh"]
