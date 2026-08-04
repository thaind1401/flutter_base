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

# Packages that own an ARB and generate their own localizations. Checked against
# the tree by `make check-l10n`: a package with an l10n.yaml that is missing here
# never gets generated, and the barrel then exports a file nobody produced.
#
# Every package listed here must ship the *same* set of locales. A delegate is
# asked `isSupported(locale)` and a "no" does not fall back to English — the type
# is simply absent from the tree and `of(context)` throws. One missing .arb is a
# crash in that language, so check-l10n treats a locale gap as a build failure.
L10N_PACKAGES := core/core_ui features/feature_auth app

FLAVOR ?= dev
DEFINES = --dart-define-from-file=env_config/$(FLAVOR)/dart_defines.json

.DEFAULT_GOAL := help
.PHONY: help setup sdk env get hooks codegen codegen-watch l10n analyze fmt fmt-check test test-coverage check-flags \
        integration golden golden-update check-deps check-artifacts check-props check-l10n ci clean rebuild dev stg prod apk aab ipa \
        ios-nosign rename doctor

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

l10n: ## Regenerate localizations from the ARB files in every l10n package
	@for pkg in $(L10N_PACKAGES); do \
		echo "→ l10n $$pkg"; \
		(cd $$pkg && $(FLUTTER) gen-l10n) || exit 1; \
	done

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
DART_SOURCES = $(shell find $(addsuffix /lib,$(PACKAGES)) $(addsuffix /test,$(PACKAGES)) app/integration_test tools \
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
	@# `--exclude-tags golden` because a golden failure depends on the renderer,
	@# not on the change: a developer whose machine disagrees with CI would be
	@# blocked by a diff they cannot act on. `make golden` runs them explicitly
	@# and CI runs them as their own step.
	@for pkg in $(or $(PKG),$(TEST_PACKAGES)); do \
		echo "→ test $$pkg"; \
		(cd $$pkg && $(FLUTTER) test --exclude-tags golden $(ARGS)) || exit 1; \
	done

# Golden tests live only in core_ui and are tagged `golden`, so they can be run
# and skipped as a set. `make test` excludes them: they are the one kind of test
# whose result depends on the renderer, and a developer on a machine that
# disagrees with CI should not be blocked by a diff they cannot act on. CI runs
# them as their own step, where the SDK is the one pinned in .fvmrc.
GOLDEN_PACKAGE := core/core_ui

golden: ## Verify the design-system golden snapshots
	cd $(GOLDEN_PACKAGE) && $(FLUTTER) test --tags golden

golden-update: ## Rewrite the golden snapshots — then REVIEW THE IMAGES
	@# Regenerating is the easy half. A golden nobody opened is worse than no
	@# golden: it launders the regression into the baseline and every later diff
	@# is measured against the broken picture.
	cd $(GOLDEN_PACKAGE) && $(FLUTTER) test --tags golden --update-goldens
	@echo ""
	@echo "→ open the changed PNGs before committing:"
	@echo "    git diff --stat -- '$(GOLDEN_PACKAGE)/test/goldens/*.png'"

integration: ## Run integration tests on a booted device/emulator/simulator
	@# Deliberately NOT part of `make ci`. These need a device, CI runners do not
	@# have one, and a gate that cannot run everywhere is a gate people learn to
	@# skip. `.github/workflows/integration.yml` boots an emulator for them on a
	@# schedule and on demand. What they buy over `app/test/app_smoke_test.dart`
	@# is the real plugin channels — that test mocks secure storage, preferences
	@# and connectivity, so every device-only failure is invisible to it.
	@# `-d` is not optional, and the reason is specific: on any Mac, `macos` and
	@# `chrome` are always connected devices, so `flutter test integration_test`
	@# aborts with "More than one device connected" every single time. The first
	@# version of this target omitted it and could never have run anywhere.
	@#
	@# The guard is by *platform*, not by device count, for the same reason: a
	@# check for "is any device present" is satisfied by macOS and Chrome and so
	@# never fires. Only android-* and ios can run these.
	@#
	@# Override with `make integration DEVICE=emulator-5554` when more than one
	@# phone is attached.
	@device="$(or $(DEVICE),$$($(FLUTTER) devices --machine \
		| grep -B4 '"targetPlatform": "\(android\|ios\)' \
		| grep '"id"' | head -1 | sed 's/.*: "\(.*\)",/\1/'))"; \
	if [ -z "$$device" ]; then \
		echo "✗ no android or ios device. Boot an emulator/simulator, or plug in a phone."; \
		echo "  macOS and Chrome do not count — these tests exist to exercise mobile plugins."; \
		$(FLUTTER) devices; \
		exit 1; \
	fi; \
	echo "→ integration tests on $$device"; \
	cd app && $(FLUTTER) test integration_test -d "$$device" $(DEFINES) $(ARGS)

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
# `.flutter-plugins-dependencies` is here because three of them were tracked
# while this check stayed green — the pattern decides what counts, and a name it
# does not list is invisible no matter how obviously generated the file is. That
# one says so on its own first line ("do not edit or check into version
# control"), `.gitignore` had listed it since before this check existed, and it
# was tracked anyway: exactly the trap rule 9 describes, where ignoring a file
# git already follows does nothing. Each one also holds absolute `.pub-cache`
# paths and a `date_created`, so they carry the committer's username and churn
# on every `pub get`.
# `.dart_tool` and `.fvm` are `(^|/)`-anchored, not `^`-anchored. They used to be
# the latter, which matched only the copies at the repository root — so three
# `<package>/.dart_tool/flutter_build/dart_plugin_registrant.dart` files were
# tracked while this check passed. In a workspace every package has its own
# `.dart_tool`, and the root is the one that matters least.
#
# The content pass below is what found them. That is the division of labour:
# this list is fast and precise for what is already known, and the header grep
# is what notices the thing nobody thought to list.
ARTIFACT_PATTERN := (^|/)\.dart_tool/|(^|/)\.fvm/|(^|/)build/|(^|/)coverage/|\.g\.dart$$|\.config\.dart$$|\.module\.dart$$|l10n/generated/|env_config/.*/dart_defines\.json$$|(^|/)\.flutter-plugins(-dependencies)?$$

check-props: ## Fail if an Equatable class omits a field from props
	@# Rule 14's teeth. A field outside `props` is invisible to `==`, so
	@# BlocSelector and buildWhen never rebuild for it — the state is right, the
	@# widget is right, and the screen simply does not update. Deliberate
	@# exclusions live in `allowedOmissions` with their reason.
	@$(DART) run tools/check_equatable_props.dart

check-l10n: ## Fail if the l10n packages disagree on locales, keys or delegates
	@# The three ways per-package localization breaks silently: a package with an
	@# ARB missing from L10N_PACKAGES (generated for nobody), a package short one
	@# locale (a crash in that language, not a fallback), and a generated class
	@# whose delegate the host never registered (a crash on first open). None of
	@# the three is a compile error. ADR-0011.
	@$(DART) run tools/check_l10n.dart

# What a generated file says about itself, on its first line.
#
# The name check below is a denylist, and a denylist fails **open**: it catches
# what it was taught and waves through everything else. Three
# `.flutter-plugins-dependencies` files rode in that way while this target
# reported success, because nothing had added them to ARTIFACT_PATTERN.
#
# Most Dart and Flutter generators stamp a header saying not to check the file
# in. Grepping for that stamp catches the next such file without anyone
# predicting its name — which is the only way this check gets ahead of the
# problem rather than one incident behind it.
GENERATED_MARKER := generated file|GENERATED CODE - DO NOT MODIFY|do not edit or check into version control|DO NOT EDIT

check-flags: ## Fail if a config flag promises a feature nothing implements
	@# `AppEnvironmentConfig.enableCertificatePinning` was true in production and
	@# read by nothing, while two tests asserted its value — so it looked wired
	@# and covered, and an auditor reading the config would have concluded that
	@# production traffic was pinned. A `bool enableX` is a claim; this checks
	@# something honours it. Deliberate exceptions live in `allowedUnread` with
	@# their reason.
	@$(DART) run tools/check_dead_flags.dart

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
	@# Second pass, by content rather than by name. Only the first two lines are
	@# read, so a source file merely discussing generated code is not a hit, and
	@# this stays fast over the whole index. Files the name pass already covers
	@# are excluded so a real offender is reported once.
	@selfdeclared=$$(git ls-files | grep -vE '$(ARTIFACT_PATTERN)' | while read -r f; do \
		[ -f "$$f" ] || continue; \
		head -n 2 "$$f" 2>/dev/null | grep -qiE '$(GENERATED_MARKER)' && echo "$$f"; \
	done); \
	if [ -n "$$selfdeclared" ]; then \
		echo "✗ these tracked files declare themselves generated:"; \
		echo "$$selfdeclared" | sed 's/^/    /'; \
		echo ""; \
		echo "  Untrack them, then add the pattern to ARTIFACT_PATTERN so the"; \
		echo "  name pass catches the next one before it is committed:"; \
		echo "    git rm -r --cached <path>"; \
		exit 1; \
	fi
	@echo "✓ no build output, generated code or env files tracked, by name or by header"

ci: get l10n codegen fmt-check analyze test golden check-deps check-props check-l10n check-flags check-artifacts ## The full quality gate
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

ios-nosign: ## Compile iOS without signing — the release-build check CI can run
	@# A signing identity is a per-project secret this base does not ship, so
	@# `ipa` cannot run in CI on a fresh clone. This target still catches what
	@# actually breaks an iOS release: a plugin with no iOS implementation, a
	@# Podfile that will not resolve, a deployment target below what a
	@# dependency needs. None of those show up in `flutter test`.
	cd app && $(FLUTTER) build ios --release --no-codesign $(DEFINES)

# --- Scaffolding -------------------------------------------------------------

rename: ## Rebrand the template: make rename NAME="My App" ORG=com.acme.myapp
	@$(DART) run tools/rename.dart --name "$(NAME)" --org "$(ORG)"
