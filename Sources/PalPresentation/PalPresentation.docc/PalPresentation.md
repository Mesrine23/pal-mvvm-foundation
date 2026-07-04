# ``PalPresentation``

The per-screen contract every ViewModel uses: a four-case state machine, a presentable error, and owned async runners for plain and paginated content.

## Overview

A screen holds one ``Loader`` per independently-loadable section (or one ``PagedLoader`` for an infinite list) and its View switches on the loader's ``ViewState`` — killing the per-ViewModel `isLoading`/`showError` flag-zoo. Failures map to ``PresentableError`` at the boundary; cancellation never surfaces.

For the narrative guide, see the repository's `Documentation/Products/PalPresentation.md`.

## Topics

### State machine

- ``ViewState``
- ``PresentableError``
- ``PresentableErrorConvertible``

### Runners

- ``Loader``
- ``PagedLoader``
- ``Page``
