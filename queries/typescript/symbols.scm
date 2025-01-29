; Ref: https://github.com/stevearc/aerial.nvim/blob/master/queries/typescript/aerial.scm
; MIT License

; Imports
(
  (import_statement) @name
  (#set! "language" "typescript")
  (#set! "kind" "Import")
) @symbol

; Regular functions
(
  "export"? @export
  "default"? @default
  (_
    "async"? @async
    "function" @symbol_keyword
    "*"? @generator
    name: (identifier) @name
    (#has-parent? @name function_declaration generator_function_declaration)
    type_parameters: (_)? @type_parameters
    parameters: (_)? @parameters
    return_type: (_)? @return_type
  ) @symbol
  (#has-parent? @symbol export_statement program statement_block)
  (#set! "language" "typescript")
  (#set! "kind" "Function")
)

; Arrow functions
(
  "export"? @export
  (_
    ["var" "let" "const"] @symbol_keyword
    (variable_declarator
      name: (identifier) @name
      value: (arrow_function
        "async"? @async
        type_parameters: (_)? @type_parameters
        parameters: (_)? @parameters
        return_type: (_)? @return_type
      ) @arrow
    ) @var_declare
    (#has-parent? @var_declare lexical_declaration variable_declaration)
  ) @symbol
  (#has-parent? @symbol export_statement program statement_block)
  (#set! "language" "typescript")
  (#set! "kind" "Function")
)

; Classes
(
  "export"? @export
  "default"? @default
  (_
    "abstract"? @abstract_class
    "class" @symbol_keyword
    name: (type_identifier) @name
    (class_heritage
      (extends_clause
        value: (identifier)?
      )? @inherit
    )?
    (class_heritage
      (implements_clause
        (type_identifier)?
      )? @inherit
    )?
    (#has-parent? @name class_declaration abstract_class_declaration)
  ) @symbol
  (#has-parent? @symbol export_statement program)
  (#set! "language" "typescript")
  (#set! "kind" "Class")
)

; Class Methods
(_
  (accessibility_modifier)? @acc_modifier
  "abstract"? @abstract_method
  "async"? @async
  "*"? @generator
  name: (property_identifier) @name
  (#has-parent? @name method_definition abstract_method_signature)
  type_parameters: (_)? @type_parameters
  parameters: (_)? @parameters
  return_type: (_)? @return_type
  (#set! "language" "typescript")
  (#set! "kind" "Method")
) @symbol

; Arrow Functions in Class Properties
(public_field_definition
  (accessibility_modifier)? @acc_modifier
  "static"? @static
  "readonly"? @read_only
  name: (property_identifier) @name
  value: (arrow_function
    "async"? @async
    type_parameters: (_)? @type_parameters
    parameters: (_)? @parameters
    return_type: (_)? @return_type
  ) @arrow
  (#set! "language" "typescript")
  (#set! "kind" "Method")
) @symbol

; Interfaces and Type Aliases
(_
  ["interface" "type"] @symbol_keyword
  name: (type_identifier) @name
  (#has-parent? @name type_alias_declaration interface_declaration)
  (#set! "language" "typescript")
  (#set! "kind" "Interface")
) @symbol
