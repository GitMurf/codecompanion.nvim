--[[
Uses Tree-sitter to parse a given file and extract symbol types and names. Then
displays those symbols in the chat buffer as references. To support tools
and agents, start and end lines for the symbols are also output.

Heavily modified from the awesome Aerial.nvim plugin by stevearc:
https://github.com/stevearc/aerial.nvim/blob/master/lua/aerial/backends/treesitter/init.lua
--]]
local config = require("codecompanion.config")
local log = require("codecompanion.utils.log")
local path = require("plenary.path")
local util = require("codecompanion.utils")

local fmt = string.format
local get_node_text = vim.treesitter.get_node_text --[[@type function]]

local CONSTANTS = {
  NAME = "Symbols",
  PROMPT = "Select symbol(s)",
}

---Get the range of two nodes
---@param start_node TSNode
---@param end_node TSNode
local function range_from_nodes(start_node, end_node)
  local row, col = start_node:start()
  local end_row, end_col = end_node:end_()
  return {
    lnum = row + 1,
    end_lnum = end_row + 1,
    col = col,
    end_col = end_col,
  }
end

---Return when no symbols query exists
local function no_query(ft)
  util.notify(
    fmt("There are no Tree-sitter symbol queries for `%s` files yet. Please consider making a PR", ft),
    vim.log.levels.WARN
  )
end

---Return when no symbols have been found
local function no_symbols()
  util.notify("No symbols found in the given file", vim.log.levels.WARN)
end

local providers = {
  ---The default provider
  ---@param SlashCommand CodeCompanion.SlashCommand
  ---@return nil
  default = function(SlashCommand)
    local default = require("codecompanion.providers.slash_commands.default")
    return default
      .new({
        output = function(selection)
          SlashCommand:output({ relative_path = selection.relative_path, path = selection.path })
        end,
        SlashCommand = SlashCommand,
        title = CONSTANTS.PROMPT,
      })
      :find_files()
      :display()
  end,

  ---The Snacks.nvim provider
  ---@param SlashCommand CodeCompanion.SlashCommand
  ---@return nil
  snacks = function(SlashCommand)
    local snacks = require("codecompanion.providers.slash_commands.snacks")
    snacks = snacks.new({
      title = CONSTANTS.PROMPT .. ": ",
      output = function(selection)
        return SlashCommand:output({
          relative_path = selection.file,
          path = vim.fs.joinpath(selection.cwd, selection.file),
        })
      end,
    })

    snacks.provider.picker.pick({
      source = "files",
      prompt = snacks.title,
      confirm = snacks:display(),
      main = { file = false, float = true },
    })
  end,

  ---The Telescope provider
  ---@param SlashCommand CodeCompanion.SlashCommand
  ---@return nil
  telescope = function(SlashCommand)
    local telescope = require("codecompanion.providers.slash_commands.telescope")
    telescope = telescope.new({
      title = CONSTANTS.PROMPT,
      output = function(selection)
        return SlashCommand:output({
          relative_path = selection[1],
          path = selection.path,
        })
      end,
    })

    telescope.provider.find_files({
      prompt_title = telescope.title,
      attach_mappings = telescope:display(),
    })
  end,

  ---The Mini.Pick provider
  ---@param SlashCommand CodeCompanion.SlashCommand
  ---@return nil
  mini_pick = function(SlashCommand)
    local mini_pick = require("codecompanion.providers.slash_commands.mini_pick")
    mini_pick = mini_pick.new({
      title = CONSTANTS.PROMPT,
      output = function(selected)
        return SlashCommand:output(selected)
      end,
    })

    mini_pick.provider.builtin.files(
      {},
      mini_pick:display(function(selected)
        return {
          path = selected,
          relative_path = selected,
        }
      end)
    )
  end,

  ---The fzf-lua provider
  ---@param SlashCommand CodeCompanion.SlashCommand
  ---@return nil
  fzf_lua = function(SlashCommand)
    local fzf = require("codecompanion.providers.slash_commands.fzf_lua")
    fzf = fzf.new({
      title = CONSTANTS.PROMPT,
      output = function(selected)
        return SlashCommand:output(selected)
      end,
    })

    fzf.provider.files(fzf:display(function(selected, opts)
      local file = fzf.provider.path.entry_to_file(selected, opts)
      return {
        relative_path = file.stripped,
        path = file.path,
      }
    end))
  end,
}

