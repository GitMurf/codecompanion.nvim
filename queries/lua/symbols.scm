; Ref: https://github.com/stevearc/aerial.nvim/blob/master/queries/lua/aerial.scm
; MIT License

; Require statements at root, inside functions, tables etc.
(_(_
  name: (identifier) @name
  (#contains? @name "require")
  (#set! "language" "lua")
  (#set! "kind" "Import")
)) @symbol

; local function foo(bar)
(function_declaration
  name: (_) @name
  parameters: (_)? @parameters
  (#set! "language" "lua")
  (#set! "kind" "Function")
) @symbol

; local foo = function(bar)
; M.foo = function(bar)
(assignment_statement
  (variable_list
    name: (_) @name) @var_list
  (expression_list
    value: (function_definition
      parameters: (_)? @parameters
    ) @func_def
  ) @exp_list
  (#set! "language" "lua")
  (#set! "kind" "Function")
) @symbol

; Table => func: { foo = function(bar) end }
(field
  name: (identifier) @name
  value: (function_definition
    parameters: (_)? @parameters
  ) @func_def
  (#set! "language" "lua")
  (#set! "kind" "Function")
) @symbol
