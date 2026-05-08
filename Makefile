IMAGE       := agentbox
CONFIG_BASE := $(HOME)/.agentbox
COMPOSE     := $(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Agent to run: pi (default) or opencode
AGENT       ?= pi

# Set SNAPSHOT=0 to disable automatic session branching
SNAPSHOT    ?= 1

# Number of old image builds to keep (ring buffer)
KEEP        ?= 3

.PHONY: build run shell clean images help _mkdirs

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-10s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables (override with make <target> VAR=value):"
	@echo "  AGENT      Agent to run: pi (default) or opencode"
	@echo "  SNAPSHOT   Create a session branch before starting: 1 (default) or 0"
	@echo "  KEEP       Number of image builds to keep: 3 (default)"
	@echo ""
	@echo "Project directories are configured in compose.yml under volumes."

build: ## Build the Docker image (keeps last KEEP builds)
	DOCKER_BUILDKIT=1 docker build --no-cache --pull -t $(IMAGE):latest -t $(IMAGE):$(shell date -u +%Y%m%d-%H%M%S) .
	@docker images $(IMAGE) --format '{{.Tag}}' \
		| grep -v latest \
		| sort -r \
		| tail -n +$$(($(KEEP) + 1)) \
		| while IFS= read -r tag; do echo "Pruning $(IMAGE):$$tag"; docker rmi "$(IMAGE):$$tag" > /dev/null; done

images: ## List available image builds
	@docker images $(IMAGE) --format 'table {{.Tag}}\t{{.Size}}\t{{.CreatedAt}}' | grep -v latest | sort -r

run: _mkdirs ## Run the agent (AGENT=pi|opencode, SNAPSHOT=0 to skip branching)
	@AGENT=$(AGENT) SNAPSHOT=$(SNAPSHOT) DIRNAME=$(notdir $(PWD)) $(COMPOSE) run --rm agentbox

shell: _mkdirs ## Drop into a zsh shell without starting an agent
	@AGENT=$(AGENT) DIRNAME=$(notdir $(PWD)) $(COMPOSE) run --rm --entrypoint zsh agentbox

clean: ## Remove all agentbox images and stopped containers
	@$(COMPOSE) rm -f 2>/dev/null || true
	@docker images $(IMAGE) --format '{{.ID}}' \
		| while IFS= read -r id; do \
			docker ps -aq --filter "ancestor=$$id" \
			| while IFS= read -r cid; do docker rm -f "$$cid" 2>/dev/null || true; done; \
		  done
	@docker images $(IMAGE) --format '{{.Tag}}' \
		| while IFS= read -r tag; do docker rmi "$(IMAGE):$$tag" 2>/dev/null || true; done
	@echo "Removed all $(IMAGE) images and stopped containers"

_mkdirs:
	@mkdir -p \
		"$(CONFIG_BASE)/pi" \
		"$(CONFIG_BASE)/opencode/config" \
		"$(CONFIG_BASE)/opencode/local"
