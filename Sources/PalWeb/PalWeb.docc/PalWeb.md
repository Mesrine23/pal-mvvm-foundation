# ``PalWeb``

Embedded web content for pages (terms, help, docs): a `WKWebView` screen driving the familiar `ViewState`, with every navigation routed through an app-supplied policy.

## Overview

`WebScreen` (iOS) loads a page into ``WebPageModel`` — state, live title/progress, history flags — and asks the app's ``WebNavigationPolicy`` about each navigation: allow it, cancel it, or hand it to the external browser. OAuth deliberately stays out: sign-in uses `ASWebAuthenticationSession` app-side.

For the narrative guide, see the repository's `Documentation/Products/PalWeb.md`.

## Topics

### The screen

- ``WebScreen``

### The page model

- ``WebPageModel``

### Navigation policy

- ``WebNavigationPolicy``
- ``WebNavigationRequest``
- ``WebNavigationDecision``

### External links

- ``ExternalLinkOpener``
