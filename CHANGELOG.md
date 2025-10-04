## 1.0.0

* Introduced continuous integration workflow running `flutter analyze` and `flutter test --coverage` on every push/PR.
* Added widget coverage for `StateHandler` along with additional `ApiClient` and `LoggerService` unit tests.
* Refactored `LoggerService` to support injectable log sinks and automatic file rotation.
* Documented production checklist and raised package version for the first stable release.

## 0.0.1

* Initial release includes pagination tooling, ApiClient helpers, and connectivity widgets. (Updated to remove experimental caching layer and related types.)
