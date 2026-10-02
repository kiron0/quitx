# Contributing to QuitX for macOS

Thank you for your interest in improving QuitX! We welcome issues, bug reports, feature requests, and pull requests.

## Development Setup

QuitX is built completely using Swift Package Manager (SPM) with no mandatory Xcode project files needed.

### Requirements
- macOS 14.0 Sonoma or later
- Swift 5.9+ / Xcode CommandLineTools or Xcode 15+

### Getting Started

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/kiron0/quitx.git
   cd quitx/app
   ```

2. Build debug binary:
   ```bash
   swift build --build-system native
   ```

3. Run automated tests:
   ```bash
   swift test --build-system native
   ```

4. Create and launch the macOS app bundle:
   ```bash
   make run
   ```

## Pull Request Guidelines

- Ensure your code builds cleanly without warnings using `swift build --build-system native`.
- Follow standard Swift coding style and keep the interface minimal, snappy, and native to macOS.
- Keep commits descriptive and concise.
