# State Provider Documentation Overview

This directory explains the structure, responsibilities, and usage patterns for every major file in the `state_provider` package. Use these documents as a blueprint when integrating the toolkit into your own Flutter applications.

## Documentation map

| Document | Focus |
| --- | --- |
| [`core_bootstrap.md`](core_bootstrap.md) | Bootstrapping services that must be initialized before using the package. |
| [`data_layer.md`](data_layer.md) | API, connectivity, and logging data sources along with configuration helpers. |
| [`domain_layer.md`](domain_layer.md) | Immutable entities, value objects, and error/result abstractions. |
| [`presentation_layer.md`](presentation_layer.md) | Controllers and widgets that drive UI state handling and pagination. |
| [`utils_and_logging.md`](utils_and_logging.md) | Development-time logging utilities and sink customization. |
| [`testing.md`](testing.md) | Test suite overview plus instructions for running and extending coverage. |

## Quick start

1. Initialize shared services using `StateProviderBootstrap`.
2. Configure networking, logging, and connectivity in the data layer.
3. Model API responses with domain entities and `AppResult`/`AppError`.
4. Manage UI with pagination controllers, notifiers, and the provided widgets.
5. Extend or customize logging via pluggable sinks.
6. Keep the test suite green by running the commands listed in [`testing.md`](testing.md).
