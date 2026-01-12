" Vim syntax file
" Language: VIBEE DSL
" Maintainer: VIBEE Team
" Latest Revision: 2024

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword vibeeKeyword tool scene fn on struct agent machine nextgroup=vibeeName skipwhite
syn keyword vibeeBlockKeyword enter exit callback message stay transition reply
syn keyword vibeeControl case if else match
syn keyword vibeeBoolean true false
syn keyword vibeeBuiltin print read_line length to_string parse_int lowercase uppercase
syn keyword vibeeBuiltin map filter reduce each enumerate first last reverse join split
syn keyword vibeeBuiltin contains starts_with ends_with replace trim
syn keyword vibeeBuiltin now sleep random generate_id
syn keyword vibeeBuiltin Ok Error Some None

" Decorators/Annotations
syn match vibeeDecorator "@\w\+"
syn match vibeeDecoratorCall "@\w\+(" contains=vibeeDecorator

" Special decorators
syn match vibeeSpecialDecorator "@desc\|@spec\|@const\|@import\|@llm\|@fallback_models\|@retry\|@timeout\|@budget\|@one_of\|@range\|@ffi"

" Types
syn keyword vibeeType str int float bool list map any nil void
syn match vibeeTypeModifier "!" contained
syn match vibeeTypedParam "\w\+:\s*\w\+[!?]\?" contains=vibeeType,vibeeTypeModifier

" Strings
syn region vibeeString start=/"/ skip=/\\"/ end=/"/ contains=vibeeEscape,vibeeInterpolation
syn region vibeeMultiString start=/"""/ end=/"""/ contains=vibeeEscape,vibeeInterpolation
syn match vibeeEscape "\\[nrt\\\"']" contained
syn region vibeeInterpolation start="\${" end="}" contained contains=ALL

" Numbers
syn match vibeeNumber "\<\d\+\>"
syn match vibeeFloat "\<\d\+\.\d\+\>"

" Comments
syn match vibeeComment "#.*$" contains=vibeeTodo
syn keyword vibeeTodo TODO FIXME XXX NOTE contained

" Operators
syn match vibeeOperator "[-+*/%=<>!&|]"
syn match vibeeOperator "->"
syn match vibeeOperator "<>"
syn match vibeeOperator "|>"
syn match vibeeOperator "=="
syn match vibeeOperator "!="
syn match vibeeOperator "<="
syn match vibeeOperator ">="
syn match vibeeOperator "&&"
syn match vibeeOperator "||"

" Delimiters
syn match vibeeDelimiter "[{}\[\]():]"

" Function/Tool names
syn match vibeeName "\s\+\w\+" contained

" Special identifiers
syn match vibeeSpecialIdent "\<self\>\|\<ctx\>\|\<state\>"

" ANSI escape codes in strings (for CLI tools)
syn match vibeeAnsiCode "\\u{001B}\[\d\+m" contained containedin=vibeeString

" Highlighting
hi def link vibeeKeyword Keyword
hi def link vibeeBlockKeyword Statement
hi def link vibeeControl Conditional
hi def link vibeeBoolean Boolean
hi def link vibeeBuiltin Function
hi def link vibeeDecorator PreProc
hi def link vibeeSpecialDecorator Special
hi def link vibeeType Type
hi def link vibeeString String
hi def link vibeeMultiString String
hi def link vibeeEscape SpecialChar
hi def link vibeeInterpolation Special
hi def link vibeeNumber Number
hi def link vibeeFloat Float
hi def link vibeeComment Comment
hi def link vibeeTodo Todo
hi def link vibeeOperator Operator
hi def link vibeeDelimiter Delimiter
hi def link vibeeName Function
hi def link vibeeSpecialIdent Identifier
hi def link vibeeAnsiCode SpecialChar

let b:current_syntax = "vibee"
