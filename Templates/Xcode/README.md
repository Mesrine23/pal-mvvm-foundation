# Xcode file templates

Custom **File Templates** that scaffold Pal's canonical patterns, so *New File…* offers a **Pal** section.

| Template | Generates |
|---|---|
| **Use Case** | `‹Name›UseCaseProtocol` + `‹Name›UseCase` (single `execute`, constructor-injected dependency). Name the file `FetchUsersUseCase`. |
| **View Model** | `@MainActor @Observable final class ‹Name›` holding a `Loader`, loading via an injected use case. Name the file `UsersListViewModel`. |
| **Coordinator** | `@MainActor final class ‹Name›` owning a typed `Router`, implementing the screens' `NavigationDelegate`s as one-liners, and doubling as the destination factory (`view(for:)` exhaustive switch). Name the file `UsersCoordinator`. Split out a `‹Feature›DestinationFactory` when it grows — see [PalNavigation's coordinator triangle](../../Documentation/Products/PalNavigation.md). |

The file name you type becomes the type name — `___FILEBASENAME___` — so a "Use Case" file named `FetchUsersUseCase` yields `FetchUsersUseCaseProtocol` + `FetchUsersUseCase`.

## Install

Copy the templates into Xcode's user template directory, then restart Xcode:

```bash
DEST="$HOME/Library/Developer/Xcode/Templates/File Templates/Pal"
mkdir -p "$DEST"
cp -R "Templates/Xcode/Pal/." "$DEST/"
```

They then appear under **File ▸ New ▸ File from Template… ▸ Pal**. Fill the `<#placeholders#>` (⇥ jumps between them).

## Uninstall

```bash
rm -rf "$HOME/Library/Developer/Xcode/Templates/File Templates/Pal"
```
