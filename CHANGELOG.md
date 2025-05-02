# DataKeep

## [Unreleased](https://github.com/noahrepublic/DataKeep/compare/v5.0.0...HEAD)

- Fixed auto save
- Live check should only be performed in studio
- Added docs info about `store:LoadKeep()` and `keep:Release()` retrying
- Improved logging, added `logPromiseTraceback` to config (default: `false`)
- Exported `ViewKeep` type
- Fixed some types
- Added `keep.SaveFailed` and `keep.ReleaseFailed` signals

### Breaking Changes

- Removed promises from `keep.Saving` and `keep.Releasing` signals
- `keep.Saving` -> `keep.Saved`
- `keep.Releasing` -> `keep.Released`

## [version 5.0.0](https://github.com/noahrepublic/DataKeep/releases/tag/v5.0.0): 12/09/2024

- Add `DataKeep.Enums`
- Default `logLevel` is now `DataKeep.Enums.LogLevel.Warn`
- Add `store:Identify()`
- Add `store:RemoveKeep()`
- Add `:LoadKeep()` retrying
- Fix `.GetStore()` returning wrong cached value
- Functions made only for specific keep type are only visible for that type
- Types are `--!strict`

### Breaking Changes

- Proper promise handling on loading, see basic usage docs
- `DataKeep.LoadMethods` -> `DataKeep.Enums.LoadMethod`
- Added customization of the verbosity of the logging via `DataKeep.Enums.LogLevel`

## [version 4.1.0](https://github.com/noahrepublic/DataKeep/releases/tag/v4.1.0): 10/22/2024

- Add DataKeep.SetConfig()

## [version 4.0.0](https://github.com/noahrepublic/DataKeep/releases/tag/v4.0.0): 10/11/2024

