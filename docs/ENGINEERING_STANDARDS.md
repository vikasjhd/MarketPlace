# Engineering standards

The rules this project follows. Short version: keep it simple, keep it readable, keep it safe.

## Platform and tools

- iOS 17.0+, iPhone, portrait and landscape.
- Swift 5 language mode, strict concurrency checking `complete`, warnings treated as errors. The build must have 0 warnings.
- SwiftUI with Observation (`@Observable`, `@State`, `@Environment`). No Combine, no `ObservableObject`.
- Apple frameworks only. No third-party packages.
- SwiftLint with the default rules, run with `--strict`.

## Architecture

- Layers: Features → Domain + Data. Data → Domain. Domain depends on Foundation only.
- SwiftData is imported only in `Data/Local/`. The rest of the app uses plain `Listing` structs.
- One type owns each job: `ListingRepository` (local data), `SyncEngine` (sync), `HTTPListingsAPI` (network), `ImageFileStore` (photo files), `ImageLoader` (displaying images).
- Pass dependencies in through `init` or the SwiftUI environment. No hidden state.
- Add a protocol only when a test needs a fake (`ListingsAPI`, `Connectivity`).
- No extra layers, base classes or generic helpers unless there is a clear need.

## Code style

- `final` classes by default.
- No force unwraps, force casts or `try!` in app code (tests may use them).
- `fatalError` only if the database can't be opened at launch.
- No `print`. Use `os.Logger` (`Log.sync`).
- Files under 400 lines, functions under 50 lines (SwiftLint default). One main type per file.
- View model `init` does no work. Work starts in `.task` or from a user action.
- Dependencies inside `@Observable` classes are `@ObservationIgnored private let`.
- `.onChange(of:)` uses the two-parameter form.
- Plain, readable code over clever code.
- Comments: one short line above each type and each non-obvious function, saying what it is and does. A short "why" line where a choice isn't obvious. No comments on obvious lines.

## Concurrency

- Main actor: views, view models, `ListingRepository`, `SyncEngine`, `NetworkMonitor`.
- Actors: `ImageFileStore`, `ImageLoader`. Disk and image work happens there, never on the main thread.
- No `DispatchQueue.main.async`, no `Task.detached`.
- No `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency`.
- Cancellation is not an error. `CancellationError` never becomes a failure state.

## Data and sync rules

1. Create vs update comes from `revision == nil` (POST) or not (PUT).
2. `updatedAt` changes only on user create or edit.
3. Favorites are local only and never sent to the server.
4. Pull never overwrites a pending or failed local listing.
5. `markSynced` and `markFailed` only change state if `updatedAt` is still the pushed value.
6. The pull cursor moves only after pulled data is saved.
7. Push photos first, then the listing, then pull. Temporary errors never mark a listing failed.
8. A 409 means the server copy won. The app applies it.
9. Save the SwiftData context after every change.

## Errors

- Storage and network errors are thrown, not hidden.
- Screens show errors in an alert.
- Sync errors show in the status bar with a Retry button.
- API errors are mapped to `APIError` (offline, server, unauthorized, conflict, validation, unexpected status, decoding).
- Image loading may fail quietly: the view shows a placeholder and the listing is not affected.

## Security

- The auth token lives only in the Keychain (`AfterFirstUnlock`). It is never logged.
- `os.Logger` keeps interpolated values private by default.
- App Transport Security stays on. The mock host uses `https`.
- User input is validated in the app and again by the server.
- Server responses are checked: status code first, then decode. Bad data is an error, never a crash.

## Money and dates

- Prices are `Int` paise (`priceCents`), shown as INR with the `en_IN` locale.
- JSON dates are epoch milliseconds.

## Testing

- XCTest.
- Unit tests cover sync logic (`SyncEngineTests`).
- Use fakes (`FakeListingsAPI`, `FakeConnectivity`) and an in-memory database. No real network.
- No sleeps or timing-based waits.
- Test names say what they check, for example `test_offline_keepsListingPending_andMakesNoCalls`.

## Definition of done

- Builds with 0 warnings.
- `swiftlint lint --strict` is clean.
- All tests pass.
- Docs updated if behavior changed.

## Git

- Conventional commit messages: `feat:`, `fix:`, `test:`, `docs:`, `chore:`.
- CI runs lint, build and tests on every push and pull request.
