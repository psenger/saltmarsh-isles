.PHONY: test mac ios project

PROJECT = SaltmarshIsles.xcodeproj
SCHEME = SaltmarshIsles

test:
	swift test
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

mac:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' build

ios:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' build

project:
	xcodegen generate
