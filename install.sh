#!/bin/bash

src="./cereal.sh"; dst="/usr/local/bin/cereal"

if [ -d "$(dirname "$dst")" ]
then
    sudo cp -i "$src" "$dst"
fi

autocompletion=\
"
#################################################################################
# CEREAL #
##########
dst=\"$dst\"

function _cereal_
{
    local cur

    COMPREPLY=()
    cur=\"\${COMP_WORDS[COMP_CWORD]}\"

    flags=\"\$(grep -o -e '\"--[A-Za-z-]*\"' \"\$dst\" | sort --unique)\"
    COMPREPLY=(\$(compgen -W \"\$flags\" -- \"\$cur\"))
}

complete -F _cereal_ -o bashdefault \"\$(basename \"\$dst\")\"
################################################################################
"

read -r -p "$0: Should an autocompletion rule be added to '.bashrc': " answer

if [[ "$answer" == [yY] ]] || [[ "$answer" == [yY][eE][sS] ]] || [ -z "${answer// }" ]
then
    echo "$autocompletion" >> ~/.bashrc
fi
