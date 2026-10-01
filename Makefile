# MacToFind Makefile
# Simple commands for building and distributing the app

.PHONY: help build release dmg clean run install test

# Default target
help:
	@echo "MacToFind Build System"
	@echo "========================"
	@echo ""
	@echo "Available commands:"
	@echo "  make build    - Quick build (debug mode)"
	@echo "  make release  - Build release version"
	@echo "  make dmg      - Build and create DMG installer"
	@echo "  make run      - Build and run the app"
	@echo "  make install  - Build and install to /Applications"
	@echo "  make test     - Run tests"
	@echo "  make clean    - Clean build artifacts"
	@echo ""

# Quick build for development
build:
	@echo "🔨 Building MacToFind (Debug)..."
	@./Scripts/quick-build.sh debug

# Release build
release:
	@echo "🚀 Building MacToFind (Release)..."
	@./Scripts/quick-build.sh

# Create DMG installer
dmg:
	@echo "💿 Creating DMG installer..."
	@./Scripts/build.sh

# Build and run
run: build
	@echo "▶️  Running MacToFind..."
	@open build/MacToFind.app

# Build and install to Applications
install: release
	@echo "📦 Installing to /Applications..."
	@rm -rf /Applications/MacToFind.app
	@cp -R build/MacToFind.app /Applications/
	@echo "✅ Installed successfully!"
	@echo "You can now run MacToFind from Applications"

# Run tests
test:
	@echo "🧪 Running tests..."
	@xcodebuild test \
		-project MacToFind.xcodeproj \
		-scheme MacToFind \
		-destination 'platform=macOS'

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf ~/Library/Developer/Xcode/DerivedData/MacToFind-*
	@echo "✅ Clean complete!"

# Create a new release tag
tag:
	@echo "Creating new release tag..."
	@read -p "Enter version (e.g., 1.0.1): " version; \
	git tag -a "v$$version" -m "Release v$$version"; \
	echo "✅ Created tag v$$version"; \
	echo "Push with: git push origin v$$version"