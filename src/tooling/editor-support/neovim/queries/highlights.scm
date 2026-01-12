; Tree-sitter highlights for VIBEE DSL

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
] @keyword.conditional

[
  "true"
  "false"
] @boolean

"nil" @constant.builtin

; Decorators
(decorator) @attribute
"@const" @attribute
"@import" @keyword.import
"as" @keyword

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
] @type.builtin

(type_modifier) @type.qualifier

(generic_type
  (identifier) @type)

; Definitions
(tool_definition
  name: (identifier) @function)

(scene_definition
  name: (identifier) @type)

(function_definition
  name: (identifier) @function)

(struct_definition
  name: (identifier) @type)

(agent_definition
  name: (identifier) @type)

(machine_definition
  name: (identifier) @type)

(state_handler
  state: (identifier) @label)

; Parameters
(parameter_definition
  name: (identifier) @parameter)

(parameter
  name: (identifier) @parameter)

; Field definitions
(field_definition
  name: (identifier) @field)

; Expressions
(call_expression
  function: (identifier) @function.call)

(call_expression
  function: (member_expression
    property: (identifier) @function.method.call))

(member_expression
  property: (identifier) @property)

(named_argument
  (identifier) @parameter)

(assignment
  (identifier) @variable)

; Literals
(string) @string
(multiline_string) @string
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

; Delimiters
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
