#!/bin/bash

src="./cpp-build.sh"; dst="/usr/local/bin/cpp-build"

if [ -d "$(dirname "$dst")" ]
then
    sudo cp -i "$src" "$dst"
fi

autocompletion=\
"
#################################################################################
# CPP BUILDER #
###############
dst=\"$dst\"

function _cpp_build_
{
    local cur

    COMPREPLY=()
    cur=\"\${COMP_WORDS[COMP_CWORD]}\"

    flags=\"\$(grep -o -e '\"--[A-Za-z-]*\"' \"\$dst\" | sort --unique)\"
    COMPREPLY=(\$(compgen -W \"\$flags\" -- \"\$cur\"))
}

complete -F _cpp_build_ -o bashdefault \"\$(basename \"\$dst\")\"
################################################################################
"

read -r -p "$0: Should an autocompletion rule be added to '.bashrc': " answer

if [[ "$answer" == [yY] ]] || [[ "$answer" == [yY][eE][sS] ]] || [ -z "${answer// }" ]
then
    echo "$autocompletion" >> ~/.bashrc
fi
