; Tree-sitter indents for VIBEE DSL

[
  (tool_definition)
  (scene_definition)
  (function_definition)
  (struct_definition)
  (agent_definition)
  (machine_definition)
  (state_handler)
  (enter_block)
  (exit_block)
  (callback_handler)
  (message_handler)
  (case_expression)
  (if_expression)
  (block)
  (list)
  (map)
] @indent.begin

[
  "}"
  "]"
  ")"
] @indent.end

[
  (comment)
] @indent.ignore
