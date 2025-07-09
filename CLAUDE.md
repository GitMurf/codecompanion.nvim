# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CodeCompanion.nvim is an AI-powered coding assistant plugin for Neovim. It supports multiple LLM providers and offers features like chat buffers, inline code generation, tools/agents for automation, and prompt chaining workflows.

## Development Commands

```bash
# Run all checks (format, docs, test)
make all

# Format code with stylua
make format

# Run full test suite
make test

# Run specific test file
make test_file FILE=path/to/test.lua

# Generate documentation
make docs

# Documentation site (requires Node.js)
cd doc
npm install
npm run dev      # Development server
npm run build    # Build documentation
```

## Project Structure

```
codecompanion.nvim/
├── lua/codecompanion/
│   ├── init.lua              # Plugin entry point
│   ├── config.lua            # Default configuration
│   ├── schema.lua            # Adapter validation schemas
│   ├── types.lua             # Type annotations
│   ├── adapters/             # LLM provider integrations
│   │   ├── anthropic.lua
│   │   ├── openai.lua
│   │   └── ...
│   ├── strategies/           # Core interaction modes
│   │   ├── chat/            # Chat buffer implementation
│   │   └── inline/          # Direct code generation
│   ├── providers/           # Integration providers (Telescope, FZF)
│   ├── utils/               # Utility functions
│   └── extensions/          # Extension system
├── tests/                   # Test files
├── doc/                     # VitePress documentation
└── codecompanion-workspace.json  # Workspace definitions
```

## Architecture & Patterns

**Design Patterns:**
- **Adapter Pattern**: Unified interface for LLM providers in `/lua/codecompanion/adapters/`
- **Strategy Pattern**: Different interaction modes (chat, inline, cmd) in `/lua/codecompanion/strategies/`
- **Event-Driven**: Extensible through subscribers and watchers

**Key Components:**
- `config.lua`: Central configuration with defaults
- `schema.lua`: Validation for adapter configurations
- `adapters/`: Each adapter implements a standard interface (complete, stream, tools)
- `strategies/chat/`: Complex chat buffer with references, tools, and streaming
- `utils/keymaps.lua`: Centralized keymap management
- `extensions/`: Hooks for extending functionality

## Development Guidelines

**Code Style:**
- Use stylua for formatting (configured in `stylua.toml`)
- 120 character line width
- 2 space indentation
- Type annotations in `types.lua` using EmmyLua format

**Testing:**
- Framework: Mini.Test
- Run tests before commits
- Add tests for new features/bug fixes
- Visual regression tests for UI changes
- Test files go in `/tests/` directory

**Logging:**
- Use `local log = require("codecompanion.utils.log")`
- Set `log_level = "DEBUG"` in config for debugging
- Logs stored in `vim.fn.stdpath("state") .. "/codecompanion.log"`

**Error Handling:**
- Always validate adapter responses
- Use `pcall` for external calls
- Provide helpful error messages to users

## Working with CodeCompanion

**Using Workspaces:**
- Define workspaces in `codecompanion-workspace.json`
- Use VectorCode tool to search project context
- Workspaces enhance LLM understanding of your codebase

**Debugging Requests:**
```lua
-- Enable debug logging
require("codecompanion").setup({
  opts = {
    log_level = "DEBUG",
  }
})
```

For request/response debugging, use mitmproxy as documented in CONTRIBUTING.md.

## Common Patterns

**Adding a New Adapter:**
1. Create file in `/lua/codecompanion/adapters/`
2. Implement required methods: `complete()`, `stream()`, `tools()` (optional)
3. Add schema validation in `schema.lua`
4. Add tests in `/tests/adapters/`

**Adding a New Tool:**
1. Create tool definition with schema
2. Implement system prompt and function
3. Add to adapter's tools capability
4. Test with chat buffer

**Debugging Issues:**
1. Enable debug logging
2. Check logs at `vim.fn.stdpath("state") .. "/codecompanion.log"`
3. Use `:checkhealth codecompanion`
4. Test with minimal configuration

## Environment Setup

**Requirements:**
- Neovim >= 0.10.0
- plenary.nvim
- nvim-treesitter
- mini.nvim (for testing)

**Example Development Config:**
```lua
-- Use minimal.lua for testing
nvim --clean -u minimal.lua
```

## Quick Tips

- Always run `make format` before commits
- Test changes with multiple adapters
- Check CI status - tests run on Ubuntu with Neovim v0.11.0 and nightly
- Use type annotations for better IDE support
- Follow existing patterns when adding features
- Reference line numbers as `file_path:line_number` format