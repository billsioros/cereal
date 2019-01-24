#!/bin/bash

cereal_src=./cereal.sh
cereal_dst=/usr/local/bin/cereal

cereal_complete=~/.cereal_complete

function confirm
{
    read -r -p "$(basename "$0"):~ $1: " answer

    if [[ "$answer" != [yY] ]] && [[ "$answer" != [yY][eE][sS] ]] && [ ! -z "${answer// }" ]
    then
        return 1
    fi

    return 0
}

echo \
"
                      X
                     //
     8o8o8o8o8o8o8o8//         BBBBBBBB BBBBBBB BBBBBBB   BBBBBBB BBBBB     BB
   o8o8o8o8o8o8o8o8o8o8       BB        BB      BB    BB  BB      BB  BB    BB
==========================    BB        BBBBBBB BBBBBBB   BBBBBBB BBBBBBB   BB
 HHHH                HHHH     BB        BB      BB  BBB   BB      BB    BB  BB
    HHHHHHHHHHHHHHHHHH         BBBBBBBB BBBBBBB BB    BBB BBBBBBB BB     BB BBBBBBB
"

if [ "$1" == "--uninstall" ] && confirm "Are you sure you want to continue"
then
    sed -i '/# cereal/,/# cereal/d' ~/.bashrc
    sudo rm -v "$cereal_complete" "$cereal_dst" 2> /dev/null
    exit 0
fi

if [ ! -r "$cereal_src" ] || [ ! -d "$(dirname "$cereal_dst")" ]
then
    echo "Failed to install '$cereal_src' at '$(dirname "$cereal_dst")'"
    exit 1
fi

if confirm "Would you like to install '$cereal_src' at '$(dirname "$cereal_dst")'"
then
    sudo cp "$cereal_src" "$cereal_dst"
else
    exit 1
fi

rule=\
"
cereal_dst=\"$cereal_dst\"

function _cereal_complete_
{
    local cur

    COMPREPLY=()
    cur=\"\${COMP_WORDS[COMP_CWORD]}\"

    flags=\"\$(grep -soe '\"--[A-Za-z-]*\"' \"\$cereal_dst\" | sort --unique)\"
    COMPREPLY=(\$(compgen -W \"\$flags\" -- \"\$cur\"))
}

complete -F _cereal_complete_ -o bashdefault \"\$(basename \"\$cereal_dst\")\"
"

entry=\
"
# cereal
if [ -r $cereal_complete ]
then
    . $cereal_complete
fi
# cereal
"

if confirm "Should an autocompletion rule be added to '.bashrc'"
then
    sed -i '/# cereal/,/# cereal/d' ~/.bashrc
    echo -n "$entry" >> ~/.bashrc
    
    if [ ! -w "$cereal_complete" ] || confirm "Would you like to overwrite '$cereal_complete'"
    then
        echo -n "$rule" > "$cereal_complete"
    fi
fi
