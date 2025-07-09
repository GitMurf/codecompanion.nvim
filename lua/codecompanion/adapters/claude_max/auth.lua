local M = {}

local Path = require("plenary.path")
local curl = require("plenary.curl")
local log = require("codecompanion.utils.log")

---Example Claude Code credentials file format:
-- {
--     "claudeAiOauth": {
--         "accessToken": "sk-ant-oat...QAA",
--         "refreshToken": "sk-ant-ort...XAAA",
--         "expiresAt": 1752102432019,
--         "scopes": [
--             "user:inference",
--             "user:profile"
--         ],
--         "subscriptionType": "max"
--     }
-- }

---Example OAuth token response format:
-- {
--   "token_type": "Bearer",
--   "access_token": "sk-ant-oat...gAA",
--   "expires_in": 28800, -- seconds until expiry (8 hours)
--   "refresh_token": "sk-ant-ort...KAAA",
--   "scope": "user:inference user:profile",
--   "organization": {
--     "uuid": "8e6ee0b8...dbb9",
--     "name": "shawn...@gmail.com's Organization"
--   },
--   "account": {
--     "uuid": "5fbe103c...4c32",
--     "email_address": "shawn...@gmail.com"
--   }
-- }

---@alias ClaudeCodeCredentialsOauth { accessToken: string, refreshToken: string, expiresAt: number, scopes: string[], subscriptionType: string }
---@alias ClaudeCodeCredentials { claudeAiOauth: ClaudeCodeCredentialsOauth }

---Claude Code OAuth response format when refreshing tokens
---expires_in: is the number of seconds until the token expires
---@alias ClaudeCodeOauthResponse { token_type: string, access_token: string, expires_in: number, refresh_token: string, scope: string, organization: { uuid: string, name: string }, account: { uuid: string, email_address: string } }

---URL encode function for query parameters only
local function url_encode(str)
  str = tostring(str)
  str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str
end

---OAuth configuration: using Claude Code auth token to get refresh access tokens
M.config = {
  claude_code_credentials = vim.fn.expand("~/.claude/.credentials.json"),
  token_url = "https://api.anthropic.com/v1/oauth/token",
  -- Claude Code client ID
  client_id = "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
}

---Load Claude Code credentials from the specified file
---@return ClaudeCodeCredentialsOauth|nil
function M.load_claude_code_credentials()
  local cred_path = Path:new(M.config.claude_code_credentials)
  if not cred_path:exists() then
    vim.notify("Claude Code credentials file does not exist. Aborting!", vim.log.levels.ERROR)
    log:error("Claude Code credentials file does not exist: %s", cred_path:absolute())
    return nil
  end

  ---@type boolean, ClaudeCodeCredentials
  local ok, data = pcall(vim.json.decode, cred_path:read())
  if not ok then
    vim.notify("Failed to parse Claude Code credentials file. Aborting!", vim.log.levels.ERROR)
    log:error("Failed to parse Claude Code credentials file")
    return nil
  end

  if data.claudeAiOauth then
    ---@type ClaudeCodeCredentialsOauth
    local result = data.claudeAiOauth
    return result
  end

  vim.notify("No Claude Code OAuth data found in credentials file. Aborting!", vim.log.levels.ERROR)
  return nil
end

---Save updated tokens back to Claude Code credentials file
---@param accessToken string
---@param refreshToken string
---@param expiresAt number -- Unix timestamp in milliseconds
function M.save_claude_code_credentials(accessToken, refreshToken, expiresAt)
  local cred_path = Path:new(M.config.claude_code_credentials)

  ---Read existing file to preserve structure in case of other data
  ---@type ClaudeCodeCredentials
  local existing_data = {}
  if cred_path:exists() then
    local ok, data = pcall(vim.json.decode, cred_path:read())
    if ok then
      existing_data = data
    end
  end

  existing_data.claudeAiOauth.accessToken = accessToken
  existing_data.claudeAiOauth.refreshToken = refreshToken
  existing_data.claudeAiOauth.expiresAt = expiresAt

  cred_path:write(vim.json.encode(existing_data), "w")
  log:debug("Updated Claude Code credentials")
end

---Check if token is expired
---@param tokens ClaudeCodeCredentialsOauth
function M.is_token_expired(tokens)
  if not tokens or not tokens.expiresAt then
    return true
  end
  -- Convert milliseconds to seconds
  local tokenExpirationSeconds = tokens.expiresAt / 1000
  -- Add 5 minute buffer before expiry
  return os.time() > (tokenExpirationSeconds - (5 * 60))
end

---Refresh access token using Claude Code's refresh token
---@param refresh_token string
---@return ClaudeCodeCredentialsOauth|nil
function M.refresh_oauth_token(refresh_token)
  if not refresh_token then
    log:error("No refresh token provided")
    return nil
  end

  local response = curl.post({
    url = M.config.token_url,
    headers = {
      ["content-type"] = "application/x-www-form-urlencoded",
    },
    body = string.format(
      "grant_type=refresh_token&refresh_token=%s&client_id=%s",
      url_encode(refresh_token),
      -- Claude Code client ID
      url_encode(M.config.client_id)
    ),
    timeout = 10000,
  })

  if response.status ~= 200 then
    log:error("Failed to refresh token: %s", response.body)
    return nil
  end

  ---@type boolean, ClaudeCodeOauthResponse
  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    log:error("Failed to parse token refresh response")
    return nil
  end

  ---Convert response to our token format for saving to credentials file
  ---@type ClaudeCodeCredentialsOauth
  local tokens = {
    accessToken = data.access_token,
    refreshToken = data.refresh_token or refresh_token,
    expiresAt = (os.time() + (data.expires_in or 28800)) * 1000, -- Convert to milliseconds
    scopes = data.scope and vim.split(data.scope, " ") or { "user:inference", "user:profile" },
    subscriptionType = "max",
  }

  -- Save the refreshed token to Claude Code credentials file
  M.save_claude_code_credentials(tokens.accessToken, tokens.refreshToken, tokens.expiresAt)
  vim.notify("Successfully refreshed OAuth token", vim.log.levels.INFO)
  log:debug("Successfully refreshed OAuth token")

  return tokens
end

---Get valid access token (refresh if needed)
---@return string|nil accessToken Access token to authenticate with Anthropic API
function M.get_access_token()
  local tokens = M.load_claude_code_credentials()
  if not tokens then
    vim.notify("No OAuth tokens found. Please authenticate first.", vim.log.levels.WARN)
    log:warn("No OAuth tokens found. Please authenticate first.")
    return nil
  end

  if M.is_token_expired(tokens) then
    vim.notify("Access token expired, refreshing...", vim.log.levels.WARN)
    log:debug("Access token expired, refreshing...")
    local refreshed_token = M.refresh_oauth_token(tokens.refreshToken)
    if not refreshed_token then
      vim.notify("Failed to refresh token. Please re-authenticate with Claude Code.", vim.log.levels.ERROR)
      log:error("Failed to refresh token. Please re-authenticate with Claude Code.")
      return nil
    end
    tokens = refreshed_token
  end

  return tokens.accessToken
end

---Check authentication status
---@return boolean
function M.is_authenticated()
  local tokens = M.load_claude_code_credentials()
  return tokens ~= nil
end

return M
