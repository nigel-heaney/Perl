; exe wrapper for ssh-load perl script
;
; nigel heaney 9-10-09
; v0.1
;
;
;
if $CmdLine[1] == "-l" or $CmdLine[1] == "--list" or $CmdLine[1] == "-a"or $CmdLine[1] == "--add" then
	run("cmd /K perl d:\stuff\programs\ssh-load.pl " & $CmdLine[1] & " " & $CmdLine[2]) ;,,@SW_HIDE )
    exit(0)
Endif
run("perl d:\stuff\programs\ssh-load.pl $CmdLine[1] $CmdLine[2] $CmdLine[3] $CmdLine[4]") ;,,@SW_HIDE )
