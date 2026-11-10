# Claude Usage widget for macOS

A desktop widget that shows your Claude plan limits at a glance, the same numbers as Claude's usage page:

- **Current session** (5-hour window)
- **Weekly · All models**
- **Per-model weekly limits** (e.g. Fable)

Small and medium sizes. Bars turn orange near the limit and red at the limit.

> Unofficial. Not made by or affiliated with Anthropic.

## Install

Requirements: macOS 14+, [Homebrew](https://brew.sh), and [Claude Code](https://claude.com/claude-code) installed and logged in (Pro/Max plan).

```sh
brew install kostiantyn-kaniuka/claude-usage/claude-usage && claude-usage install
```

Then right-click the desktop → **Edit Widgets…** → search **Claude Usage** → drag it onto the desktop.

A small **✱ 74%** item appears in the menu bar. That's the helper that keeps the widget updated (every 5 minutes, and at login).

### "Your Command Line Tools (CLT) does not support macOS …"

Your Apple Command Line Tools are older than your macOS. Update them, then run the install line again:

```sh
sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install
```

## How it works & privacy

- The helper app reads **your own** Claude Code login from your Mac's Keychain and asks `api.anthropic.com` for your usage, the same request Claude Code's `/usage` makes. The token is used only for that HTTPS request: never logged, never saved, never sent anywhere else.
- It saves only the percentages and reset times to `~/Library/Application Support/ClaudeUsageWidget/usage.json`.
- The widget is sandboxed and can only read that one file. It never sees your login.
- The usage endpoint is not a public Anthropic API and may change without notice.
- If the widget says **"Open Claude Code to refresh login"**, run Claude Code once and it will recover.

## Update / uninstall

```sh
brew upgrade claude-usage && claude-usage install   # update
claude-usage uninstall && brew uninstall claude-usage   # remove
```

## Building from source

`./build.sh` builds `dist/ClaudeUsage.app` with just the Command Line Tools. If you have Xcode, `xcodegen generate` creates an Xcode project from `project.yml`.
