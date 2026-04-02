# Architecture Notes

## System Shape

The project will likely split into three layers:

1. `macOS app`
   Renders the notch or top-bar UI, owns state presentation, and handles user interaction.
2. `bridge`
   Receives agent events locally and exposes a stable event stream to the app.
3. `agent adapters`
   Translate tool-specific hooks or config into a shared event model.

## Initial Event Model

The shared model should support:

- session started
- session updated
- permission requested
- question asked
- session completed
- jump target updated

Each event should carry a stable session identifier, tool name, timestamps, and enough metadata to route approvals or focus changes.

## Likely Technologies

- SwiftUI for most UI composition
- AppKit for panel behavior, status item control, and activation policy edge cases
- Unix domain sockets or local stream IPC for app and bridge communication
- JSON event envelopes for debugging and adapter simplicity

## Current Demo Slice

The current scaffold keeps the bridge server inside the app process for convenience, but the app still talks to it over a Unix socket with newline-delimited JSON envelopes. That means the protocol and transport boundary are already real even though the helper has not been split into a separate process yet.

## Suggested Build Order

1. Define the shared event schema
2. Build a mock event publisher
3. Build the overlay UI against the mock stream
4. Add an interaction channel for approve and answer actions
5. Replace the mock source with one real adapter

## Open Questions

- Should the bridge live inside the app process first, or as a separate helper from day one?
- Which agent should be the first real integration target?
- How much terminal-jump accuracy is possible without private APIs?
- Which permissions are required for reliable focus restoration across terminals and IDEs?

## Engineering Rules

- Preserve a clean separation between UI state and transport concerns.
- Version the event schema early so adapters can evolve safely.
- Keep setup reversible when editing third-party tool config files.
- Add mock fixtures for every event type before wiring real integrations.
