function! IncSerial()
    " Don't do anything if nothing changed
    if !&modified
        return
    endif

    " Store old position and registers
    let curpos = getpos(".")
    let saved_d = @d
    let saved_s = @s

    " Find the domain. Must be the first thing on the SOA line
    silent execute ":normal! gg/SOA\rk$/\\S\rv/\\s\rh\"dy"

    " If it's @, use the filename instead
    if @d == '@'
        let @d = expand('%:t:r')
    endif

    echom "Checking and writing zone " . @d

    " Run through checkzone
    if filereadable("/usr/sbin/named-checkzone")
        let content = join(getline(1,"$"), "\n") . "\n"
        let result = system("/usr/sbin/named-checkzone " . @d . " /dev/stdin", content)
        if v:shell_error != 0
            throw "Syntax error in zonefile"
        endif
    endif

    " Find SOA record and the serial number
    silent execute ":normal! gg/SOA\r/(\r/\\d\r\"dy8l8l\"sy2l"
    echom "Old Date " . @d . " Serial "  . @s

    " Increment
    let curdate = strftime("%Y%m%d")
    if curdate != @d
        let @s = "00"
    else
        let @s = printf("%02d", @s+1)
    endif
    let @d = curdate
    echom "New Date " . @d . " Serial "  . @s

    " And put back
    silent execute ":normal! 8h10xh\"dp\"sp"

    " Return to where we were
    call setpos('.', curpos)
    let @d = saved_d
    let @s = saved_s
endfunction

function! ReloadZones()
    if filereadable("/usr/sbin/rndc")
        let result = system("/usr/sbin/rndc reload")
    endif
endfunction

function! ZoneTemplate()
    " Generate a template based on the filename
    let saved_reg = @@
    let domain = expand("%:t:r")
    let @@  = "$ORIGIN .\n"
    let @@ .= "$TTL 3600 ; 1 hour\n"
    let @@ .= domain . "  IN SOA  master.name.server. administrative.contact. (\n"
    let @@ .= "                2011112501 ; serial\n"
    let @@ .= "                28800      ; refresh (8 hours)\n"
    let @@ .= "                7200       ; retry (2 hours)\n"
    let @@ .= "                604800     ; expire (1 week)\n"
    let @@ .= "                86402      ; minimum (1 day 2 seconds)\n"
    let @@ .= ")\n" . domain . ".  IN NS master.name.server\n\n"
    let @@ .= "$ORIGIN " . domain . ".\n\n""
    if domain =~? "in-addr\.arpa"
        let i = 1
        while i < 254
            let @@ .= printf(";%-3d    IN PTR\n", i)
            let i += 1
        endwhile
    endif
    execute "normal! ggP"
    let @@ = saved_reg
endfunction

augroup bind
    autocmd!
    autocmd BufWritePre <buffer> :call IncSerial()
    autocmd BufWritePost <buffer> :call ReloadZones()
augroup end

if line("$") == 1
    silent call ZoneTemplate()
    silent call IncSerial()
endif