---@class CodeCompanion.SlashCommand.Symbols: CodeCompanion.SlashCommand
local SlashCommand = {}

---@param args CodeCompanion.SlashCommandArgs
function SlashCommand.new(args)
  local self = setmetatable({
    Chat = args.Chat,
    config = args.config,
    context = args.context,
  }, { __index = SlashCommand })

  return self
end

---Execute the slash command
---@param SlashCommands CodeCompanion.SlashCommands
---@return nil
function SlashCommand:execute(SlashCommands)
  if not config.can_send_code() and (self.config.opts and self.config.opts.contains_code) then
    return log:warn("Sending of code has been disabled")
  end
  return SlashCommands:set_provider(self, providers)
end

---Output from the slash command in the chat buffer
---@param selected table The selected item from the provider { relative_path = string, path = string }
---@param opts? table
---@return nil
function SlashCommand:output(selected, opts)
  if not config.can_send_code() and (self.config.opts and self.config.opts.contains_code) then
    return log:warn("Sending of code has been disabled")
  end
  opts = opts or {}

  local ft = vim.filetype.match({ filename = selected.path })
  -- weird TypeScript bug for vim.filetype.match
  -- see: https://github.com/neovim/neovim/issues/27265
  if not ft then
    local base_name = vim.fs.basename(selected.path)
    local split_name = vim.split(base_name, "%.")
    if #split_name > 1 then
      local ext = split_name[#split_name]
      if ext == "ts" then
        ft = "typescript"
      end
    end
  end
  local content = path.new(selected.path):read()

  local query = vim.treesitter.query.get(ft, "symbols")

  if not query then
    return no_query(ft)
  end

  local parser = vim.treesitter.get_string_parser(content, ft)
  local tree = parser:parse()[1]

  local symbols = {}
  for _, matches, metadata in query:iter_matches(tree:root(), content) do
    local match = vim.tbl_extend("force", {}, metadata)
    for id, nodes in pairs(matches) do
      local node = type(nodes) == "table" and nodes[1] or nodes
      match = vim.tbl_extend("keep", match, {
        [query.captures[id]] = {
          metadata = metadata[id],
          node = node,
        },
      })
    end

    local name_match = match.name or {}
    local symbol_node = (match.symbol or match.type or {}).node

    if not symbol_node then
      goto continue
    end

    local start_node = (match.start or {}).node or symbol_node
    local end_node = (match["end"] or {}).node or start_node

    local kind = match.kind

    local kinds = {
      "Import",
      "Enum",
      "Module",
      "Class",
      "Struct",
      "Interface",
      "Method",
      "Function",
    }

    vim
      .iter(kinds)
      :filter(function(k)
        return kind == k
      end)
      :each(function(k)
        local node_kind = k
        local node_kind_text = node_kind:lower()
        local range = range_from_nodes(start_node, end_node)
        if name_match.node then
          local name = vim.trim(get_node_text(name_match.node, content)) or "<parse error>"
          ---@type { before_name: string[], after_name: string[] }
          local symbol_metadata = {
            before_name = {},
            after_name = {},
          }
          local full_text = ""

          -- Check if it's a single-line declaration
          if range.lnum == range.end_lnum and symbol_node then
            local start_row = symbol_node:start()
            local end_row = symbol_node:end_()
            if start_row == end_row then
              full_text = vim.trim(get_node_text(symbol_node, content))
            else
              full_text = ""
            end
          end

          if full_text == "" then
            -- Extract parameters for Functions and Methods
            -- Currently supports TypeScript and Lua
            if node_kind == "Function" or node_kind == "Method" then
              -- Handle parameters if they exist
              -- Always show empty parentheses for functions/methods without parameters
              local parameters_text = "()"
              if match.parameters and match.parameters.node then
                local parameters_node = vim.trim(get_node_text(match.parameters.node, content))
                if parameters_node and parameters_node ~= "" then
                  parameters_text = parameters_node
                end
              end
              table.insert(symbol_metadata.after_name, 1, parameters_text)
            end

            -- TypeScript specific handling
            if match.language and match.language == "typescript" then
              -- Handle `export` and `default` keywords for functions, interfaces and classes
              if match.export and match.export.node then
                table.insert(symbol_metadata.before_name, "export" .. " ")
              end
              if match.default and match.default.node then
                table.insert(symbol_metadata.before_name, "default" .. " ")
              end

              -- Interfaces and Type Aliases
              if node_kind == "Interface" then
                if match.symbol_keyword and match.symbol_keyword.node then
                  local symbol_keyword = vim.trim(get_node_text(match.symbol_keyword.node, content))
                  if symbol_keyword and symbol_keyword ~= "" then
                    table.insert(symbol_metadata.before_name, symbol_keyword .. " ")
                  end
                end

              -- Functions and Methods
              elseif node_kind == "Function" or node_kind == "Method" then
                -- Handle return type of the function/method
                -- symbol_metadata.return_type = ""
                local return_type_text = ""
                if match.return_type and match.return_type.node then
                  local return_type_node = vim.trim(get_node_text(match.return_type.node, content))
                  if return_type_node and return_type_node ~= "" then
                    return_type_text = return_type_node
                  end
                end
                table.insert(symbol_metadata.after_name, 2, return_type_text)

                -- Handle detection of abstract methods
                if match.abstract_method and match.abstract_method.node then
                  table.insert(symbol_metadata.before_name, "abstract" .. " ")
                end

                -- Handle access modifiers such as `public`, `private`, `protected`
                if match.acc_modifier and match.acc_modifier.node then
                  local acc_modifier_text = vim.trim(get_node_text(match.acc_modifier.node, content))
                  if acc_modifier_text and acc_modifier_text ~= "" then
                    table.insert(symbol_metadata.before_name, acc_modifier_text .. " ")
                  end
                end

                -- Handle detection of static methods
                if match.static and match.static.node then
                  table.insert(symbol_metadata.before_name, "static" .. " ")
                end

                -- Handle detection of readonly methods
                if match.read_only and match.read_only.node then
                  table.insert(symbol_metadata.before_name, "readonly" .. " ")
                end

                -- Handle generic type parameters if they exist
                if match.type_parameters and match.type_parameters.node then
                  local type_parameters_text = vim.trim(get_node_text(match.type_parameters.node, content))
                  if type_parameters_text and type_parameters_text ~= "" then
                    table.insert(symbol_metadata.after_name, 1, type_parameters_text)
                  end
                end

                -- Handle detection of arrow functions (var vs const vs let keyword)
                -- For regular functions, this will be `function`
                if match.symbol_keyword and match.symbol_keyword.node then
                  -- If arrow function, add " = " before parameters "()"
                  if match.arrow and match.arrow.node then
                    table.insert(symbol_metadata.after_name, 1, " = ")
                    -- Add " => " after return type
                    table.insert(symbol_metadata.after_name, " => {")
                    -- Handle detection of the async keyword for arrow functions
                    if match.async and match.async.node then
                      table.insert(symbol_metadata.after_name, 2, "async" .. " ")
                    end
                  else
                    -- Handle detection of the async keyword for regular functions
                    if match.async and match.async.node then
                      table.insert(symbol_metadata.before_name, "async" .. " ")
                    end
                  end

                  -- Add in the const/let/var keyword for arrow functions and function for regular functions
                  local symbol_keyword = vim.trim(get_node_text(match.symbol_keyword.node, content))
                  if symbol_keyword and symbol_keyword ~= "" then
                    table.insert(symbol_metadata.before_name, symbol_keyword)
                    -- If a generator function, do NOT add a space after the function keyword
                    if match.generator and match.generator.node then
                      -- Do nothing... asterisk is added below directly to function*
                    else
                      table.insert(symbol_metadata.before_name, " ")
                    end
                  end
                end

                -- Handle async for methods
                if node_kind == "Method" then
                  if match.async and match.async.node then
                    table.insert(symbol_metadata.before_name, "async" .. " ")
                  end
                end

                -- Handle detection of generator functions*
                if match.generator and match.generator.node then
                  if node_kind == "Method" then
                    table.insert(symbol_metadata.before_name, "*")
                  else
                    table.insert(symbol_metadata.before_name, "*" .. " ")
                  end
                end

              -- Classes
              elseif node_kind == "Class" then
                -- Handle detection of the abstract keyword
                if match.abstract_class and match.abstract_class.node then
                  table.insert(symbol_metadata.before_name, "abstract" .. " ")
                end

                -- Add class symbol keyword
                if match.symbol_keyword and match.symbol_keyword.node then
                  local symbol_keyword = vim.trim(get_node_text(match.symbol_keyword.node, content))
                  if symbol_keyword and symbol_keyword ~= "" then
                    table.insert(symbol_metadata.before_name, symbol_keyword .. " ")
                  end
                end

                -- Handle detection of the extends or implements keywords
                if match.inherit and match.inherit.node then
                  local inherit_text = vim.trim(get_node_text(match.inherit.node, content))
                  if inherit_text and inherit_text ~= "" then
                    table.insert(symbol_metadata.after_name, " " .. inherit_text)
                  end
                end
              end
            end
          end

          -- Use full text for single-line declarations, otherwise use the formatted version
          local symbol_text = full_text
          if symbol_text == "" then
            -- -- TEMP: TODO: Remove this... testing purposes only
            -- symbol_metadata.before_name = {}
            -- symbol_metadata.after_name = {}

            -- loop through before_name and add only items that are not empty
            local before_name = table.concat(vim.tbl_filter(function(v)
              return v ~= ""
            end, symbol_metadata.before_name), "")
            if not before_name then
              before_name = ""
            end
            -- if before_name ~= "" then
            --   before_name = before_name .. ""
            -- end

            -- loop through after_name and add only items that are not empty
            local after_name = table.concat(vim.tbl_filter(function(v)
              return v ~= ""
            end, symbol_metadata.after_name), "")
            if not after_name then
              after_name = ""
            end

            symbol_text = fmt(
              "%s%s%s",
              before_name,
              name,
              after_name
            )
          end

          -- TypeScript specific handling for normalizing the final node_kind_text
          if match.language and match.language == "typescript" then
            if node_kind == "Interface" then
              if match.symbol_keyword and match.symbol_keyword.node then
                local symbol_keyword = vim.trim(get_node_text(match.symbol_keyword.node, content))
                if symbol_keyword and symbol_keyword ~= "" then
                  node_kind_text = symbol_keyword:lower()
                end
              end
            end
          end

          local final_text = fmt(
            "- %s: `%s` (from line %s to %s)",
            node_kind_text,
            symbol_text,
            range.lnum,
            range.end_lnum
          )

          table.insert(symbols, final_text)
        end
      end)

    ::continue::
  end

  if #symbols == 0 then
    return no_symbols()
  end

  local id = "<symbols>" .. (selected.relative_path or selected.path) .. "</symbols>"
  content = table.concat(symbols, "\n")

  -- Workspaces allow the user to set their own custom description which should take priority
  local description
  if selected.description then
    description = fmt(
      [[%s

```%s
%s
```]],
      selected.description,
      ft,
      content
    )
  else
    description = fmt(
      [[Here is a symbolic outline of the file `%s` (with filetype `%s`). I've also included the line numbers that each symbol starts and ends on in the file:

%s

Prompt the user if you need to see more than the symbolic outline.
]],
      selected.relative_path or selected.path,
      ft,
      content
    )
  end

  self.Chat:add_message({
    role = config.constants.USER_ROLE,
    content = description,
  }, { reference = id, visible = false })

  self.Chat.references:add({
    source = "slash_command",
    name = "symbols",
    id = id,
  })

  if opts.silent then
    return
  end

  util.notify(fmt("Added the symbols for `%s` to the chat", vim.fn.fnamemodify(selected.relative_path, ":t")))
end

return SlashCommand
