#!/bin/bash

cereal_src=./cereal.sh
cereal_dst=/usr/local/bin/cereal

cereal_complete=~/.cereal_complete

function confirm
{
    read -r -p "$1: " answer

    if [[ "$answer" != [yY] ]] && [[ "$answer" != [yY][eE][sS] ]] && [ ! -z "${answer// }" ]
    then
        return 1
    fi

    return 0
}

if [ ! -r "$cereal_src" ] || [ ! -d "$(dirname "$cereal_dst")" ]
then
    echo "Failed to copy '$cereal_src' to $(dirname "$cereal_dst")"; exit 1
fi

sudo cp -i "$cereal_src" "$cereal_dst"

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
    . "$cereal_complete"
fi
# cereal
"

if confirm "Should an autocompletion rule be added to '.bashrc'"
then
    echo -n "$entry" >> ~/.bashrc
    
    if [ ! -w "$cereal_complete" ] || confirm "Would you like to overwrite '$cereal_complete'"
    then
        echo -n "$rule" > "$cereal_complete"
    fi
fi
