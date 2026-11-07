.PHONY: test mac ios project help helpbook build run dmg dial bench clean

PROJECT = SaltmarshIsles.xcodeproj
SCHEME = SaltmarshIsles
VERSION = $(shell sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)

comma := ,

# The folder Xcode builds into for a destination; mac and ios use Xcode's own DerivedData.
products = $$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(1)' -showBuildSettings 2>/dev/null | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | head -1)

test:
	swift test
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

mac:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' build
	@echo "Built $(call products,platform=macOS)/SaltmarshIsles.app"

# Help pages only load from an Applications folder, so this runs the Mac app from one.
# A Release build of the Mac app into build/Build/Products/Release/SaltmarshIsles.app, so the Captain and
# Admiral search at full speed; a Debug build is about twenty times slower.
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'platform=macOS' -derivedDataPath build build
	@echo "Built build/Build/Products/Release/SaltmarshIsles.app"

# Build, install the app in ~/Applications/SaltmarshIslesDev and open it.
run: build
	rm -rf "$(HOME)/Applications/SaltmarshIslesDev"
	mkdir -p "$(HOME)/Applications/SaltmarshIslesDev"
	ditto build/Build/Products/Release/SaltmarshIsles.app "$(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"
	open -n "$(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"
	@echo "Installed and opened $(HOME)/Applications/SaltmarshIslesDev/SaltmarshIsles.app"

# A Release build for Apple silicon and Intel Macs, signed ad hoc, in a disk image
# with a link to Applications.
dmg:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build/release build
	rm -rf build/dmg
	mkdir -p build/dmg
	ditto build/release/Build/Products/Release/SaltmarshIsles.app build/dmg/SaltmarshIsles.app
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "Saltmarsh Isles" -srcfolder build/dmg -ov -format UDZO build/SaltmarshIsles-$(VERSION).dmg
	@echo "Built build/SaltmarshIsles-$(VERSION).dmg"

ios:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' build
	@echo "Built $(call products,platform=iOS Simulator$(comma)name=iPhone 15 Pro$(comma)OS=17.5)/SaltmarshIsles.app"

project:
	xcodegen generate

help:
	@echo "make test      package tests, then the full scheme on the Mac"
	@echo "make mac       Debug build for Mac, into Xcode's DerivedData"
	@echo "make ios       Debug build for the iPhone 15 Pro simulator on iOS 17.5"
	@echo "make build     Release build of the Mac app into build/Build/Products/Release/"
	@echo "make run       build, install in ~/Applications/SaltmarshIslesDev and open it"
	@echo "make dmg       Release disk image into build/SaltmarshIsles-<version>.dmg"
	@echo "make project   regenerate the Xcode project with xcodegen"
	@echo "make helpbook  rebuild the Mac help book and its search index"
	@echo "make dial      the search dial test, as a release build"
	@echo "make bench     the level-versus-level win table; BENCH_ARGS=\"--fast --games 4\""
	@echo "make clean     remove build/, .build/ and this project's DerivedData"
	@echo "make help      this list"

helpbook:
	swift run help-book App/SaltmarshIsles.help
	cd App/SaltmarshIsles.help/Contents/Resources && hiutil -I lsm -Caf en.lproj/SaltmarshIsles.helpindex en.lproj
	cd App/SaltmarshIsles.help/Contents/Resources && hiutil -I corespotlight -Caf en.lproj/SaltmarshIsles.cshelpindex en.lproj

# The search dial test needs a release build; a searched game takes seconds in debug.
dial:
	swift test -c release -Xswiftc -enable-testing --filter SearchDialTests

# The effort dial at shipped budgets: minutes with --fast, hours in full. BENCH_ARGS="--games 20".
bench:
	swift run -c release ai-bench $(BENCH_ARGS)

# Remove every build product: the repo's build folders and Xcode's DerivedData for this project.
clean:
	rm -rf build .build
	find "$(HOME)/Library/Developer/Xcode/DerivedData" -maxdepth 1 -name 'SaltmarshIsles-*' -exec rm -rf {} +
