" Vim indent file
" Language: VIBEE DSL

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetVibeeIndent()
setlocal indentkeys=0{,0},0),0],!^F,o,O,e,0=case,0=enter,0=exit,0=callback,0=message

if exists("*GetVibeeIndent")
  finish
endif

function! GetVibeeIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let prev = getline(lnum)
  let curr = getline(v:lnum)
  let ind = indent(lnum)

  " Increase indent after lines ending with :
  if prev =~ ':\s*$'
    let ind += &shiftwidth
  endif

  " Increase indent after { [ (
  if prev =~ '[{[(]\s*$'
    let ind += &shiftwidth
  endif

  " Decrease indent for } ] )
  if curr =~ '^\s*[}\])]'
    let ind -= &shiftwidth
  endif

  " Decrease indent for case patterns (align with case keyword)
  if curr =~ '^\s*\(case\|enter\|exit\|callback\|message\)\>'
    " Find the parent block
    let parent = searchpair('tool\|scene\|on', '', '^\S', 'bnW')
    if parent > 0
      let ind = indent(parent) + &shiftwidth
    endif
  endif

  return ind
endfunction
