; Zed tree-sitter highlights for VIBEE DSL

; Keywords
[
  "tool"
  "scene"
  "fn"
  "on"
  "struct"
  "agent"
  "machine"
] @keyword

[
  "enter"
  "exit"
  "callback"
  "message"
  "stay"
  "transition"
  "reply"
] @keyword.function

[
  "case"
  "if"
  "else"
  "match"
] @keyword.control

[
  "true"
  "false"
] @boolean

"nil" @constant

; Decorators
(decorator) @attribute
"@const" @attribute
"@import" @keyword

; Types
[
  "str"
  "int"
  "float"
  "bool"
  "list"
  "map"
  "any"
  "void"
] @type

(type_modifier) @type

; Definitions
(tool_definition
  name: (identifier) @function)

(scene_definition
  name: (identifier) @type)

(function_definition
  name: (identifier) @function)

(struct_definition
  name: (identifier) @type)

; Parameters
(parameter_definition
  name: (identifier) @variable.parameter)

(parameter
  name: (identifier) @variable.parameter)

; Expressions
(call_expression
  function: (identifier) @function)

(member_expression
  property: (identifier) @property)

; Literals
(string) @string
(escape_sequence) @string.escape
(number) @number
(identifier) @variable

; Operators
[
  "+"
  "-"
  "*"
  "/"
  "%"
  "=="
  "!="
  "<"
  ">"
  "<="
  ">="
  "&&"
  "||"
  "!"
  "<>"
  "|>"
  "->"
  "="
] @operator

; Punctuation
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ":"
  ","
  "."
] @punctuation.delimiter

; Comments
(comment) @comment
