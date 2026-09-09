# BannerHither build entry points. Run `make help` for a summary.

APP_NAME        := BannerHither
VERSION         := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
GITHUB_REPO     ?= KJeon10/BannerHither
CONFIGURATION   ?= release
ARCHS           ?= universal
CODESIGN_IDENTITY ?= -
ICON_PNG        ?=

export CONFIGURATION ARCHS CODESIGN_IDENTITY GITHUB_REPO

.PHONY: help build run test clean install icon release cask log

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## Build build/BannerHither.app (universal; ad-hoc signed unless CODESIGN_IDENTITY is set)
	scripts/build-app.sh

run: build ## Build, then (re)launch the app
	-pkill -x $(APP_NAME)
	open build/$(APP_NAME).app

test: ## Run the unit tests
	swift test

clean: ## Remove build products
	rm -rf .build build dist

install: build ## Copy the app to /Applications
	rm -rf /Applications/$(APP_NAME).app
	cp -R build/$(APP_NAME).app /Applications/

icon: ## Regenerate Resources/AppIcon.icns from a PNG: make icon ICON_PNG=path/to/icon-1024.png
	scripts/make-icon.sh "$(ICON_PNG)"

release: CODESIGN_IDENTITY := $(if $(filter -,$(CODESIGN_IDENTITY)),auto,$(CODESIGN_IDENTITY))
release: ## Developer ID build + notarize + staple → dist/BannerHither-$(VERSION).dmg (needs create-dmg)
	scripts/build-app.sh
	scripts/notarize.sh

cask: ## Render the Homebrew cask for the current release image → dist/bannerhither.rb
	scripts/make-cask.sh

log: ## Stream the app's unified log
	log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
