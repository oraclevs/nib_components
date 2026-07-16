
# =====================================================
# StackForge – Advanced Flutter Makefile
# =====================================================

# ------------------
# Core
# ------------------
FLUTTER      := flutter
DART         := dart
BUILD_DIR    := build
SYMBOLS      := build/symbols
COVERAGE     := coverage
APK          := $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
AAB          := $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
IPA_DIR      := $(BUILD_DIR)/ios/ipa

.DEFAULT_GOAL := help

# ------------------
# Android Signing
# ------------------
KEYSTORE     ?= android/key.jks
KEY_ALIAS    ?= key_alias
KEY_PASS     ?= key_password
STORE_PASS   ?= store_password

# ------------------
# iOS Signing
# ------------------
IOS_TEAM     ?= YOUR_TEAM_ID
IOS_EXPORT   ?= ios/exportOptions.plist

# ------------------
# Flavors
# ------------------
FLAVOR       ?= prod
ENTRY        ?= lib/main_$(FLAVOR).dart

# ------------------
# Help
# ------------------
.PHONY: help
help:
	@echo "Core:"
	@echo "  make deps        → install deps"
	@echo "  make clean       → clean build"
	@echo "  make doctor     → flutter doctor"
	@echo ""
	@echo "Quality:"
	@echo "  make fmt         → format"
	@echo "  make analyze     → analyze"
	@echo "  make test        → tests"
	@echo "  make cov         → coverage"
	@echo "  make qa          → fmt + analyze + test"
	@echo ""
	@echo "Run:"
	@echo "  make run-a       → android"
	@echo "  make run-i       → ios"
	@echo ""
	@echo "Build:"
	@echo "  make apk         → android apk"
	@echo "  make aab         → android appbundle"
	@echo "  make ios         → ios build"
	@echo "  make ipa         → export ipa"
	@echo ""
	@echo "Advanced:"
	@echo "  make gen         → codegen"
	@echo "  make watch       → codegen watch mode "
	
	@echo "  make icons       → launcher icons"
	@echo "  make splash      → splash screen"
	@echo "  make version     → show version"
	@echo "  make ci          → CI pipeline"
	@echo "  make install-a   → Install release apk"

# ------------------
# Core Workflow
# ------------------
deps:
	$(FLUTTER) pub get

upgrade:
	$(FLUTTER) pub upgrade --major-versions

clean:
	$(FLUTTER) clean
# 	rm -rf $(SYMBOLS) $(COVERAGE)
clean_get: clean deps

doctor:
	$(FLUTTER) doctor -v

# ------------------
# Quality
# ------------------
fmt:
	$(FLUTTER) format lib/ test/ --set-exit-if-changed

analyze:
	$(FLUTTER) analyze

lint:
	$(DART) analyze

test:
	$(FLUTTER) test

cov:
	$(FLUTTER) test --coverage
	genhtml $(COVERAGE)/lcov.info -o $(COVERAGE)/html

qa: fmt analyze test

# ------------------
# Codegen
# ------------------
gen:
	$(DART) run build_runner build --delete-conflicting-outputs

watch:
	$(DART) run build_runner watch --delete-conflicting-outputs

# ------------------
# Run
# ------------------
run-a:
	$(FLUTTER) run -d android --flavor $(FLAVOR) -t $(ENTRY)

run-i:
	$(FLUTTER) run -d ios --flavor $(FLAVOR) -t $(ENTRY)

# ------------------
# Android
# ------------------
apk:
	$(FLUTTER) build apk --release \
		--flavor $(FLAVOR) -t $(ENTRY) \
		--obfuscate --split-debug-info=$(SYMBOLS)

apk-debug:
	$(FLUTTER) build apk --debug --flavor $(FLAVOR)

aab:
	$(FLUTTER) build appbundle --release \
		--flavor $(FLAVOR) -t $(ENTRY)

sign-apk:
	jarsigner -keystore $(KEYSTORE) \
		-storepass $(STORE_PASS) \
		-keypass $(KEY_PASS) \
		$(APK) $(KEY_ALIAS)

install-a:
	adb install -r $(APK)

# ------------------
# iOS
# ------------------
ios:
	$(FLUTTER) build ios --release \
		--flavor $(FLAVOR) -t $(ENTRY) \
		--obfuscate --split-debug-info=$(SYMBOLS)

archive:
	xcodebuild archive \
		-workspace ios/Runner.xcworkspace \
		-scheme Runner \
		-configuration Release \
		-archivePath $(BUILD_DIR)/ios/Runner.xcarchive \
		-developmentTeam $(IOS_TEAM)

ipa:
	xcodebuild -exportArchive \
		-archivePath $(BUILD_DIR)/ios/Runner.xcarchive \
		-exportOptionsPlist $(IOS_EXPORT) \
		-exportPath $(IPA_DIR)

install-i:
	$(FLUTTER) install -d ios

# ------------------
# Branding
# ------------------
icons:
	$(DART) run flutter_launcher_icons

splash:
	$(DART) run flutter_native_splash:create

branding: icons splash

# ------------------
# Security
# ------------------
keystore:
	keytool -genkey -v \
		-keystore $(KEYSTORE) \
		-alias $(KEY_ALIAS) \
		-keyalg RSA -keysize 2048 -validity 10000

# ------------------
# Versioning
# ------------------
version:
	@grep "^version:" pubspec.yaml

bump-patch:
	$(DART) pub global run cider bump patch

bump-minor:
	$(DART) pub global run cider bump minor

bump-major:
	$(DART) pub global run cider bump major

# ------------------
# CI / Release
# ------------------
ci: deps gen qa apk ios

release: clean deps gen qa aab ipa

        