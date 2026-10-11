# Engineering standards

The rules I followed in this project. Mostly: keep it simple and easy to read.

## Platform and tools

- iOS 17+, iPhone only, portrait and landscape.
- Swift 5 with strict concurrency checking set to complete. The build has 0 warnings.
- SwiftUI with Observation (`@Observable`). No `ObservableObject`.
- Only Apple frameworks. No third-party packages.
- SwiftLint with its default rules. It runs as a build phase in Xcode, and with `--strict` in the terminal and on CI.

## Architecture

- Features use Domain and Data. Data uses Domain. Domain only uses Foundation.
- Only `Data/Local` imports SwiftData. The rest of the app works with the `Listing` struct.
- Each job has one owner:
  - `ListingRepository`: local data
  - `SyncEngine`: syncing
  - `HTTPListingsAPI`: network calls
  - `ImageFileStore`: photo files
  - `ImageLoader`: images on screen
- Dependencies are passed in through `init` or the SwiftUI environment. There are only three shared instances: `ImageFileStore.app`, `URLSession.mock` and `MockServer.shared`.
- Protocols only where a test needs a fake: `ListingsAPI` and `Connectivity`.
- No extra layers or base classes.

## Code style

- Classes are `final`.
- No force unwraps, force casts or `try!` in app code. Tests can use them.
- `fatalError` is used in one place: when the database can't be opened at launch.
- No `print`. Logging goes through `os.Logger` (`Log.sync`).
- Files stay under 400 lines and functions under 50 lines (SwiftLint defaults). One main type per file.
- A view model's `init` only sets values. Real work starts in `.task` or after a user action.
- Dependencies inside `@Observable` classes are `@ObservationIgnored private let`.
- `.onChange(of:)` uses the version with old and new values.
- Readable code.
- One short comment above each type and each function that isn't obvious.

## Concurrency

- On the main actor: views, view models, `ListingRepository`, `SyncEngine`, `NetworkMonitor`.
- `ImageFileStore` and `ImageLoader` are actors, so photo files and image decoding stay off the main thread.
- No `DispatchQueue.main.async` and no `Task.detached`.
- No `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency`.

## Data and sync rules

1. No server `revision` means POST. Otherwise PUT.
2. `updatedAt` changes only when the user creates or edits a listing.
3. Favorites stay on the device and are never sent.
4. A pull never overwrites a listing that is pending or failed.
5. `markSynced` and `markFailed` only change the state if `updatedAt` is still what we pushed.
6.  Photos go first, then the listing, then the pull. Temporary errors never mark a listing as failed.
7. The SwiftData context is saved after every change.

## Errors

- Storage and network errors are thrown, not hidden.
- Screens show errors in an alert.
- Sync errors show in the status bar with a Retry button.
- Network errors become an `APIError`: offline, server, unauthorized, conflict, validation, unexpected status or decoding.
- If an image fails to load, the view shows a placeholder. The listing isn't affected.

## Security

- The auth token is only stored in the Keychain (`AfterFirstUnlock`) and is never logged.
- `os.Logger` hides interpolated values by default.
- App Transport Security is on. The mock host uses `https`.
-  Responses are checked by status code first, then decoded. Bad data gives an error, not a crash.

## Money and dates

- Prices are stored as `Int` paise (`priceCents`) and shown in ₹.
- Dates in JSON are milliseconds since 1970.

## Testing

- XCTest.
- Unit tests cover the sync logic (`SyncEngineTests`) only.
- Tests use fakes (`FakeListingsAPI`, `FakeConnectivity`) and an in-memory database. No real network.
- No sleeps or waiting on timers.
- Test names say what they check, like `test_offline_keepsListingPending_andMakesNoCalls`.

## What done means: 

- 0 warnings.
- `swiftlint lint --strict` passes.
- All tests pass.

## CI

- GitHub Actions runs lint, build and tests on every push and pull request.
