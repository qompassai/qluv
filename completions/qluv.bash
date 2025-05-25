#!/bin/bash
# /qompassai/qluv/completions/qluvs.bash
# ---------------------------------------
# Copyright (C) 2025 Qompass AI, All rights reserved
_qluv_download() {
    if command -v curl &>/dev/null; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

_qluv_get_commands() {
    local cmd
    while read -r line; do
        if [[ $line =~ ^[[:space:]]{2}([a-zA-Z0-9_-]+) ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done < <(qluv help)
}

_qluv_get_lua_versions() {
    [[ -n $_qluv_lua_versions ]] && return
    _qluv_lua_versions=($(_qluv_download 'https://www.lua.org/ftp/' |
    sed -n 's/.*lua-\(5\.[0-9]\.[0-9]\)\.tar\.gz.*/\1/p'))
}

_qluv_get_luajit_versions() {
    [[ -n $_qluv_luajit_versions ]] && return
    _qluv_luajit_versions=($(_qluv_download 'https://luajit.org/download.html' |
            awk '/MD5 Checksums/{flag=1;next} /<\/pre/{flag=0} flag' |
    sed -n 's/.*LuaJIT-\([0-9.]*\)\.tar\.gz.*/\1/p'))
}

_qluv_get_luarocks_versions() {
    [[ -n $_qluv_luarocks_versions ]] && return
    _qluv_luarocks_versions=($(_qluv_download 'https://luarocks.github.io/luarocks/releases/releases.json' |
            grep -o '"version":"[^"]*"' |
    cut -d'"' -f4))
}

_qluv_get_installed_versions() {
    local type=$1
    local versions=()
    while read -r line; do
        if [[ $line =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
            versions+=("${BASH_REMATCH[1]}")
        fi
    done < <(qluv "list-$type")
    echo "${versions[@]}"
}

_qluv() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opts=()

    case $COMP_CWORD in
        1)
            opts=($(_qluv_get_commands))
            ;;
        2)
            case ${COMP_WORDS[1]} in
                install)
                    _qluv_get_lua_versions
                    opts=("${_qluv_lua_versions[@]}")
                    ;;
                install-luajit)
                    _qluv_get_luajit_versions
                    opts=("${_qluv_luajit_versions[@]}")
                    ;;
                install-luarocks)
                    _qluv_get_luarocks_versions
                    opts=("${_qluv_luarocks_versions[@]}")
                    ;;
                use|set-default|uninstall)
                    opts=($(_qluv_get_installed_versions))
                    ;;
                use-luajit|set-default-luajit|uninstall-luajit)
                    opts=($(_qluv_get_installed_versions "luajit"))
                    ;;
                use-luarocks|set-default-luarocks|uninstall-luarocks)
                    opts=($(_qluv_get_installed_versions "luarocks"))
                    ;;
            esac
            ;;
    esac

    COMPREPLY=($(compgen -W "${opts[*]}" -- "$cur"))
}

complete -F _qluv qluv
