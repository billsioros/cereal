#!/bin/bash

# TODO:
# (1) Make --shortcuts check for shortcut collisions
# (2) Make --shortcuts format not be so hardcoded
# (3) PATHs not ending in '/'
# (4) Autocomplete flags

prog=$(basename "$0")

config_name=".config.json"

separator_shrtct="@"

declare -A mappings=(
    ["compiler"]="CC"
    ["compiler-flags"]="CCFLAGS"
    ["external-libraries"]="LIBS"
    ["include-path"]="PATH_INC"
    ["source-path"]="PATH_SRC"
    ["test-path"]="PATH_TEST"
    ["binaries-path"]="PATH_BIN"
)

declare -A reversed

for key in "${!mappings[@]}"
do
    reversed["${mappings["$key"]}"]="$key"
done

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
    echo -e "$(hightlight "$1" "$prog":~) $2"
}

function confirm
{
    read -r -p "$(log "$1" "$2")" answer

    if [[ "$answer" != [yY] ]] && [[ "$answer" != [yY][eE][sS] ]]
    then
        return 1
    fi

    return 0
}

function overwrite
{
    return $(confirm "WARNING" "Are you sure you want to overwrite '$1': ")
}

function grep_include_directives
{
	local includes
    
    includes="$(grep -Eo '["<].*\.[hi]pp[">]' "$1")"

	if [ -z "$includes" ]
	then
		return
	fi

	for include in $includes
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

    for file in $1
    do
        declare -A visited

        grep_include_directives "$PATH_SRC/$file"; includes="${!visited[*]}"

        unset visited

        file=${file%.cpp};

        rule="\$(PATH_BIN)/$file.o:"

        if [ -n "$includes" ]
        then
            deps_name=$(echo "$file" | tr "[:lower:]" "[:upper:]")_DEP

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

function create_header
{
    identifier="$1"; type="$2"

    echo -e "\n#pragma once\n"

    if [ "$3" == "True" ]
    then
        echo "template <typename T>"
    fi

    if [ "$type" == class ]
    then
        echo "class $identifier"
        echo "{"
        echo "public:"
        echo
    else
        echo "struct $identifier"
        echo "{"
    fi

    echo -e "\t$identifier();"
    echo
    echo -e "\t$identifier(const $identifier&);"
    echo
    echo -e "\t$identifier($identifier&&) noexcept;"
    echo
    echo -e "\t~$identifier();"
    echo
    echo -e "\t$identifier& operator=(const $identifier&);"
    echo
    echo -e "\t$identifier& operator=($identifier&&) noexcept;"
    echo -e "};"

    if [ "$3" == "True" ]
    then
        echo -e "\n#include <$(echo "$identifier" | tr "[:upper:]" "[:lower:]").ipp>"
    fi
}

function create_source
{
    identifier="$1"; include="$2"

    if [ "$3" == "True" ]
    then
        template="template <typename T>\n"
        list="<T>"

        echo -e "\n#pragma once"
    else
        template=""
        list=""

        echo -e "\n#include <$include.hpp>"
    fi

    echo
    echo -en "$template"
    echo "$identifier$list::$identifier()"
    echo "{"
    echo
    echo "}"
    echo
    echo -en "$template"
    echo "$identifier$list::$identifier(const $identifier$list& other)"
    echo "{"
    echo
    echo "}"
    echo
    echo -en "$template"
    echo "$identifier$list::$identifier($identifier$list&& other) noexcept"
    echo "{"
    echo
    echo "}"
    echo
    echo -en "$template"
    echo "$identifier$list::~$identifier()"
    echo "{"
    echo
    echo "}"
    echo
    echo -en "$template"
    echo "$identifier$list& $identifier$list::operator=(const $identifier$list& other)"
    echo "{"
    echo
    echo "}"
    echo
    echo -en "$template"
    echo "$identifier$list& $identifier$list::operator=($identifier$list&& other) noexcept"
    echo "{"
    echo
    echo "}"
}

function create_module
{
    identifier="$1"; type="$2"; template="$3"

    if ! [[ "$identifier" =~ ^[A-Za-z_]w* ]]
    then
        log ERROR "'$identifier' is not a valid C++ identifier"; exit 1
    fi

    module="$(echo "$identifier" | tr "[:upper:]" "[:lower:]")"

    header="$PATH_INC"/"$module".hpp
    
    if [ "$template" == "True" ]
    then
        source="$PATH_INC"/"$module".ipp
    else
        source="$PATH_SRC"/"$module".cpp
    fi

    if ([ ! -f "$header" ] && [ ! -f "$source" ]) || overwrite "$module.*"
    then
        find "$PATH_INC" "$PATH_SRC" -type f -name "$module.*" -exec rm -i {} \;

        create_header "$identifier" "$type"   "$template" > "$header"
        create_source "$identifier" "$module" "$template" > "$source"
    fi
}

load_config=\
"
import json

with open(\"$config_name\", 'r') as data:

    data = json.load(data)

    for field in data.keys():
        if field == \"shortcuts\":
            continue

        if isinstance(data[field], list) and (field == \"compiler-flags\" or field == \"external-libraries\"):
            data[field] = \" \".join(data[field])

        print(field, \"=\", '\"', data[field], '\"', sep='')
"

edit_config=\
"
import json, os, sys

class DevNull:
    def write(self, msg):
        pass

sys.stderr = DevNull()

def promt(data, field):
    if data[field]:
        ans = input(field.replace('-', ' ') + \" (\" + str(data[field]) + \"): \")
    else:
        ans = input(field.replace('-', ' ') + \": \")

    if field == \"compiler-flags\" or field == \"external-libraries\":
        ans = ans.split()
    else:
        ans = ans.strip()

    return ans if ans else data[field]

mode = 'r+' if os.path.exists(\"$(realpath "$config_name")\") else 'w'

with open(\"$config_name\", mode) as file:

    if mode == 'r+':
        data = json.load(file)
    else:
        data = {}

        data[\"compiler\"]           = \"g++\"
        data[\"compiler-flags\"]     = [
            \"-Wall\",
            \"-Wextra\",
            \"-std=c++17\",
            \"-g3\"
        ]
        data[\"external-libraries\"] = []
        data[\"include-path\"]       = \"./inc\"
        data[\"source-path\"]        = \"./src\"
        data[\"test-path\"]          = \"./test\"
        data[\"binaries-path\"]      = \"./bin\"

    data[\"compiler\"]           = promt(data, \"compiler\")
    data[\"compiler-flags\"]     = promt(data, \"compiler-flags\")
    data[\"external-libraries\"] = promt(data, \"external-libraries\")
    data[\"include-path\"]       = promt(data, \"include-path\")
    data[\"source-path\"]        = promt(data, \"source-path\")
    data[\"test-path\"]          = promt(data, \"test-path\")
    data[\"binaries-path\"]      = promt(data, \"binaries-path\")

    file.seek(0)
    json.dump(data, file, indent=4)
    file.truncate()
"

load_shrtct=\
"
import json, sys

with open(\"$config_name\", 'r') as data:

    data = json.load(data)

    if \"shortcuts\" in data.keys():

        data = data[\"shortcuts\"]

        for field in data.keys():        
            print(\"shortcuts[\", field, \"]\", \"=\", '\"', data[field], '\"', sep='')
"

save_shrtct=\
"
import json, sys

with open(\"$config_name\", 'r+') as file:
    data = json.load(file)

    if \"shortcuts\" not in data.keys():
        data[\"shortcuts\"] = {}

    for exp in list(sys.stdin):
        exp = exp.replace('\n', '').split(\"$separator_shrtct\")

        if exp[0] in data[\"shortcuts\"] and exp[1] != data[\"shortcuts\"][exp[0]]:

            ans = input(\"Are you sure you want to overwrite\", exp[0], \": \")

            if ans.lower() not in { 'y', 'yes' }:
                continue

        data[\"shortcuts\"][exp[0]] = exp[1]

    file.seek(0)
    json.dump(data, file, indent=4)
    file.truncate()
"

if [ ! -f "$config_name" ] || [[ "$*" == *"--config"* ]]
then
    log MESSAGE "Fill in the following to generate a '$config_name' file"
    python3 -c "$edit_config"
fi

while read -r line
do
    if [[ "$line" =~ (.*)=(\".*\") ]]
    then
        eval "${mappings[${BASH_REMATCH[1]}]}=${BASH_REMATCH[2]}"
    fi
done <<< "$(python3 -c "$load_config" 2> /dev/null)"

for field in "${mappings[@]}"
do
    if [ ! -v "$field" ]
    then
        log ERROR "'${reversed["$field"]}' was not specified"; exit 1
    fi

    if [[ "$field" == *PATH* ]] && [[ "$field" != *BIN* ]]
    then
        path="${!field}"

        if [ ! -d "$path" ]
        then
            if confirm "MESSAGE" "Would you like to create directory '$path': "
            then
                mkdir -p "$path" 2> /dev/null
            else
                log ERROR "'$path' needs to be created in order to continue"; exit 1
            fi
        fi
    fi
done

declare -A shortcuts

if [[ "$*" == *"--shortcuts"* ]]
then
    declare -A classes

    classes[-g]=$(grep -Evs '//' "$PATH_INC"/*.h*p "$PATH_SRC"/*.c*p | grep -E '__.*__' | cut -d : -f 2 | sed -nE 's/^.*\((__.*__)\).*$/\1/p')

    classes[-u]=$(grep -Evs '//' "$PATH_TEST"/*.c*p | grep -E '__.*__' | cut -d : -f 2 | sed -nE 's/^.*\((__.*__)\).*$/\1/p')

    for class in "${!classes[@]}"
    do
        for macro in ${classes[$class]}
        do
            if [[ -z "$macro" ]]
            then
                continue
            fi

            key="-$(echo "${macro:2:1}" | tr "[:upper:]" "[:lower:]")"

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

                log ERROR "Macro collision detected '$macro' '$(echo "$entry" | cut -d ' ' -f 2)'"
                exit 1
            else
                shortcuts["$key"]="$class $macro"
            fi
        done
    done

    for key in "${!shortcuts[@]}"
    do
        echo "$key$separator_shrtct${shortcuts[$key]}"
    done | python3 -c "$save_shrtct" 2> /dev/null
else
    while read -r line
    do
        eval "$line"
    done <<< "$(python3 -c "$load_shrtct" 2> /dev/null)"
fi

if [[ "$*" == *"--help"* ]]
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

if [[ "$*" == *"--struct"* ]] || [[ "$*" == *"--class"* ]] || [[ "$*" == *"--template"* ]]
then
    if [ "$#" -eq 2 ] && [ "$1" == "--struct" ]
    then
        create_module "$2" "struct" "False"
        exit 0
    elif [ "$#" -eq 2 ] && [ "$1" == "--class" ]
    then
        create_module "$2" "class" "False"
        exit 0
    elif [ "$#" -eq 3 ] && [ "$1" == "--template" ] && [ "$2" == "--struct" ]
    then
        create_module "$3" "struct" "True"
        exit 0
    elif [ "$#" -eq 3 ] && [ "$1" == "--template" ] && [ "$2" == "--class" ]
    then
        create_module "$3" "class" "True"
        exit 0
    else
        log "ERROR" "Invalid syntax"; exit 1
    fi
fi

sources=$(ls "$PATH_SRC")

if [ -n "$sources" ]
then
    if [ ! -f "Makefile" ] || ([[ "$*" == *"--makefile"* ]] && overwrite "Makefile")
    then
        generate_makefile "$sources" > Makefile
    fi
else
    log ERROR "Consider adding files to'$PATH_SRC'"; exit 1
fi

cmd="$*";

cmd="${cmd//--shortcuts/}"; cmd="${cmd//--makefile/}"; cmd="${cmd//--config/}";

for key in "${!shortcuts[@]}"
do
    full="${shortcuts[$key]}"; cmd=${cmd/$key/$full}
done

set -- ${cmd[*]}

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
        log ERROR "Invalid syntax near '$*'"
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

for name in $fexe
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
            log "WARNING" "Directory mismatch! '$dir'"
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
