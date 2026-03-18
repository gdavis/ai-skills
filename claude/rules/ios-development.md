# iOS/macOS Development

## Xcode Tools MCP

- Prefer the `xcode-tools` MCP server over shell commands for Xcode-related operations such as building, testing, resolving packages, cleaning, and querying project structure
- Do NOT invoke `xcodebuild`, `swift build`, `swift test`, `swift package`, `xcrun`, or similar CLI executables directly when the MCP provides equivalent functionality
- Always check the MCP tool schema before calling a tool to ensure correct parameters
- If the MCP server is unavailable or errored, fall back to CLI commands and inform the user

## Patterns

- MVVM preferred
- Protocol-oriented design
- Dependency injection
- Proper use of weak/unowned to avoid retain cycles

## Standards

- Proper error handling, not silent failures or force unwraps in production
- Check for retain cycles in closures and async operations
- Consider main thread requirements for UI updates
- Prefer `@MainThread` method annotation for view updates and clarity
- Use appropriate access control (private, internal, public)
- Prefer composition over inheritance
- Swift Concurrency is preferred over `DispatchQueue` use cases
- Use `guard` for early exits
- Prefer refactoring helper methods to model object extensions instead of multiple lines of inline logic

## UIKit Best Practices

- Build lists using `UICollectionView` with `NSCollectionViewDiffableDataSource` and `NSCollectionViewCompositionalLayout`
- Use extensions to organize common functionality
- Use Combine publishers to bind view model properties to views

## AppKit Best Practices

- Proper macOS standards for common actions such as key shortcuts and responder chains
- Prefer high performance over simplicity, e.g. `NSCollectionView` over SwiftUI `List`

## SwiftUI Best Practices

- View models favor the `@Observable` macro over the `ObservableObject` protocol
- Extract views when they exceed 100 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `@Bindable` for bindings to `@Observable` objects
- Ask to refactor child views to new files when the main view becomes large

## UIKit/AppKit View Model Requirements

- View controllers should NOT build complex Combine publisher chains directly
- Create a dedicated view model when a view controller needs to:
  - Subscribe to multiple publishers
  - Transform or combine publisher values for display
  - Manage state that affects multiple UI elements
- View models encapsulate publisher logic and expose simple, observable properties
- View controllers only bind UI elements to view model properties
- Prefer using pre-built publisher methods from providers over constructing equivalent chains manually in view controllers
- Avoid inline `flatMap`, `combineLatest`, or other complex operators in view controller setup methods

## Code Review Standards

- Expect proper error handling, not silent failures
- Look for race conditions and threading issues
- Check for memory leaks and retain cycles
- Ensure graceful degradation when external services fail
- Identify overly complex logic as technical debt
- Verify Core Data context usage is thread-safe
