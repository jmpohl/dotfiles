define-command -override kv-swap -docstring 'save and hand off to neovim' %{
    evaluate-commands %sh{
        handoff="$kak_client_env_KV_HANDOFF"
        if [ -z "$handoff" ] || [ ! -f "$kak_buffile" ]; then
            printf 'fail %%{kv-swap: needs a file buffer started by kv}\n'
            exit
        fi
        set -- $kak_window_range
        printf 'nvim\n%s\n%s\n%s\n%s\n' \
            "$kak_cursor_line" "$kak_cursor_column" "$(( $1 + 1 ))" "$kak_buffile" \
            > "$handoff"
        [ "$kak_modified" = true ] && printf 'write\n'
        printf 'quit!\n'
    }
}

define-command -override -hidden kv-open -params 4 %{
    edit %arg{1}
    evaluate-commands %sh{
        # show what is on disk, since the daemon may hold a stale buffer, but
        # never discard unsaved edits made in another client
        [ "$kak_modified" = false ] && [ -f "$kak_buffile" ] && printf 'edit!\n'
        exit 0
    }
    try %{
        select "%arg{2}.%arg{3},%arg{2}.%arg{3}"
    } catch %{
        try %{ select "%arg{2}.1,%arg{2}.1" }
    }
    evaluate-commands %sh{
        line=$2
        want_top=$4
        set -- $kak_window_range
        top=$(( $1 + 1 ))
        height=$3
        # a freshly created client has no window laid out yet, and a cold start
        # carries no view to restore, so in both cases leave the view alone
        if [ "$want_top" -le 0 ] || [ "$height" -le 0 ]; then
            exit 0
        fi
        scrolloff=${kak_opt_scrolloff%%,*}
        # scrolloff pins the cursor to a band, and scrolling outside it leaves a
        # view that snaps back on the next keypress, so ask for what is reachable
        row=$(( line - want_top + 1 ))
        low=$(( scrolloff + 1 ))
        high=$(( height - scrolloff ))
        [ $row -lt $low ] && row=$low
        [ $row -gt $high ] && row=$high
        delta=$(( row - (line - top + 1) ))
        [ $delta -gt 0 ] && printf 'execute-keys %%{%dvk}\n' $delta
        [ $delta -lt 0 ] && printf 'execute-keys %%{%dvj}\n' $(( - delta ))
        exit 0
    }
}

map global normal <F8> ': kv-swap<ret>'
