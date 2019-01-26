#!/bin/bash

cereal_dir_src="."
cereal_exe_src="$cereal_dir_src/cereal.sh"
cereal_com_src="$cereal_dir_src/cereal_complete.sh"

cereal_dir_dst=~/.cereal
cereal_exe_dst="$cereal_dir_dst/cereal"
cereal_com_dst="$cereal_dir_dst/cereal_complete"
cereal_glb_dst="/usr/local/bin/cereal"

entry=\
"
# cereal
if [ -r $cereal_com_dst ]
then
    . $cereal_com_dst
fi
# cereal
"

function hightlight
{
    if [ "$1" == ERROR ]
    then
        color=3
    elif [ "$1" == "WARNING" ]
    then
        color=9
    else
        color=6
    fi

    echo "$(tput setaf $color)$2$(tput sgr0)"
}

function log
{
    echo -e "$(hightlight "$1" "$(basename "$0")":~) $2"
}

function confirm
{
    read -r -p "$(log "WARNING" "$1: ")" answer

    if [[ "$answer" != [yY] ]] && [[ "$answer" != [yY][eE][sS] ]] && [ ! -z "${answer// }" ]
    then
        return 1
    fi

    return 0
}

echo \
"
$(tput setaf 9)
                      X
                     //
     8o8o8o8o8o8o8o8//         BBBBBBBB BBBBBBB BBBBBBB   BBBBBBB BBBBB     BB
   o8o8o8o8o8o8o8o8o8o8       BB        BB      BB    BB  BB      BB  BB    BB
==========================    BB        BBBBBBB BBBBBBB   BBBBBBB BBBBBBB   BB
 \...                .../     BB        BB      BB  BBB   BB      BB    BB  BB
    \________________/         BBBBBBBB BBBBBBB BB    BBB BBBBBBB BB     BB BBBBBBB

$(tput sgr0)
"

if [ "$1" == "--uninstall" ] && confirm "Are you sure you want to proceed"
then
    log "WARNING" "Removing directory '$cereal_dir_dst'"
    rm -riv "$cereal_dir_dst"

    log "WARNING" "Removing cereal from your PATH"
    sudo rm -iv "$cereal_glb_dst"

    if confirm "Should any existing autocompletion entry be removed from '.bashrc'"
    then
        sed -i '/# cereal/,/# cereal/d' ~/.bashrc
    fi

    exit 0
fi

log "MESSAGE" "Creating directory '$cereal_dir_dst'"
mkdir -p "$cereal_dir_dst"

log "MESSAGE" "Installing cereal at '$cereal_dir_dst'"
cp -i "$cereal_exe_src" "$cereal_exe_dst"

log "MESSAGE" "Adding cereal to your PATH"
if [ ! -f "$cereal_glb_dst" ] || confirm "Should '$cereal_glb_dst' be overwritten"
then
    sudo ln -sf "$cereal_exe_dst" "$cereal_glb_dst"
fi

if confirm "Should an autocompletion rule be added to '.bashrc'"
then
    sed -i '/# cereal/,/# cereal/d' ~/.bashrc
    echo -n "$entry" >> ~/.bashrc
    
    if [ ! -w "$cereal_com_dst" ] || confirm "Should '$cereal_com_dst' be overwritten"
    then
        cp "$cereal_com_src" "$cereal_com_dst"
    fi
    
    log "MESSAGE" "Restarting your shell is probably required"
fi
