# Vibe Island OSS

An open-source macOS notch and top-bar companion for AI coding agents.

The goal is to build a native Swift app that can monitor local agent sessions, surface permission requests and questions, and jump back into the right terminal or editor context without leaving flow.

## Status

Initial native scaffold is in place. The repository now contains a buildable macOS Swift package with:

- `VibeIslandCore` for shared event and session state logic
- `VibeIslandApp` for the SwiftUI and AppKit shell
- a demo Unix-socket bridge transport between the app and a local event source
- core tests for session state transitions

## Product Direction

- Native macOS app built with SwiftUI and AppKit where needed.
- Local-first communication over Unix sockets or equivalent IPC.
- Support multiple coding agents over time, starting with one narrow integration.
- Focus on interaction, not just passive monitoring.

## Initial Milestones

1. `v0.1` Single-agent MVP with mocked events and overlay UI.
2. `v0.2` Real hook integration, approval flow, and question answering.
3. `v0.3` Terminal jump, multi-session state, and external display behavior.
4. `v0.4` Multi-agent adapters and install/setup automation.

## Getting Started

```bash
swift test
swift build
open Package.swift
```

Open the package in Xcode to run the macOS app target with the preview overlay and mock event stream.

The app now boots a demo bridge on a local Unix socket under `/tmp` and consumes session events through the same transport shape we can later reuse for real CLI adapters.

## Repository Layout

- `Package.swift` Swift package entry point for the app and shared core module.
- `Sources/VibeIslandCore` Shared models, events, mock scenario, and session state reducer.
- `Sources/VibeIslandCore` also contains the wire protocol, local socket client, and demo bridge server.
- `Sources/VibeIslandApp` SwiftUI app shell, menu bar entry, and overlay panel controller.
- `Tests/VibeIslandCoreTests` Core logic tests.
- `docs/product.md` Product scope, MVP boundary, and roadmap.
- `docs/architecture.md` System shape, event flow, and engineering decisions.

## Principles

- Keep the app local-first. No server dependency for core behavior.
- Build narrow slices end to end before adding more integrations.
- Prefer native platform APIs over cross-platform abstractions.
- Treat hooks, IPC, and focus-switching behavior as first-class engineering concerns.

## Next Step

Replace the in-process mock bridge with a real local event transport and wire the first CLI adapter end to end.
