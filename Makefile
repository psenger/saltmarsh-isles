.PHONY: test mac ios project help run

PROJECT = SaltmarshIsles.xcodeproj
SCHEME = SaltmarshIsles

test:
	swift test
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

mac:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' build

# Help pages only load from an Applications folder, so this runs the Mac app from one.
run:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath build build
	rm -rf "$(HOME)/Applications/SaltmarshIslesDev"
	mkdir -p "$(HOME)/Applications/SaltmarshIslesDev"
	ditto build/Build/Products/Debug/SaltmarshIsles.app "$(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"
	open -n "$(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"

ios:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' build

project:
	xcodegen generate

help:
	swift run help-book App/SaltmarshIsles.help
	cd App/SaltmarshIsles.help/Contents/Resources && hiutil -I lsm -Caf en.lproj/SaltmarshIsles.helpindex en.lproj
	cd App/SaltmarshIsles.help/Contents/Resources && hiutil -I corespotlight -Caf en.lproj/SaltmarshIsles.cshelpindex en.lproj
