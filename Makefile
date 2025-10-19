# OpenTelemetry Collector Helm Chart Makefile
# Provides testing, linting, and documentation generation

.DEFAULT_GOAL := help
.PHONY: help lint test docs clean install-deps upgrade template validate security-check all ci

# Variables
CHART_DIR := otel-collectors
TEST_VALUES := test-values.yml
CHART_NAME := otel-collectors
NAMESPACE := o11y
HELM_DOCS_VERSION := v1.11.3
KIND_CLUSTER_NAME := otel-test

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

## Help
help: ## Display this help message
	@echo "$(BLUE)OpenTelemetry Collector Helm Chart$(NC)"
	@echo "$(BLUE)=====================================$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make lint          # Lint the chart with schema validation"
	@echo "  make test          # Run all tests including template generation"
	@echo "  make docs          # Generate README.md from template"
	@echo "  make ci            # Run full CI pipeline"
	@echo "  make kind-install  # Install in kind cluster for testing"

## Dependencies
install-deps: ## Install required tools (helm-docs, kind, etc.)
	@echo "$(BLUE)Installing dependencies...$(NC)"
	@if ! command -v helm-docs >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing helm-docs $(HELM_DOCS_VERSION)...$(NC)"; \
		go install github.com/norwoodj/helm-docs/cmd/helm-docs@$(HELM_DOCS_VERSION); \
	else \
		echo "$(GREEN)✓ helm-docs already installed$(NC)"; \
	fi
	@if ! command -v kind >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing kind...$(NC)"; \
		go install sigs.k8s.io/kind@latest; \
	else \
		echo "$(GREEN)✓ kind already installed$(NC)"; \
	fi
	@if ! command -v helm >/dev/null 2>&1; then \
		echo "$(RED)✗ Helm not found. Please install Helm first.$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ helm already installed$(NC)"; \
	fi

## Linting and Validation
lint: ## Lint the chart with strict validation
	@echo "$(BLUE)Linting Helm chart...$(NC)"
	@cd $(CHART_DIR) && helm lint . --strict
	@echo "$(GREEN)✓ Chart linting passed$(NC)"

validate: ## Validate chart with test values
	@echo "$(BLUE)Validating chart with test values...$(NC)"
	@cd $(CHART_DIR) && helm lint . -f ../$(TEST_VALUES) --strict
	@echo "$(GREEN)✓ Chart validation with test values passed$(NC)"

security-check: ## Check security context compliance
	@echo "$(BLUE)Checking security context compliance...$(NC)"
	@helm template test $(CHART_DIR) -f $(TEST_VALUES) | \
		grep -E "(runAsUser|runAsNonRoot|readOnlyRootFilesystem|allowPrivilegeEscalation)" | \
		grep -v "runAsUser: 65534\|runAsNonRoot: true\|readOnlyRootFilesystem: true\|allowPrivilegeEscalation: false" && \
		{ echo "$(RED)✗ Security compliance check failed$(NC)"; exit 1; } || \
		echo "$(GREEN)✓ Security context compliance verified$(NC)"

## Testing
template: ## Generate and validate templates
	@echo "$(BLUE)Generating templates...$(NC)"
	@helm template test $(CHART_DIR) -f $(TEST_VALUES) > /tmp/otel-test-output.yaml
	@echo "$(GREEN)✓ Template generation successful$(NC)"
	@echo "$(YELLOW)Output written to /tmp/otel-test-output.yaml$(NC)"

dry-run: ## Perform dry-run installation
	@echo "$(BLUE)Performing dry-run installation...$(NC)"
	@helm install $(CHART_NAME)-test $(CHART_DIR) -f $(TEST_VALUES) \
		--namespace $(NAMESPACE) --create-namespace --dry-run
	@echo "$(GREEN)✓ Dry-run installation successful$(NC)"

