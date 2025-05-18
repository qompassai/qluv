#!/bin/sh

{ # ensure the whole script is loaded

    set -eu

    print_bold()
    {
        tput bold; echo "${1}"; tput sgr0
    }

    download_file()
    {
        if 'curl' -V >/dev/null 2>&1
        then 'curl' -fsSL "${1}"
        else 'wget' -qO- "${1}"
        fi
    }

    # install_file baseurl file
    install_file()
    {
        if [ -e "${2}" ]
        then
            cp "${2}" "${QLUV_DIR}/${2}"
        else
            download_file "${1}/${2}" >"${QLUV_DIR}/${2}"
        fi
    }

    ## Option parsing
    QLUV_DIR=~/.qluv
    REVISION=v1.1.0
    SHELL_TYPE="$(basename /"${SHELL}")"

    while getopts hr:s: OPT
    do
        case "$OPT" in
            r ) REVISION="${OPTARG}" ;;
            h )
                echo "Usage: ${0} [-r REVISION]"
                echo "  -r  qluv reversion [${REVISION}]"
                exit 0
                ;;
        esac
    done

    print_bold "Installing qluv..."

    ## Download script
    URL="https://raw.githubusercontent.com/DhavalKapil/qluv/${REVISION}"

    mkdir -p "${QLUV_DIR}/completions"

    install_file "${URL}" "qluv"
    chmod a+x "${QLUV_DIR}/qluv"

    install_file "${URL}" "completions/qluv.bash" || rm "${QLUV_DIR}/completions/qluv.bash"

    ## Set up profile
    APPEND_COMMON="[ -s ~/.qluv/qluv ] && . ~/.qluv/qluv"

    APPEND_BASH="${APPEND_COMMON}
    [ -s ~/.qluv/completions/qluv.bash ] && . ~/.qluv/completions/qluv.bash"

    APPEND_ZSH="${APPEND_COMMON}"

    case "${SHELL_TYPE}" in
        bash ) APPEND="${APPEND_BASH}" ;;
        zsh ) APPEND="${APPEND_ZSH}" ;;
        * ) APPEND="${APPEND_COMMON}"
    esac

    if [ -f ~/."${SHELL_TYPE}"rc ]
    then
        'grep' -qF "${APPEND}" ~/."${SHELL_TYPE}"rc || printf "\n%s\n\n" "${APPEND}" >>~/."${SHELL_TYPE}"rc

        print_bold "Appending the following lines at the end of ~/.${SHELL_TYPE}rc if lines not exists:"
        printf "\n%s\n\n" "${APPEND}"
        print_bold "To use qluv, you must restart the shell or execute '. ~/.${SHELL_TYPE}rc'"
    else
        print_bold "Add the following lines at the end of your profile (~/.bashrc, ~/.zshrc, etc):"
        printf "\n%s\n\n" "${APPEND}"
        print_bold "To use qluv, you must restart the shell or execute the above lines"
    fi

    print_bold "qluv was successfully installed!"

}
