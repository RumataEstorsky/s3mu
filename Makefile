REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DOCKER_COMPOSE ?= docker-compose -f $(REPO_ROOT)/docker-compose.yml

.PHONY: help docker-up docker-down docker-logs docker-reset stat install deps docdeps format format-check compile test it-test run clean quality ci

help: ## List available targets
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort -u | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'



docker-reset: ## Reset Docker environment (stop, remove volumes, clean)
	$(DOCKER_COMPOSE) down -v --remove-orphans
	@docker system prune -f --volumes >/dev/null 2>&1 || true

stat: ## Count total Scala lines of code
	@s=$$(find $(REPO_ROOT)src $(REPO_ROOT)integration -name "*.scala" -not -path "*/target/*" -not -path "*/.bsp/*" | xargs cat 2>/dev/null | wc -l | tr -d ' '); \
	 echo "Scala: $$s lines"

install: ## Install required tools (openjdk, sbt, colima, regclient)
	brew install openjdk sbt colima regclient

deps: ## Check for dependency updates
	sbt dependencyUpdates

docdeps: ## Check for Docker image updates in docker-compose.yml
	@command -v regctl >/dev/null 2>&1 || { echo "Install regctl: brew install regclient"; exit 1; }
	@echo "Checking Docker image versions..."
	@grep -E '^\s+image:' $(REPO_ROOT)docker-compose.yml | sed 's/.*image:\s*//' | while read img; do \
		name=$$(echo "$$img" | cut -d: -f1); \
		current=$$(echo "$$img" | cut -d: -f2); \
		if [ "$$current" = "latest" ]; then \
			printf "  %-45s %s\n" "$$name" "using :latest (consider pinning)"; \
		else \
			prefix=""; suffix=""; \
			case "$$current" in v*) prefix="v";; esac; \
			case "$$current" in *-alpine) suffix="-alpine";; esac; \
			latest=$$(regctl tag ls "$$name" 2>/dev/null | \
				grep -E "^$${prefix}[0-9]+\.[0-9]+\.[0-9]+$${suffix}$$" | \
				sed 's/^v//' | sed 's/-alpine$$//' | sort -V | tail -1); \
			[ -n "$$latest" ] && latest="$${prefix}$${latest}$${suffix}"; \
			current_num=$$(echo "$$current" | sed 's/^v//' | sed 's/-alpine$$//'); \
			if [ -n "$$latest" ] && [ "$$current" != "$$latest" ]; then \
				latest_num=$$(echo "$$latest" | sed 's/^v//' | sed 's/-alpine$$//'); \
				if [ "$$(printf '%s\n%s' "$$current_num" "$$latest_num" | sort -V | tail -1)" = "$$latest_num" ] && [ "$$current_num" != "$$latest_num" ]; then \
					printf "  %-45s %s → %s\n" "$$name" "$$current" "$$latest"; \
				else \
					printf "  %-45s %s ✓\n" "$$name" "$$current"; \
				fi; \
			else \
				printf "  %-45s %s ✓\n" "$$name" "$$current"; \
			fi; \
		fi; \
	done

format: ## Format all code with scalafmt
	sbt scalafmtAll scalafmtSbt

format-check: ## Check if code is formatted properly
	sbt scalafmtCheckAll scalafmtSbtCheck

compile: ## Compile the project
	sbt compile

test: ## Run unit tests
	sbt test

it-test: ## Run integration tests (requires Colima or Docker)
	DOCKER_HOST=unix:///$$HOME/.colima/default/docker.sock TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock sbt integration/test

run: ## Run the application
	sbt run

clean: ## Clean all build artifacts (target/, .bsp/)
	@find . -type d -name target -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .bsp

quality: format-check compile test ## Run all quality checks (format, compile, test)

ci: format-check compile test ## Run CI pipeline checks

# Scoverage
coverage: ## Run tests with coverage
	sbt clean coverage test

coverage-report: ## Generate coverage report
	sbt coverageReport

coverage-off: ## Reset coverage instrumentation
	sbt coverageOff

coverage-all: coverage coverage-report coverage-off ## Full coverage workflow

# Native Packager
package: ## Create distributable package
	sbt clean stage

docker-build: ## Build Docker image
	sbt docker:publishLocal

docker-run: ## Run Docker image
	docker run --rm -p 8080:8080 my-app:latest

