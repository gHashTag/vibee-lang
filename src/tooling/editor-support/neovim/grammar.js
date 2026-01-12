// Tree-sitter grammar for VIBEE DSL
// Install: npx tree-sitter generate

module.exports = grammar({
  name: 'vibee',

  extras: $ => [
    /\s/,
    $.comment,
  ],

  rules: {
    source_file: $ => repeat($._definition),

    _definition: $ => choice(
      $.tool_definition,
      $.scene_definition,
      $.function_definition,
      $.struct_definition,
      $.agent_definition,
      $.machine_definition,
      $.const_declaration,
      $.import_statement,
    ),

    // Decorators
    decorator: $ => seq(
      '@',
      $.identifier,
      optional($.decorator_arguments),
    ),

    decorator_arguments: $ => seq(
      '(',
      optional(commaSep($._expression)),
      ')',
    ),

    // Tool definition
    tool_definition: $ => seq(
      repeat($.decorator),
      'tool',
      field('name', $.identifier),
      ':',
      $.tool_body,
    ),

    tool_body: $ => repeat1(choice(
      $.decorator,
      $.parameter_definition,
      $.arrow_block,
    )),

    parameter_definition: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $.type),
      optional(seq('=', $._expression)),
      repeat($.decorator),
    ),

    arrow_block: $ => seq(
      '->',
      choice(
        $.block,
        $._expression,
      ),
    ),

    // Scene definition
    scene_definition: $ => seq(
      repeat($.decorator),
      'scene',
      field('name', $.identifier),
      ':',
      $.scene_body,
    ),

    scene_body: $ => repeat1($.state_handler),

    state_handler: $ => seq(
      'on',
      field('state', $.identifier),
      ':',
      $.state_body,
    ),

    state_body: $ => repeat1(choice(
      $.enter_block,
      $.exit_block,
      $.callback_handler,
      $.message_handler,
    )),

    enter_block: $ => seq('enter', ':', repeat1($.action)),
    exit_block: $ => seq('exit', ':', repeat1($.action)),

    callback_handler: $ => seq(
      'callback',
      $.string,
      '->',
      $.action,
    ),

    message_handler: $ => seq(
      'message',
      $.message_pattern,
      ':',
      repeat1($.action),
    ),

    message_pattern: $ => seq(
      $.identifier,
      optional(seq('(', commaSep($.identifier), ')')),
    ),

    action: $ => seq('->', $._expression),

    // Function definition
    function_definition: $ => seq(
      repeat($.decorator),
      'fn',
      field('name', $.identifier),
      $.parameter_list,
      optional(seq('->', field('return_type', $.type))),
      ':',
      $.block,
    ),

    parameter_list: $ => seq(
      '(',
      optional(commaSep($.parameter)),
      ')',
    ),

    parameter: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $.type),
      optional(seq('=', $._expression)),
    ),

    // Struct definition
    struct_definition: $ => seq(
      repeat($.decorator),
      'struct',
      field('name', $.identifier),
      ':',
      repeat1($.field_definition),
    ),

    field_definition: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $.type),
    ),

    // Agent/Machine definitions
    agent_definition: $ => seq(
      repeat($.decorator),
      'agent',
      field('name', $.identifier),
      ':',
      $.block,
    ),

    machine_definition: $ => seq(
      repeat($.decorator),
      'machine',
      field('name', $.identifier),
      ':',
      $.block,
    ),

    // Const declaration
    const_declaration: $ => seq(
      '@const',
      field('name', $.identifier),
      '=',
      $._expression,
    ),

    // Import statement
    import_statement: $ => seq(
      '@import',
      $.string,
      'as',
      $.identifier,
    ),

    // Types
    type: $ => seq(
      $._type_name,
      optional($.type_modifier),
    ),

    _type_name: $ => choice(
      'str',
      'int',
      'float',
      'bool',
      'list',
      'map',
      'any',
      'nil',
      'void',
      $.generic_type,
      $.identifier,
    ),

    generic_type: $ => seq(
      $.identifier,
      '[',
      commaSep1($.type),
      ']',
    ),

    type_modifier: $ => choice('!', '?'),

    // Expressions
    _expression: $ => choice(
      $.identifier,
      $.number,
      $.string,
      $.multiline_string,
      $.boolean,
      $.nil,
      $.list,
      $.map,
      $.binary_expression,
      $.unary_expression,
      $.call_expression,
      $.member_expression,
      $.index_expression,
      $.case_expression,
      $.if_expression,
      $.block,
      $.parenthesized_expression,
      $.pipe_expression,
      $.assignment,
    ),

    binary_expression: $ => prec.left(1, seq(
      $._expression,
      choice('+', '-', '*', '/', '%', '==', '!=', '<', '>', '<=', '>=', '&&', '||', '<>'),
      $._expression,
    )),

    unary_expression: $ => prec(2, seq(
      choice('!', '-'),
      $._expression,
    )),

    call_expression: $ => prec(3, seq(
      $._expression,
      '(',
      optional(commaSep(choice(
        $._expression,
        $.named_argument,
      ))),
      ')',
    )),

    named_argument: $ => seq(
      $.identifier,
      ':',
      $._expression,
    ),

    member_expression: $ => prec(4, seq(
      $._expression,
      '.',
      $.identifier,
    )),

    index_expression: $ => prec(4, seq(
      $._expression,
      '[',
      $._expression,
      ']',
    )),

    pipe_expression: $ => prec.left(0, seq(
      $._expression,
      '|>',
      $._expression,
    )),

    case_expression: $ => seq(
      'case',
      $._expression,
      ':',
      repeat1($.case_branch),
    ),

    case_branch: $ => seq(
      $._pattern,
      '->',
      $._expression,
    ),

    _pattern: $ => choice(
      $.identifier,
      $.number,
      $.string,
      $.boolean,
      '_',
    ),

    if_expression: $ => seq(
      'if',
      $._expression,
      ':',
      $._expression,
      optional(seq('else', ':', $._expression)),
    ),

    assignment: $ => seq(
      $.identifier,
      '=',
      $._expression,
    ),

    parenthesized_expression: $ => seq('(', $._expression, ')'),

    block: $ => seq('{', repeat($._expression), '}'),

    // Literals
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,
    number: $ => /\d+(\.\d+)?/,
    string: $ => seq('"', repeat(choice(/[^"\\]/, $.escape_sequence)), '"'),
    multiline_string: $ => seq('"""', /[^]*?/, '"""'),
    escape_sequence: $ => /\\[nrt\\'"]/,
    boolean: $ => choice('true', 'false'),
    nil: $ => 'nil',

    list: $ => seq('[', optional(commaSep($._expression)), ']'),
    map: $ => seq('{', optional(commaSep($.map_entry)), '}'),
    map_entry: $ => seq(choice($.string, $.identifier), ':', $._expression),

    // Comments
    comment: $ => /#.*/,
  },
});

function commaSep(rule) {
  return optional(commaSep1(rule));
}

function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}
