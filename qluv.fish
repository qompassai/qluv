# /qompassai/lua/qluv/qluv.fish
# -----------------------------------
# Copyright (C) 2025 Qompass AI, All rights reserved

function qluv
    set -l qluv_load
    if which qluv > /dev/null
        set qluv_load ". qluv"
    else
        set qluv_load ". "(cd (dirname (status -f)); pwd)"/qluv"
    end

    set -l target_cmd "$qluv_load && qluv $argv"

    switch "$argv[1]"

    case 'install*'
        echo y\ny\nn\ny | bash -c "$target_cmd" | grep -iv switch

    case 'use*'
        set -l list (echo "$argv[1]" | sed -e s/use/list/)
        set -l list_cmd "$qluv_load && qluv $list"

        if not bash -c "$list_cmd" | grep -q "$argv[2]"
            set -l inst (echo "$argv[1]" | sed -e s/use/install/)
            echo "Cannot $argv: Run qluv $inst $argv[2]"
            return 1
        end

        set -x PATH (bash -c "$target_cmd"' 1>&2 && echo $PATH' | tr : \n)

    case load
        set -x PATH (bash -c "$qluv_load"' 1>&2 && echo $PATH' | tr : \n)

    case '*'
        bash -c $target_cmd

    end
end

qluv load
