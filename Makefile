.PHONY: test mac ios project help run dmg dial bench

PROJECT = SaltmarshIsles.xcodeproj
SCHEME = SaltmarshIsles
VERSION = $(shell sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)

test:
	swift test
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

mac:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' build

# Help pages only load from an Applications folder, so this runs the Mac app from one.
# A Release build, so the Captain and Admiral search at full speed; a Debug build is about twenty times slower.
run:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'platform=macOS' -derivedDataPath build build
	rm -rf "$(HOME)/Applications/SaltmarshIslesDev"
	mkdir -p "$(HOME)/Applications/SaltmarshIslesDev"
	ditto build/Build/Products/Release/SaltmarshIsles.app "$(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"
	open -n "$(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"

# A Release build for Apple silicon and Intel Macs, signed ad hoc, in a disk image
# with a link to Applications.
dmg:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build/release build
	rm -rf build/dmg
	mkdir -p build/dmg
	ditto build/release/Build/Products/Release/SaltmarshIsles.app build/dmg/SaltmarshIsles.app
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "Saltmarsh Isles" -srcfolder build/dmg -ov -format UDZO build/SaltmarshIsles-$(VERSION).dmg

ios:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' build

project:
	xcodegen generate

help:
	swift run help-book App/SaltmarshIsles.help
	cd App/SaltmarshIsles.help/Contents/Resources && hiutil -I lsm -Caf en.lproj/SaltmarshIsles.helpindex en.lproj
	cd App/SaltmarshIsles.help/Contents/Resources && hiutil -I corespotlight -Caf en.lproj/SaltmarshIsles.cshelpindex en.lproj

# The search dial test needs a release build; a searched game takes seconds in debug.
dial:
	swift test -c release -Xswiftc -enable-testing --filter SearchDialTests

# The effort dial at shipped budgets: minutes with --fast, hours in full. BENCH_ARGS="--games 20".
bench:
	swift run -c release ai-bench $(BENCH_ARGS)
