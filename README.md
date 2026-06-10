# Claude Usage (macOS menu bar)

A tiny menu bar app showing your live Claude Code usage — 5-hour session %, weekly %,
and weekly Opus % with reset times. Same numbers as `/usage` inside Claude Code.

## How it works

- Reads the Claude Code OAuth token from the macOS Keychain (service
  `Claude Code-credentials`). **Read-only** — it never refreshes or rewrites the
  token, so it can't disturb your Claude Code login.
- Polls `https://api.anthropic.com/api/oauth/usage` (the endpoint Claude Code's
  `/usage` uses) every 60 s (configurable: 30 s – 5 min).
- Menu bar shows a gauge icon + current session %. Click for the popover with
  progress bars and reset countdowns.

## Features

- Session (5h), weekly, and weekly-Opus utilization with reset times
- Color-coded bars (green < 50%, yellow < 80%, red ≥ 80%)
- Notification when session usage crosses a threshold (default 80%, once per window)
- Launch at login (works when running the built `.app`)
- No Dock icon (menu bar only)

## Requirements

- macOS 14+ (Sonoma)
- Claude Code CLI signed in (subscription OAuth)
- Xcode 15+ to build (SwiftUI/AppKit frameworks require the full Xcode toolchain)

## Build & run

```bash
make app    # builds dist/ClaudeUsage.app (release, ad-hoc signed)
make run    # build + launch
make test   # unit tests
```

On first launch macOS asks for keychain access — click **Always Allow**.

To stop the app: click the menu bar item → power button, or `pkill ClaudeUsage`.

## Project layout

```
Sources/ClaudeUsage/
  App/        entry point, NSStatusItem + NSPopover wiring
  Core/       keychain reader, OAuth credentials, usage API client + models
  ViewModel/  polling view model, settings, notifications, launch-at-login
  UI/         SwiftUI popover
Tests/        decoding, credentials, notification-threshold tests
scripts/      app bundle assembly
```

## License

[MIT](LICENSE) — free to use, modify, redistribute, and sell. Just keep the
copyright and license notice in copies.