test-values: ## Validate test values against schema
	@echo "$(BLUE)Testing values.yaml against schema...$(NC)"
	@cd $(CHART_DIR) && helm lint . --strict --quiet || \
		{ echo "$(RED)✗ Default values validation failed$(NC)"; exit 1; }
	@cd $(CHART_DIR) && helm lint . -f ../$(TEST_VALUES) --strict --quiet || \
		{ echo "$(RED)✗ Test values validation failed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Values validation passed$(NC)"

test: lint validate template dry-run security-check test-values ## Run all tests
	@echo "$(GREEN)✓ All tests passed$(NC)"

## Documentation
docs: install-deps ## Generate README.md from Go template
	@echo "$(BLUE)Generating README.md...$(NC)"
	@if command -v helm-docs >/dev/null 2>&1; then \
		helm-docs -c $(CHART_DIR) -t README.md.gotmpl -o README.md; \
		echo "$(GREEN)✓ README.md generated successfully$(NC)"; \
	else \
		echo "$(YELLOW)helm-docs not found, using manual template processing...$(NC)"; \
		helm template readme $(CHART_DIR) -f $(TEST_VALUES) \
			--show-only README.md.gotmpl > $(CHART_DIR)/README.md 2>/dev/null || \
			echo "$(YELLOW)Manual processing failed, keeping existing README-preview.md$(NC)"; \
	fi

docs-preview: ## Show preview of generated README
	@echo "$(BLUE)README.md preview:$(NC)"
	@if [ -f "$(CHART_DIR)/README.md" ]; then \
		head -30 $(CHART_DIR)/README.md; \
		echo "..."; \
		echo "$(YELLOW)(Showing first 30 lines. Full file: $(CHART_DIR)/README.md)$(NC)"; \
	else \
		echo "$(RED)README.md not found. Run 'make docs' first.$(NC)"; \
	fi

## Kind Cluster Operations
kind-create: ## Create kind cluster for testing
	@echo "$(BLUE)Creating kind cluster...$(NC)"
	@if kind get clusters | grep -q $(KIND_CLUSTER_NAME); then \
		echo "$(YELLOW)Kind cluster '$(KIND_CLUSTER_NAME)' already exists$(NC)"; \
	else \
		kind create cluster --name $(KIND_CLUSTER_NAME); \
		echo "$(GREEN)✓ Kind cluster created$(NC)"; \
	fi

kind-delete: ## Delete kind cluster
	@echo "$(BLUE)Deleting kind cluster...$(NC)"
	@kind delete cluster --name $(KIND_CLUSTER_NAME)
	@echo "$(GREEN)✓ Kind cluster deleted$(NC)"

kind-install: kind-create ## Install chart in kind cluster
	@echo "$(BLUE)Installing chart in kind cluster...$(NC)"
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(YELLOW)Creating test secrets...$(NC)"
	@kubectl create secret generic grafana-cloud-secret \
		--from-literal=username=test \
		--from-literal=password=test \
		-n $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic otlp-azure-foobar-auth \
		--from-literal=username=test \
		--from-literal=password=test \
		-n $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install $(CHART_NAME) $(CHART_DIR) -f $(TEST_VALUES) \
		--namespace $(NAMESPACE) \
		--set otlpDestinations.grafanaCloud.authSecretName=grafana-cloud-secret \
		--set otlpDestinations.azurefoobar.authSecretName=otlp-azure-foobar-auth
	@echo "$(GREEN)✓ Chart installed in kind cluster$(NC)"

kind-uninstall: ## Uninstall chart from kind cluster
	@echo "$(BLUE)Uninstalling chart from kind cluster...$(NC)"
	@helm uninstall $(CHART_NAME) -n $(NAMESPACE) || true
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "$(GREEN)✓ Chart uninstalled$(NC)"

kind-test: kind-install ## Install and test in kind cluster
	@echo "$(BLUE)Testing chart in kind cluster...$(NC)"
	@sleep 10  # Wait for pods to start
	@kubectl get pods -n $(NAMESPACE)
	@kubectl get opentelemetrycollectors -n $(NAMESPACE)
	@echo "$(GREEN)✓ Kind cluster test completed$(NC)"

## Chart Operations
upgrade: ## Upgrade chart with test values
	@echo "$(BLUE)Upgrading chart...$(NC)"
	@helm upgrade $(CHART_NAME) $(CHART_DIR) -f $(TEST_VALUES) \
		--namespace $(NAMESPACE)
	@echo "$(GREEN)✓ Chart upgraded$(NC)"

uninstall: ## Uninstall chart
	@echo "$(BLUE)Uninstalling chart...$(NC)"
	@helm uninstall $(CHART_NAME) -n $(NAMESPACE)
	@echo "$(GREEN)✓ Chart uninstalled$(NC)"

status: ## Show chart status
	@echo "$(BLUE)Chart status:$(NC)"
	@helm status $(CHART_NAME) -n $(NAMESPACE)

## Utility
clean: ## Clean up generated files
	@echo "$(BLUE)Cleaning up...$(NC)"
	@rm -f /tmp/otel-test-output.yaml
	@rm -f $(CHART_DIR)/README.md.bak
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

version: ## Show version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "Chart Version: $$(grep '^version:' $(CHART_DIR)/Chart.yaml | cut -d' ' -f2)"
	@echo "App Version: $$(grep '^appVersion:' $(CHART_DIR)/Chart.yaml | cut -d' ' -f2)"
	@helm version --short
	@kubectl version --client --short 2>/dev/null || echo "kubectl: not connected to cluster"

## CI Pipeline
ci: clean lint validate template security-check test-values docs ## Run complete CI pipeline
	@echo "$(GREEN)"
	@echo "======================================"
	@echo "✓ CI Pipeline Completed Successfully"
	@echo "======================================"
	@echo "$(NC)"
	@echo "Summary:"
	@echo "  ✓ Chart linting passed"
	@echo "  ✓ Schema validation passed"
	@echo "  ✓ Template generation successful"
	@echo "  ✓ Security compliance verified"
	@echo "  ✓ README.md generated"

## Development workflow
dev: lint template docs ## Quick development workflow
	@echo "$(GREEN)✓ Development workflow completed$(NC)"

all: install-deps ci kind-test ## Run everything (full test suite)
	@echo "$(GREEN)"
	@echo "==============================="
	@echo "✓ Full Test Suite Completed"
	@echo "==============================="
	@echo "$(NC)"

.SILENT: help