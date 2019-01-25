
function retrieve_macros
{
    if [ "$1" == "--global" ]
    then
        cmd="grep -she \"\#ifdef\|\#ifndef\|defined\" $PATH_INC/*.[ih]pp $PATH_SRC/*.cpp"
    else
        cmd="grep -she \"\#ifdef\|\#ifndef\|defined\" $PATH_TEST/*.cpp"
    fi

    while read -r line
    do
        if
        [[ "$line" =~ ^\#ifdef[\ ]*(.*)[\ ]*$ ]] ||
        [[ "$line" =~ ^\#ifndef[\ ]*(.*)[\ ]*$ ]] ||
        [[ "$line" =~ ^\#if[\ ]*defined[\ ]*\(*([^\(\)]*)\)*[\ ]*$ ]] ||
        [[ "$line" =~ ^\#if[\ ]*\![\ ]*defined[\ ]*\(*([^\(\)]*)\)*[\ ]*$ ]]
        then
            echo "${BASH_REMATCH[1]}"
        fi
    done <<< "$(eval "$cmd")"
}

function _cereal_complete_
{
    local word="${COMP_WORDS[COMP_CWORD]}"
    local line="${COMP_LINE}"

    local load_shrtct
    
    local config

    local PATH_TEST
    local PATH_SRC
    local PATH_INC

    local results

    COMPREPLY=()

    config="$(pwd)/.config.json"

    load_shrtct=\
"
import json, sys

with open(\"$config\", 'r') as data:

    data = json.load(data)

    if \"shortcuts\" in data.keys():

        data = data[\"shortcuts\"]

        for field in data.keys():        
            print(field)
"

    if [[ "$line" =~ .*--unit\ *[A-Za-z1-9_.]*$ ]]
    then
        PATH_TEST="$(grep -s "test-path" "$config")"
        if [[ "$PATH_TEST" =~ .*\"test-path\":.*\"(.*)\" ]]
        then
            PATH_TEST="${BASH_REMATCH[1]}"
        fi
        
        results="$(ls "$PATH_TEST" 2> /dev/null)"
        COMPREPLY=($(compgen -W "$results" -- "$word"))
    elif [[ "$line" =~ .*--local\ *[A-Za-z1-9_]*$ ]]
    then
        PATH_TEST="$(grep -s "test-path" "$config")"
        if [[ "$PATH_TEST" =~ .*\"test-path\":.*\"(.*)\" ]]
        then
            PATH_TEST="${BASH_REMATCH[1]}"
        fi

        results="$(retrieve_macros "--local")"
        COMPREPLY=($(compgen -W "$results" -- "$word"))
    elif [[ "$line" =~ .*--global\ *[A-Za-z1-9_]*$ ]]
    then
        PATH_SRC="$(grep -s "source-path" "$config")"
        
        if [[ "$PATH_SRC" =~ .*\"source-path\":.*\"(.*)\" ]]
        then
            PATH_SRC="${BASH_REMATCH[1]}"
        fi

        PATH_INC="$(grep -s "include-path" "$config")"

        if [[ "$PATH_INC" =~ .*\"include-path\":.*\"(.*)\" ]]
        then
            PATH_INC="${BASH_REMATCH[1]}"
        fi

        results="$(retrieve_macros "--global")"
        COMPREPLY=($(compgen -W "$results" -- "$word"))
    else
        results="$(grep -soe '"--[A-Za-z-]*"' "/usr/local/bin/cereal" | sort --unique)"
        results="$results $(python3 -c "$load_shrtct" 2> /dev/null)"
        COMPREPLY=($(compgen -W "$results" -- "$word"))
    fi
}

complete -F _cereal_complete_ -o bashdefault cereal
