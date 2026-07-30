# Single entry point for every workflow. CI runs these exact targets — see
# .github/workflows/ci.yml, where every step is a `make` invocation — so a green
# `make ci` locally means a green pipeline. Package lists live here and nowhere
# else.
#
# This was not always true. The workflow used to inline its own `for pkg in ...`
# loops, and they drifted: `core/core_ui` was added to CODEGEN_PACKAGES here but
# not there, so CI stopped generating `core_ui/lib/di.module.dart` while the
# barrel kept exporting it. Duplicating a list is how the duplicate goes stale.

# Overridable, because CI installs the SDK directly rather than through FVM and
# still has to run these same targets: the workflow sets FLUTTER=flutter and
# DART=dart in the job environment. Locally the FVM-pinned SDK is the default
# and nobody has to think about it.
FLUTTER ?= fvm flutter
DART    ?= fvm dart

# Paths, because packages are grouped by kind. Keep in sync with the root
# pubspec's `workspace:` list — `make check-deps` fails if one drifts.
PACKAGES := core/core_kit core/core_storage core/core_network core/core_arch core/core_ui \
            mini_apps/mini_app_contract features/feature_auth app

# Packages that run build_runner, and packages that have tests. Both lists are
# checked against the source tree by `make check-deps`: a package that carries
# an injectable/json/retrofit annotation must appear in CODEGEN_PACKAGES, and a
# package with a `*_test.dart` must appear in TEST_PACKAGES. Editing one of
# these by hand without the other change is caught rather than shipped.
CODEGEN_PACKAGES := core/core_storage core/core_network core/core_ui features/feature_auth app
TEST_PACKAGES := core/core_kit core/core_storage core/core_network core/core_arch core/core_ui \
                 mini_apps/mini_app_contract features/feature_auth app

FLAVOR ?= dev
DEFINES = --dart-define-from-file=env_config/$(FLAVOR)/dart_defines.json

.DEFAULT_GOAL := help
.PHONY: help setup sdk env get hooks codegen codegen-watch l10n analyze fmt fmt-check test test-coverage \
        check-deps check-artifacts check-props ci clean rebuild dev stg prod apk aab ipa rename doctor

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- Setup -------------------------------------------------------------------

setup: sdk env get l10n codegen hooks ## First-time setup on a fresh clone
	@echo "✓ Workspace ready. Run 'make dev', or use the VS Code launch configs."

hooks: ## Point git at the tracked hooks in .githooks/
	@# core.hooksPath rather than copying into .git/hooks: a copy is a snapshot
	@# that never updates when the hook changes, so half the team ends up running
	@# a version nobody can see in the diff.
	@git config core.hooksPath .githooks
	@chmod +x .githooks/*
	@echo "✓ git hooks active (bypass a run with 'git push --no-verify')"

sdk: ## Materialise the FVM SDK symlink pinned in .fvmrc
	@# .fvm/ is gitignored, so a fresh clone has no SDK and VS Code's
	@# dart.flutterSdkPath (.fvm/flutter_sdk) is a dangling symlink until this runs.
	@fvm install
	@fvm use --force >/dev/null

env: ## Create env_config/*/dart_defines.json from the tracked samples
	@# The real files are gitignored because they carry per-project URLs and
	@# keys. Without this the VS Code launch configs fail on a missing file,
	@# which is a confusing first experience on a new clone.
	@for flavor in dev stg prod; do \
		target=app/env_config/$$flavor/dart_defines.json; \
		if [ -f "$$target" ]; then \
			echo "· $$target exists, leaving it alone"; \
		else \
			cp app/env_config/$$flavor/dart_defines.sample.json "$$target"; \
			echo "· created $$target"; \
		fi; \
	done

get: ## Resolve dependencies for the whole workspace
	$(FLUTTER) pub get

l10n: ## Regenerate core_ui localizations from the ARB files
	cd core/core_ui && $(FLUTTER) gen-l10n

codegen: ## Run build_runner in every package that needs it
	@for pkg in $(CODEGEN_PACKAGES); do \
		echo "→ codegen $$pkg"; \
		(cd $$pkg && $(DART) run build_runner build --delete-conflicting-outputs) || exit 1; \
	done

codegen-watch: ## Watch mode for the package in PKG=... (default: app)
	cd $(or $(PKG),app) && $(DART) run build_runner watch --delete-conflicting-outputs

# --- Quality -----------------------------------------------------------------

analyze: ## Static analysis across the workspace
	$(FLUTTER) analyze

# Hand-written sources only. `dart format` does not honour the analyzer's
# exclude list, so pointing it at whole directories also reformats generated
# files — and since the generators emit their own style, fmt-check would then
# fail on a clean checkout every time codegen runs.
DART_SOURCES = $(shell find $(addsuffix /lib,$(PACKAGES)) $(addsuffix /test,$(PACKAGES)) tools \
	-name '*.dart' ! -name '*.g.dart' ! -name '*.config.dart' ! -name '*.module.dart' \
	! -path '*/generated/*' 2>/dev/null)