- [Types Rewrite](https://github.com/noahrepublic/DataKeep/pull/32)

### Breaking Changes

- Changed `globalUpdate.ID` -> `globalUpdate.Id`
- DataKeep:LoadStore() requires wrapper as third parameter (for strict types)
- Default Wrapper now moved to `DataKeep.Wrapper`
- `CriticalStateSignal` and `IssueSignal` moved to `DataKeep.CriticalStateSignal` and `DataKeep.IssueSignal`
- `.CriticalState` -> `.IsCriticalState`

## [version 3.2.1](https://github.com/noahrepublic/DataKeep/releases/tag/v3.2.1): 09/29/2024

- Fixed no waiting between failed saves

## [version 3.2.0](https://github.com/noahrepublic/DataKeep/releases/tag/v3.2.0): 08/23/2024

- Fixes [#21](https://github.com/noahrepublic/DataKeep/issues/21)
- Adds Steal option to .LoadMethods
- ForceLoad now waits for previous keep to save data
- :ViewKeep() now correctly calls :GetAsync() and :GetVersionAsync()
- Adds keep:Destroy() for cleaning :ViewKeep()
- Adds TestEZ definitions
- Adds more tests
- Fixed global update edge case
- Cancel `:LoadKeep` when server closing
- Fix infinite session stealing

## [version 3.1.2](https://github.com/noahrepublic/DataKeep/releases/tag/v3.1.2): 05/28/2024

- [Fix a few things](https://github.com/noahrepublic/DataKeep/pull/20)
- Fix for [#22](https://github.com/noahrepublic/DataKeep/pull/23)
- [`:SetAsync()` in mock store should deep copy value](https://github.com/noahrepublic/DataKeep/pull/26)

## [version 3.1.1](https://github.com/noahrepublic/DataKeep/releases/tag/v3.1.1): 03/17/2024

### Fixed

- LoadCount not incrementing

### Added

- Class implementation to Usage docs

## [version 3.1.0](https://github.com/noahrepublic/DataKeep/releases/tag/v3.1.0): 03/17/2024

### Fixed

- Mock detection fix

### Slight Breaking Change

- GetStore now waits for mockstore detection to finish. Players.PlayerAdded events may fire before getstore is ready. Use a loop of current players first. (See Example)

## [version 3.0.5](https://github.com/noahrepublic/DataKeep/releases/tag/v3.0.5): 02/13/2024

### Fixed

- GlobalUpdates returning nil causing an error

## [version 3.0.4](https://github.com/noahrepublic/DataKeep/releases/tag/v3.0.4): 01/21/2024

### Fixed

- Impartial saving issues from Roblox's :UpdateAsync() not working as intended

## [version 3.0.3](https://github.com/noahrepublic/DataKeep/releases/tag/v3.0.3): 01/06/2024

### Fixed

- Mockstore not returning version key
- Mockstore yield detection flagged false
- .Mock missing API

## [version 3.0.2](https://github.com/noahrepublic/DataKeep/releases/tag/v3.0.2): 01/01/2024

### Fixed

- .Mock erroring due to no ‘Wrapper’

## [version 3.0.1](https://github.com/noahrepublic/DataKeep/releases/tag/v3.0.1): 12/22/2023

### Fixed

- Default Wrapper error relating to new API
- Docs

## [version 3.0.0](https://github.com/noahrepublic/DataKeep/releases/tag/v3.0.0): 12/22/2023

### Added

- Documented IssueSignal, CriticalState, & CriticalStateSignal
- Added 'Saving' signal to Keep
- Mockstore didyield detection for more accurate development testing

### Breaking Changes

- DataKeep.Wrapper is now: DataStore.Wrapper (independant wrappers supported)
- OnRelease -> Releasing (signal) to address [#13](https://github.com/noahrepublic/DataKeep/issues/13)
- [#13](https://github.com/noahrepublic/DataKeep/issues/13) Releasing, and Saving signals now pass a promise to track the state

### Fixed

- Wrapper type warning

## [version 2.1.1](https://github.com/noahrepublic/DataKeep/releases/tag/v2.1.1): 12/17/2023

### Fixed

- ViewKeep :Save not working, replaced with :Overwrite()

### Added

- ViewKeep :Overwrite()

## [version 2.1.1](https://github.com/noahrepublic/DataKeep/releases/tag/v2.1.1): 12/05/2023

### Fixes

- Merged PR [#12](https://github.com/noahrepublic/DataKeep/pull/12)

## [version 2.1.0](https://github.com/noahrepublic/DataKeep/releases/tag/v2.1.0): 11/30/2023

### Added

- Store.validate() for validating data before saving ex: type guards

## [version 2.0.0](https://github.com/noahrepublic/DataKeep/releases/tag/v2.0.0): 11/28/2023

### API Breaking Change

:AttachSave() -> :PreSave() & :PreLoad()

Allows for more control and not limited to just compression/decompression but transforming the data however.

## [version 1.3.0 & 1.3.1](https://github.com/noahrepublic/DataKeep/releases/tag/v1.3.1): 11/27/2023

(version skip due to small patch)

### Added

- [Finally added compression 'plugins'](https://github.com/noahrepublic/DataKeep/issues/2)

## [version 1.2.2](https://github.com/noahrepublic/DataKeep/releases/tag/v1.2.2): 11/21/2023

### Fixed

- 'cannot resume dead coroutine' error on release
- Fixed UpdatedAsync accidentally yielding causing a failure to save

### Improved

- OnRelease fires quicker
- Finished issue signal implementation, and code reused

## [version 1.2.1](https://github.com/noahrepublic/DataKeep/releases/tag/v1.2.1): 11/16/2023

### Fixed

- Data not saving
- Basic Usage example

### Improved

- Reverted to an older method that works better for splitting up workload

## [version 1.2.0](https://github.com/noahrepublic/DataKeep/releases/tag/v1.2.0): 11/07/2023

### Added

- WriteLib functionality
- Default WriteLib

### Fixed

- OnRelease fire bug

### Improved

- Cleanups

## [version 1.1.9](https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.9): 11/1/2023

### Fixed

- Critcal bug where passing a store info would be ignored

## [version 1.1.8](https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.8): 10/27/2023

### Added

- MetaData reconciles

### Improved

- Quicker shutdown saves/releases
- Promise caching on release

### Fixed

- Coroutine dead?

## [version 1.1.7](https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.7): 10/25/2023

### Implemented

- CriticalState
- IssueSignal

### Improved

- Promise caching + Keep caching
- Some API documentation
- Saving loop on shutdown

(version skip, just was a bad build)

## [version 1.1.5](https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.5): 10/22/2023

### Added

Keep.MetaData.LoadCount

### Fixed

Stablized Session Lock

## [version 1.1.4](https://github.com/noahrepublic/DataKeep/releases/tag/v1.1.4): 10/22/2023

### Added

Keep.MetaData.Created

### Improved

MockStore detection

### Fixed

Session locked state
