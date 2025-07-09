local Anthropic = require("codecompanion.adapters.anthropic")
local auth = require("codecompanion.adapters.claude_max.auth")

---@class ClaudeMax.Adapter: Anthropic.Adapter
local ClaudeMaxAdapter = vim.deepcopy(Anthropic)

-- Override basic properties
ClaudeMaxAdapter.name = "claude_max"
ClaudeMaxAdapter.formatted_name = "Claude Max"

-- Remove API key requirement
ClaudeMaxAdapter.env = {}

-- Override headers to use OAuth
ClaudeMaxAdapter.headers = {
  ["content-type"] = "application/json",
  ["anthropic-version"] = "2023-06-01",
  ["anthropic-beta"] = "oauth-2025-04-20", -- Use OAuth beta header
  ["x-api-key"] = nil, -- Remove API key header
}

-- Add custom handlers
ClaudeMaxAdapter.handlers = vim.tbl_deep_extend("force", Anthropic.handlers, {
  ---Setup handler that checks for valid OAuth token
  ---@param self CodeCompanion.Adapter
  ---@return boolean
  setup = function(self)
    -- Call parent setup first
    local parent_success = Anthropic.handlers.setup(self)
    if not parent_success then
      return false
    end

    -- Check if authenticated
    if not auth.is_authenticated() then
      vim.notify(
        "Claude Max: Not authenticated. Please install and authenticate Claude Code first.",
        vim.log.levels.WARN
      )
      return false
    end

    -- Get access token
    local access_token = auth.get_access_token()
    if not access_token then
      vim.notify("Claude Max: Failed to retrieve access token. Please re-authenticate.", vim.log.levels.ERROR)
      return false
    end

    -- Set OAuth access token in headers
    self.headers["authorization"] = "Bearer " .. access_token

    return true
  end,

  ---Modify messages to add Claude Code identification
  ---@param self CodeCompanion.Adapter
  ---@param messages table
  ---@return table
  form_messages = function(self, messages)
    -- First call the parent form_messages
    local result = Anthropic.handlers.form_messages(self, messages)

    -- Add Claude Code identification as the first system message
    if not result.system then
      result.system = {}
    end

    -- Prepend the Claude Code identification
    table.insert(result.system, 1, {
      type = "text",
      text = "You are Claude Code, Anthropic's official CLI for Claude.",
      cache_control = nil,
    })

    return result
  end,
})

-- Custom schema
ClaudeMaxAdapter.schema = vim.tbl_deep_extend("force", Anthropic.schema, {
  -- Remove API key schema
  api_key = nil,
  -- Set default model to Opus
  model = {
    order = 1,
    mapping = "parameters",
    type = "enum",
    desc = "The model that will complete your prompt",
    default = "claude-opus-4-20250514",
    choices = Anthropic.schema.model.choices,
  },
})

-- Add status check method
function ClaudeMaxAdapter:status()
  if auth.is_authenticated() then
    local tokens = auth.load_claude_code_credentials()
    if tokens and tokens.expiresAt then
      local expires_at_seconds = tokens.expiresAt / 1000 -- Convert from milliseconds to seconds
      local ttl = expires_at_seconds - os.time()
      if ttl > 0 then
        local hours = math.floor(ttl / 3600)
        local minutes = math.floor((ttl % 3600) / 60)
        vim.notify(string.format("Claude Max: Authenticated (expires in %dh %dm)", hours, minutes), vim.log.levels.INFO)
      else
        -- vim.notify('Claude Max: Token expired, please open Claude Code to refresh', vim.log.levels.WARN)
        vim.notify("Claude Max: Token expired, refreshing token now...", vim.log.levels.WARN)
        auth.refresh_oauth_token(tokens.refreshToken)
      end
    else
      vim.notify("Claude Max: Authenticated", vim.log.levels.INFO)
    end
  else
    vim.notify("Claude Max: Not authenticated", vim.log.levels.WARN)
  end
end

return ClaudeMaxAdapter
