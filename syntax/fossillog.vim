" Vim syntax file
" Language:	fossil log output
" Maintainer:	Bob Hiestand <bob.hiestand@gmail.com>
" Fossilizer:   H. Raz <hadaraz@gmail.com>
" Remark:	Used by the vcscommand plugin.
" License:
" Copyright (c) Bob Hiestand
" Copyright (c) H. Raz
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.

if exists("b:current_syntax")
	finish
endif

syn match fossilCommit /\[\zs\x\+/
syn match fossilDate /\d\d\d\d-\d\d-\d\d/
syn match fossilName /user:\_s\+\zs\w\+/
syn match fossilBranch /branch:\_s\+\zs\w\+/

if !exists("did_fossillog_syntax_inits")
	let did_fossillog_syntax_inits = 1
	hi link fossilName Type
	hi link fossilCommit Statement
	hi link fossilDate Comment
	hi link fossilBranch Label
endif

let b:current_syntax="fossilLog"
