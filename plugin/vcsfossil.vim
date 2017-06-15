" vim600: set foldmethod=marker:
"
" fossil extension for VCSCommand.
"
" Maintainer:    Bob Hiestand <bob.hiestand@gmail.com>
" Fossilizer:    H. Raz <hadaraz@gmail.com>
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
"
" Section: Documentation {{{1
"
" Options documentation: {{{2
"
" VCSCommandFossilExec
"   This variable specifies the fossil executable.  If not set, it defaults to
"   'fossil' executed from the user's executable path.
"
" VCSCommandFossilDiffOpt
"   This variable, if set, determines the default options passed to the
"   VCSDiff command.  If any options (starting with '-') are passed to the
"   command, this variable is not used.

" Section: Plugin header {{{1

if exists('VCSCommandDisableAll')
	finish
endif

if v:version < 700
	echohl WarningMsg|echomsg 'VCSCommand requires at least VIM 7.0'|echohl None
	finish
endif

if !exists('g:loaded_VCSCommand')
	runtime plugin/vcscommand.vim
endif

if !executable(VCSCommandGetOption('VCSCommandFossilExec', 'fossil'))
	" fossil is not installed
	finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Section: Variable initialization {{{1

let s:fossilFunctions = {}

" Section: Utility functions {{{1

" Function: s:Executable() {{{2
" Returns the executable used to invoke fossil suitable for use in a shell
" command.
function! s:Executable()
	return shellescape(VCSCommandGetOption('VCSCommandFossilExec', 'fossil'))
endfunction

" Function: s:DoCommand(cmd, cmdName, statusText, options) {{{2
" Wrapper to VCSCommandDoCommand to add the name of the fossil executable to the
" command argument.
function! s:DoCommand(cmd, cmdName, statusText, options)
	if VCSCommandGetVCSType(expand('%')) == 'fossil'
		let fullCmd = s:Executable() . ' ' . a:cmd
		return VCSCommandDoCommand(fullCmd, a:cmdName, a:statusText, a:options)
	else
		throw 'fossil VCSCommand plugin called on non-fossil item.'
	endif
endfunction

" Section: VCS function implementations {{{1

" Function: s:fossilFunctions.Identify(buffer) {{{2
" there is no 'root' command like in HG, but 'dbstat' will return
" error status if not within an open checkout ('status' will also
" work here, but it is too generic)
function! s:fossilFunctions.Identify(buffer)
	let oldCwd = VCSCommandChangeToCurrentFileDir(resolve(bufname(a:buffer)))
	try
		call s:VCSCommandUtility.system(s:Executable() . ' dbstat -brief')
		if(v:shell_error)
			return 0
		else
			return g:VCSCOMMAND_IDENTIFY_INEXACT
		endif
	finally
		call VCSCommandChdir(oldCwd)
	endtry
endfunction

" Function: s:fossilFunctions.Add(argList) {{{2
function! s:fossilFunctions.Add(argList)
	return s:DoCommand(join(['add'] + a:argList, ' '), 'add', join(a:argList, ' '), {})
endfunction

" Function: s:fossilFunctions.Annotate(argList) {{{2
" fossil does not support annotation of specific version, only the current one
function! s:fossilFunctions.Annotate(argList)
    let options = ''
	if len(a:argList) >= 1
		let options = join(a:argList, ' ')
	endif

    " fossil version < 1.28 supports only 'annotate' command
	try
        return s:DoCommand('blame ' . options, 'annotate', options, {})
    catch /fossil: unknown/
        return s:DoCommand('annotate ' . options, 'annotate', options, {})
	endtry
endfunction

" Function: s:fossilFunctions.Commit(argList) {{{2
function! s:fossilFunctions.Commit(argList)
	try
		return s:DoCommand('commit -M "' . a:argList[0] . '"', 'commit', '', {})
	catch /nothing has changed/
		echomsg 'No commit needed.'
	endtry
endfunction

" Function: s:fossilFunctions.Delete() {{{2
" All options are passed through.
function! s:fossilFunctions.Delete(argList)
    return s:DoCommand(join(['rm'] + a:argList, ' '), 'delete', join(a:argList, ' '), {})
endfunction

" Function: s:fossilFunctions.Diff(argList) {{{2
" Pass-through call to fossil-diff.  If no options (starting with '-') are found,
" then the options in the 'VCSCommandFossilDiffOpt' variable are added.
function! s:fossilFunctions.Diff(argList)
	if len(a:argList) == 0
		let revOptions = []
		let caption = ''
        " try to diff against the version under the cursor
		if &filetype == 'fossilannotate' || &filetype == 'fossillog' || &filetype == 'fossilstatus'
            try
                let revision = matchlist(expand("<cword>"), '\(\x\{10,}\)')[1]
                let revOptions = [' --from ' . revision . ' ']
                let caption = '(' . revision . ' : current)'
            catch
                echomsg 'Version under cursor not recognised'
                return
            endtry
        endif
	elseif len(a:argList) <= 2 && match(a:argList, '^-') == -1
		let revOptions = ['--from ' . a:argList[0] . ' ']
        if len(a:argList) == 2
            let revOptions += ['--to ' . a:argList[1] . ' ']
        endif
		let caption = '(' . a:argList[0] . ' : ' . get(a:argList, 1, 'current') . ')'
	else
		" Pass-through
		let caption = join(a:argList, ' ')
		let revOptions = a:argList
	endif

	let fossilDiffOpt = VCSCommandGetOption('VCSCommandFossilDiffOpt', '')
	if fossilDiffOpt == ''
		let diffOptions = []
	endif

	return s:DoCommand(join(['diff'] + diffOptions + revOptions), 'diff', caption, {})
endfunction

" Function: s:fossilFunctions.Info(argList) {{{2
" for fossil the command is 'finfo' and does not supports version number
function! s:fossilFunctions.Info(argList)
    return s:DoCommand(join(['finfo --limit 1'] + a:argList, ' '), 'log', join(a:argList, ' '), {})
endfunction

" Function: s:fossilFunctions.GetBufferInfo() {{{2
" Provides version control details for the current file.  Current version
" number and current repository version number are required to be returned by
" the vcscommand plugin.  This fossil extension adds branch name to the return
" list as well.
" Returns: List of results:  [revision, repository, branch]

function! s:fossilFunctions.GetBufferInfo()
	let statusText = s:VCSCommandUtility.system(s:Executable() . ' status')
    " this is not a repository
	if(v:shell_error)
		return []
	endif

	let repository = matchlist(statusText, 'tags:\s\+\(\w\+\)')[1]

	let originalBuffer = VCSCommandGetOriginalBuffer(bufnr('%'))
	let fileName = bufname(originalBuffer)
	let infoText = s:VCSCommandUtility.system(s:Executable() . ' finfo --limit 1 "' . fileName . '"')
	" File not under fossil control.
	if(v:shell_error)
		return ['Unknown']
	endif

	let revision = matchlist(infoText, '\d\{4}-\d\d-\d\d\s\+\[\(\x\+\)\]')[1]
	let branch = matchlist(infoText, 'branch:\_s\+\(\w\+\)')[1]

    return [repository, revision, branch]

endfunction

" Function: s:fossilFunctions.Log() {{{2
" for fossil the command is 'finfo' and does not supports version number
function! s:fossilFunctions.Log(argList)
	return s:DoCommand(join(['finfo'] + a:argList), 'log', join(a:argList, ' '), {})
endfunction

" Function: s:fossilFunctions.Revert(argList) {{{2
function! s:fossilFunctions.Revert(argList)
	return s:DoCommand(join(['revert'] + a:argList), 'revert', join(a:argList, ' '), {})
endfunction

" Function: s:fossilFunctions.Review(argList) {{{2
function! s:fossilFunctions.Review(argList)
    let versiontag = '(current)'
    let versionOption = ''
	if len(a:argList) == 0
        " try to show the version under the cursor
		if &filetype == 'fossilannotate' || &filetype == 'fossillog' || &filetype == 'fossilstatus'
            try
                let versiontag = matchlist(expand("<cword>"), '\(\x\{10,}\)')[1]
                let versionOption = ' -r ' . versiontag . ' '
            catch
                echomsg 'Version under cursor not recognised'
                return
            endtry
        endif
	else
		let versiontag = a:argList[0]
		let versionOption = ' -r ' . versiontag . ' '
	endif

	return s:DoCommand('cat' . versionOption, 'review', versiontag, {})
endfunction

" Function: s:fossilFunctions.Status(argList) {{{2
" fossil 'status' command works only for the whole repository
function! s:fossilFunctions.Status(argList)
	return s:DoCommand('status', 'status', '', {})
endfunction

" Function: s:fossilFunctions.Update(argList) {{{2
" in fossil 'update' can work for individual files
function! s:fossilFunctions.Update(argList)
	return s:DoCommand(join(['update current'] + a:argList), 'update', join(a:argList, ' '), {})
endfunction

" Annotate setting {{{2
let s:fossilFunctions.AnnotateSplitRegex = '\w\+: '

" Section: Plugin Registration {{{1
let s:VCSCommandUtility = VCSCommandRegisterModule('fossil', expand('<sfile>'), s:fossilFunctions, [])

let &cpo = s:save_cpo
