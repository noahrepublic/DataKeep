# DataKeep

## [version 2.1.1](https://github.com/noahrepublic/DataKeep/releases/tag/v2.1.1): 12/17/2023

## **API Breaking Change**

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

API Breaking Change

:AttachSave -> :PreSave & :PreLoad

Allows for more control and not limited to just compression/decompression but transforming the data however.

## [version 1.3.0 & 1.3.1](https://github.com/noahrepublic/DataKeep/releases/tag/v1.3.1): 11/27/2023

(version skip due to small patch)

### Added

- Finally added compression 'plugins' see https://github.com/noahrepublic/DataKeep/issues/2
    :AttachToSave()

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