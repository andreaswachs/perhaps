# Perhaps Development Makefile
# ============================
#
# Quick reference:
#   make dev        - Start full containerized development with hot reloading
#   make deps       - Start only database and Redis (run Rails natively)
#   make down       - Stop all services
#   make logs       - View container logs
#   make console    - Open Rails console in container
#   make shell      - Open bash shell in web container

COMPOSE_FILE := compose.dev.yml

.PHONY: help dev deps down logs rebuild console shell test lint db-migrate db-reset clean

# Default target
help:
	@echo "Perhaps Development Commands"
	@echo "============================"
	@echo ""
	@echo "Docker Development:"
	@echo "  make dev          Start full stack with hot reloading"
	@echo "  make deps         Start only PostgreSQL and Redis"
	@echo "  make down         Stop all services"
	@echo "  make logs         View container logs (follow mode)"
	@echo "  make rebuild      Rebuild and start containers (after Gemfile changes)"
	@echo ""
	@echo "Container Access:"
	@echo "  make console      Open Rails console in web container"
	@echo "  make shell        Open bash shell in web container"
	@echo "  make worker-shell Open bash shell in worker container"
	@echo ""
	@echo "Database:"
	@echo "  make db-migrate   Run database migrations"
	@echo "  make db-reset     Reset database (drop, create, migrate, seed)"
	@echo ""
	@echo "Testing & Linting (in container):"
	@echo "  make test         Run all tests"
	@echo "  make lint         Run rubocop and erb_lint"
	@echo "  make security     Run brakeman security scan"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean        Stop containers and remove volumes"

# Start full containerized development with hot reloading
dev:
	docker compose -f $(COMPOSE_FILE) --profile full up

# Start only dependencies (PostgreSQL and Redis)
deps:
	docker compose -f $(COMPOSE_FILE) up -d

# Stop all services
down:
	docker compose -f $(COMPOSE_FILE) --profile full down

# View logs
logs:
	docker compose -f $(COMPOSE_FILE) --profile full logs -f

# Rebuild containers (use after Gemfile changes)
rebuild:
	docker compose -f $(COMPOSE_FILE) --profile full up --build

# Open Rails console
console:
	docker compose -f $(COMPOSE_FILE) exec web bin/rails console

# Open shell in web container
shell:
	docker compose -f $(COMPOSE_FILE) exec web bash

# Open shell in worker container
worker-shell:
	docker compose -f $(COMPOSE_FILE) exec worker bash

# Run database migrations
db-migrate:
	docker compose -f $(COMPOSE_FILE) exec web bin/rails db:migrate

# Reset database
db-reset:
	docker compose -f $(COMPOSE_FILE) exec web bin/rails db:reset

# Run tests
test:
	docker compose -f $(COMPOSE_FILE) exec web bin/rails test

# Run linting
lint:
	docker compose -f $(COMPOSE_FILE) exec web bin/rubocop -a
	docker compose -f $(COMPOSE_FILE) exec web bundle exec erb_lint ./app/**/*.erb -a

# Run security scan
security:
	docker compose -f $(COMPOSE_FILE) exec web bin/brakeman --no-pager

# Stop containers and remove volumes
clean:
	docker compose -f $(COMPOSE_FILE) --profile full down -v
