# Claude Max Adapter for CodeCompanion.nvim

This adapter allows you to use your Claude Pro/Max subscription with CodeCompanion.nvim by leveraging your existing Claude Code authentication.

## Overview

The Claude Max adapter uses your Claude Code credentials to authenticate with Claude.ai. This allows you to:

- Use your existing Claude Pro/Max subscription without additional API costs
- Access Claude models with your subscription's usage limits (resets every 5 hours)
- Avoid managing API keys
- Seamlessly integrate with your existing Claude Code setup

## Prerequisites

1. **Install Claude Code**: Download and install Claude Code from https://claude.ai/download
2. **Authenticate Claude Code**: Open Claude Code and sign in with your Claude Pro/Max account
3. **Verify credentials**: Ensure the file `~/.claude/.credentials.json` exists

## Setup

1. Add the Claude Max adapter to your CodeCompanion configuration:

```lua
require("codecompanion").setup({
  adapters = {
    claude_max = require("codecompanion.adapters.claude_max"),
  },
  strategies = {
    chat = {
      adapter = "claude_max", -- Use claude_max as default
    },
  },
})
```

2. Start using CodeCompanion with your Claude Max subscription:

```vim
:CodeCompanionChat claude_max
```

The adapter will automatically use your Claude Code credentials.

## Commands

- `:CodeCompanionChat claude_max` - Start a chat with Claude Max

## Token Management

The adapter uses Claude Code's credentials stored in `~/.claude/.credentials.json`.

The credentials include:
- Access token (for API requests)
- Refresh token (for renewing expired access tokens)
- Expiration time
- Subscription type (Pro/Max)

**Note**: The adapter will automatically refresh expired tokens using the refresh token from Claude Code. If token refresh fails, you'll need to open Claude Code to re-authenticate.

## Checking Authentication Status

The adapter provides a status method to check if you're authenticated:

```lua
local adapter = require("codecompanion.adapters.claude_max")
adapter:status()
```

## Troubleshooting

1. **No Claude Code credentials found**: Make sure Claude Code is installed and you've signed in
2. **Token expired errors**: The adapter will automatically refresh tokens. If this fails, open Claude Code to re-authenticate
3. **Authentication fails**: Check that `~/.claude/.credentials.json` exists and is readable
4. **Enable debug logging**: Set `log_level = "DEBUG"` in your CodeCompanion config

## Technical Details

- Uses Claude Code's OAuth tokens stored in `~/.claude/.credentials.json`
- Automatically refreshes expired tokens using the OAuth refresh token
- Adds the required `anthropic-beta: oauth-2025-04-20` header for OAuth authentication
- Removes `x-api-key` header to avoid conflicts with OAuth authentication
- Injects system prompt to identify as Claude Code (required by Anthropic's OAuth API)

## How It Works

This adapter works by:
1. Reading your existing Claude Code OAuth tokens from `~/.claude/.credentials.json`
2. Automatically refreshing expired tokens using the OAuth refresh endpoint
3. Adding the correct headers to API requests:
   - `Authorization: Bearer <token>`
   - `anthropic-beta: oauth-2025-04-20`
4. Removing any API key headers that might conflict
5. Injecting "You are Claude Code" system prompt (required for OAuth tokens)
6. Using the same request format as Claude Code

## Limitations

- Requires Claude Code to be installed and authenticated initially
- If token refresh fails, you must re-authenticate through Claude Code
- Usage is subject to your Claude Pro/Max subscription limits
- OAuth tokens are restricted to Claude Code usage (hence the system prompt injection)

## Security Considerations

- Credentials are shared with Claude Code (stored in `~/.claude/.credentials.json`)
- Never share your credentials file or tokens
- The adapter only reads existing credentials, it doesn't modify them