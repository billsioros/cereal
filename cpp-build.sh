#!/bin/bash

prog=$(basename "$0"); config_name=".config.json"; shrtct_name=".shortcuts.json"

declare -A mappings=(
    ["compiler"]="CC"
    ["compiler-flags"]="CCFLAGS"
    ["external-libraries"]="LIBS"
    ["include-path"]="PATH_INC"
    ["source-path"]="PATH_SRC"
    ["test-path"]="PATH_TEST"
    ["binaries-path"]="PATH_BIN"
)

function hightlight
{
    if [ "$1" == ERROR ]
    then
        color=3
    elif [ "$1" == WARNING ]
    then
        color=9
    else
        color=6
    fi

    echo "$(tput setaf $color)$2$(tput sgr0)"
}

function log
{
    echo -e "$(hightlight $1 $prog:~) $2"
}

function confirm
{
    if [ -e "$1" ]
    then
        read -p "$(log WARNING "Are you sure you want to overwrite '$1': ")" answer
        if [[ "$answer" != [yY] ]] && [[ "$answer" != [yY][eE][sS] ]]
        then
            exit 1
        fi
    fi
}

load_config=\
"import sys, json;

data = json.load(sys.stdin)

for field in data.keys():
    if isinstance(data[field], list) and (field == \"compiler-flags\" or field == \"external-libraries\"):
        data[field] = \" \".join(data[field])

    print(field, \"=\", '\"', data[field], '\"', sep='')"

load_shrtct=\
"import sys, json;

data = json.load(sys.stdin)

for field in data.keys():        
    print(\"shortcuts[\", field, \"]\", \"=\", '\"', data[field], '\"', sep='')"

if [ ! -f "$config_name" ]
then
    log ERROR "Unable to locate $config_name"; exit 1
else
    while read line
    do
        if [[ "$line" =~ (.*)=(\".*\") ]]
        then
            eval "${mappings[${BASH_REMATCH[1]}]}=${BASH_REMATCH[2]}"
        fi
    done <<< "$(cat "$config_name" | python3 -c "$load_config" 2> /dev/null)"

    for field in ""CC PATH_INC PATH_SRC PATH_TEST PATH_BIN""
    do
        if [ ! -v "$field" ]
        then
            log ERROR "'$field' was not specified"; exit 1
        fi

        if [ "$field" != CC ] && [ "$field" != PATH_BIN ]
        then
            path="${!field}"

            if [ ! -d "$path" ]
            then
                log ERROR "No directory named '$path'"
                exit 1
            fi
        fi
    done
fi

if [ -f "$shrtct_name" ]
then
    declare -A shortcuts

    while read line
    do
        eval "$line"
    done <<< $(cat "$shrtct_name" | python3 -c "$load_shrtct" 2> /dev/null)
fi

function grep_include_directives
{
	local includes=$(grep -Eo '["<].*\.[hi]pp[">]' $1)

	if [ -z "$includes" ]
	then
		return
	fi

	for include in ""$includes""
	do
		include=${include:1:${#include} - 2}

		local entry="${visited[$include]}"

		if [[ -n "$entry" ]]
		then
			continue
		else
			visited["$include"]=true
			grep_include_directives "$PATH_INC/$include"
		fi
	done
}

function generate_makefile
{
    echo
    echo "CC = $CC"
    echo "CCFLAGS = $CCFLAGS"
    echo
    echo "LIBS = $LIBS"
    echo
    echo "PATH_SRC = $PATH_SRC"
    echo "PATH_INC = $PATH_INC"
    echo "PATH_BIN = $PATH_BIN"
    echo "PATH_TEST = $PATH_TEST"
    echo
    echo ".PHONY: all"
    echo "all:"
    echo -e "\tmkdir -p \$(PATH_BIN)"
    echo -e "\t@echo"
    echo -e "\t@echo \"*** Compiling object files ***\""
    echo -e "\t@echo \"***\""
    echo -e "\tmake \$(OBJS)"
    echo -e "\t@echo \"***\""
    echo
    echo ".PHONY: clean"
    echo "clean:"
    echo -e "\t@echo"
    echo -e "\t@echo \"*** Purging binaries ***\""
    echo -e "\t@echo \"***\""
    echo -e "\trm -rvf \$(PATH_BIN)"
    echo -e "\t@echo \"***\"\n\n"

    objs="OBJS = \$(addprefix \$(PATH_BIN)/, "

    deps=""
    rules=""

    for file in ""$1""
    do
        declare -A visited

        grep_include_directives "$PATH_SRC/$file"; includes=${!visited[@]}

        unset visited

        file=${file%.cpp};

        rule="\$(PATH_BIN)/$file.o:"

        if [ -n "$includes" ]
        then
            deps_name=$(echo $file | tr [:lower:] [:upper:])_DEP

            rule="$rule \$($deps_name)"

            deps_list="\$(addprefix \$(PATH_INC)/, $includes) \$(PATH_SRC)/$file.cpp"

            deps="$deps$deps_name = $deps_list\n\n"
        else
            deps_name=""
            deps_list=""
        fi
        
        rule="$rule\n\t\$(CC) -I \$(PATH_INC) \$(DEFINED) \$(CCFLAGS) \$(PATH_SRC)/$file.cpp -c -o \$(PATH_BIN)/$file.o"

        rules="$rules$rule\n\n"

        objs="$objs $file.o"
    done

    objs="$objs)"

    echo -e "$deps\n$rules\n$objs\n"

    echo "\$(PATH_BIN)/%.exe: \$(PATH_TEST)/%.cpp \$(OBJS)"
    echo -e "\t\$(CC) -I \$(PATH_INC) \$(DEFINED) \$(CCFLAGS) \$< \$(OBJS) \$(LIBS) -o \$@"
}

function generate_shortcuts
{
    declare -A classes

    classes[-g]=$(grep -Evs '//' $PATH_INC/*.h*p $PATH_SRC/*.c*p | grep -E '__.*__' | cut -d : -f 2 | sed -nE 's/^.*\((__.*__)\).*$/\1/p')

    classes[-u]=$(grep -Evs '//' $PATH_TEST/*.c*p | grep -E '__.*__' | cut -d : -f 2 | sed -nE 's/^.*\((__.*__)\).*$/\1/p')

    declare -A shortcuts

    for class in "${!classes[@]}"
    do
        for macro in ""${classes[$class]}""
        do
            if [[ -z "$macro" ]]
            then
                continue
            fi

            key="-$(echo ${macro:2:1} | tr [:upper:] [:lower:])"

            if [[ "$key" =~ (-[ugxr]) ]]
            then
                log ERROR "'$macro' shortcut shadows \"${BASH_REMATCH[1]}\" flag"
                exit 1
            fi

            entry="${shortcuts[$key]}"

            if [[ -n "$entry" ]]
            then
                if [[ "$entry" =~ (-?)"$macro" ]]
                then
                    if [[ "$class" == -g ]]
                    then
                        shortcuts["$key"]="$class $macro"
                    fi

                    continue
                fi

                log ERROR "Macro collision detected '$macro' '"$(echo "$entry" | cut -d ' ' -f 2)"'"
                exit 1
            else
                shortcuts["$key"]="$class $macro"
            fi
        done
    done

    i=1

    echo "{"
    for key in "${!shortcuts[@]}"
    do
        echo -en "\t\"$key\": \"${shortcuts[$key]}\""

        if [ "$i" -lt "${#shortcuts[@]}" ]
        then
            echo ","
        else
            echo
        fi

        ((i++))
    done
    echo "}"
}

cmd="$*";

for key in "${!shortcuts[@]}"
do
    full="${shortcuts[$key]}"; cmd=${cmd/$key/$full}
done

if [[ "$cmd" == *"--help"* ]]
then
    echo "# Options:"
    echo "# -u, --unit-define      Define a macro in a test unit"
    echo "# -g, --global-define    Define a macro globally"
    echo "# -x, --executable       Compile the specified executable"
    echo "# -r, --rebuild          Recompile library / executable"

    if [ ${#shortcuts[@]} -gt 0 ]
    then
        echo -e "\n# Shortcuts:"
        for macro in "${!shortcuts[@]}"
        do
            printf "# %s, %s\n" "$macro" "${shortcuts[$macro]}"
        done
    fi

    echo -e "\n# Usage:"
    echo "# $prog -u [MACRO]"
    echo "# $prog -g [MACRO]"
    echo "# $prog -x [name]"
    echo "# $prog -r"

    echo -e "\n# Example: $prog -r -u __BENCHMARK__ -u __QUIET__ -g __CACHE_SIZE__=32768"

    exit 0
fi

if [[ "$cmd" == *"--shortcuts"* ]]
then
    confirm "$shrtct_name"; generate_shortcuts > "$shrtct_name"
fi

if [[ "$cmd" == *"--makefile"* ]] || [ ! -f $(pwd)/Makefile ]
then
    files=$(ls "$PATH_SRC");
    
    if [ -n "$files" ]
    then
        confirm "Makefile"; generate_makefile "$files" > Makefile
    else
        log ERROR "Failed to generate a makefile due to directory '$PATH_SRC' being empty"
        exit 1
    fi
fi

cmd="${cmd//--shortcuts/}"; cmd="${cmd//--makefile/}";

set -- ${cmd[@]}

while [ ! "$#" -eq 0 ]
do
    case "$1" in
        "-u" | "--unit-define")
        shift
        dexe="$dexe -D$1"
        shift
        ;;
        "-g" | "--global-define")
        shift
        dexe="$dexe -D$1"
        dlib="$dlib -D$1"
        shift
        ;;
        "-x" | "--executable")
        shift
        fexe=$(echo -e "$1\n$fexe")
        shift
        ;;
        "-r" | "--rebuild")
        rebuild=true
        shift
        ;;
        *)
        log ERROR "Invalid syntax! '$*'"
        exit 1
        ;;
    esac
done

if ([ "$rebuild" ] && [ -z "$fexe" ]) || [ ! -z "$dlib" ]
then
    make clean
fi

make "DEFINED=$dlib"

if [ -z "$fexe" ]
then
    fexe=$(ls "$PATH_TEST")
fi

echo "-e" "\n*** Compiling exe files ***"
echo "***"

for name in ""$fexe""
do
    if [ -z "$name" ]
    then
        continue
    fi

    if [[ "$name" =~ (\.?/?.+)/(.+) ]]
    then
        dir=${BASH_REMATCH[1]}
        file=${BASH_REMATCH[2]}

        if [ "$dir" == "$PATH_BIN" ]
        then
            name="$file"
        else
            log WARNING "Directory mismatch! '$dir'"
            continue
        fi
    fi

    name="$PATH_BIN/${name//.*/}.exe"

    if ([ "$rebuild" ] || [ ! -z "$dexe" ]) && [ -x "$name" ]
    then
        rm -f "$name"
    fi

    make "$name" "DEFINED=$dexe"
done

echo "***"
