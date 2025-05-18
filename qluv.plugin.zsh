# /qompassai/lua/qluv/qluv.plugin.zsh
# -----------------------------------
# Copyright (C) 2025 Qompass AI, All rights reserved

SOURCE=${(%):-%N}
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
PLUGIN_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

source $PLUGIN_DIR/qluv
fpath=($PLUGIN_DIR/completions $fpath)