fmt: ## Format hand-written Dart (page width 120)
	@$(DART) format --page-width=120 $(DART_SOURCES)

fmt-check: ## Verify formatting without writing — this is what CI runs
	@$(DART) format --page-width=120 --output=none --set-exit-if-changed $(DART_SOURCES)

test: ## Run tests — all packages, or one with PKG=core/core_storage
	@# PKG takes a path, the same string TEST_PACKAGES uses, so a name copied out
	@# of a failing run can be pasted straight back in. Extra arguments go through
	@# ARGS, e.g. `make test PKG=app ARGS="--name 'boots'"`.
	@for pkg in $(or $(PKG),$(TEST_PACKAGES)); do \
		echo "→ test $$pkg"; \
		(cd $$pkg && $(FLUTTER) test $(ARGS)) || exit 1; \
	done

test-coverage: ## Run tests with coverage and print a summary
	@for pkg in $(TEST_PACKAGES); do \
		(cd $$pkg && $(FLUTTER) test --coverage) || exit 1; \
	done
	@$(DART) run tools/coverage_summary.dart

check-deps: ## Fail if any package imports across a forbidden layer boundary
	@$(DART) run tools/check_dependencies.dart

# Regexes rather than `git check-ignore`, because .gitignore is exactly what
# does not help here: it applies only to files git is not already tracking, so
# anything added before its rule existed stays tracked forever and no amount of
# ignoring removes it. 102MB of .dart_tool/, build/, coverage/ and a whole FVM
# SDK reached this repo that way, along with ten generated files that rule 9
# says are never committed and three env files the ignore list calls secrets.
# This target is what makes that removal stick.
ARTIFACT_PATTERN := ^\.dart_tool/|^\.fvm/|(^|/)build/|(^|/)coverage/|\.g\.dart$$|\.config\.dart$$|\.module\.dart$$|l10n/generated/|env_config/.*/dart_defines\.json$$

check-props: ## Fail if an Equatable class omits a field from props
	@# Rule 13's teeth. A field outside `props` is invisible to `==`, so
	@# BlocSelector and buildWhen never rebuild for it — the state is right, the
	@# widget is right, and the screen simply does not update. Deliberate
	@# exclusions live in `allowedOmissions` with their reason.
	@$(DART) run tools/check_equatable_props.dart

check-artifacts: ## Fail if build output, generated code or env files are tracked by git
	@tracked=$$(git ls-files | grep -E '$(ARTIFACT_PATTERN)' || true); \
	if [ -n "$$tracked" ]; then \
		echo "✗ build output or generated code is tracked by git:"; \
		echo "$$tracked" | sed 's/^/    /'; \
		echo ""; \
		echo "  Untrack it (this keeps the files on disk):"; \
		echo "    git rm -r --cached <path>"; \
		exit 1; \
	fi
	@echo "✓ no build output, generated code or env files tracked"

ci: get l10n codegen fmt-check analyze test check-deps check-props check-artifacts ## The full quality gate
	@echo "✓ CI checks passed."

clean: ## Remove build outputs, generated code and the build_runner caches
	$(FLUTTER) clean
	@find . -name '*.g.dart' -o -name '*.config.dart' -o -name '*.module.dart' | xargs rm -f
	@# The asset graph too, not just its outputs. build_runner records the file
	@# list it saw last run; delete a source in another package and the next run
	@# aborts with "Tried to delete from package not in the build" — which is
	@# what `rebuild` is supposed to rescue you from, and did not.
	@find . -type d -name build -path '*/.dart_tool/*' -prune -exec rm -rf {} +

rebuild: clean get codegen ## Clean rebuild — use after a messy merge or a deleted source file

doctor: ## Environment sanity check
	$(FLUTTER) doctor -v

# --- Run ---------------------------------------------------------------------

dev: ## Run the dev flavor
	cd app && $(FLUTTER) run --dart-define-from-file=env_config/dev/dart_defines.json

stg: ## Run the staging flavor
	cd app && $(FLUTTER) run --dart-define-from-file=env_config/stg/dart_defines.json

prod: ## Run the production flavor
	cd app && $(FLUTTER) run --dart-define-from-file=env_config/prod/dart_defines.json

# --- Build -------------------------------------------------------------------
# Release builds always obfuscate and split debug info. Shipping without
# --split-debug-info makes a crash report a wall of unresolvable frames.

apk: ## Release APK — FLAVOR=dev|stg|prod
	cd app && $(FLUTTER) build apk --release --obfuscate --split-debug-info=build/debug-info $(DEFINES)

aab: ## Play Store bundle — FLAVOR=prod
	cd app && $(FLUTTER) build appbundle --release --obfuscate --split-debug-info=build/debug-info $(DEFINES)

ipa: ## iOS archive — FLAVOR=prod (macOS only)
	cd app && $(FLUTTER) build ipa --release --obfuscate --split-debug-info=build/debug-info $(DEFINES)

# --- Scaffolding -------------------------------------------------------------

rename: ## Rebrand the template: make rename NAME="My App" ORG=com.acme.myapp
	@$(DART) run tools/rename.dart --name "$(NAME)" --org "$(ORG)"
