#!/bin/bash


# We're not interested in anything escaped, anything inside quotes, anything after unbalanced quotes, and anything commented out
clean_string() {
    echo "$*" | sed -r \
                    -e 's/\\(.|$)//g' \
                    -e 's/"[^"]*"//g' \
                    -e "s/'[^']*'//g" \
                    -e 's/(\w|^)#.*/\1/g' \
                    -e 's/\(\s*\)//g'
}

print_function_definition() {
    local -rA end_tokens=(['(']=')' ['((']='))' ['[[']=']]' ['{']='}' ['for']='done' 
        ['while']='done' ['until']='done' ['select']='done' ['if']='fi' ['case']='esac'
    )
    trap 'rm -f "$processed_file"' RETURN
    [[ "$file" && "$function" ]] || return 1
    local processed_file; processed_file=$(mktemp)
    process_file < "$file" > "$processed_file"
    local start_line start_lineno
    if start_line=$(grep -En "(^|[^\w_])$function\s*\(\s*\)" "$processed_file") ||
       start_line=$(grep -En "^\s*function\s+$function" "$processed_file")
    then
        start_lineno=$(cut -d : -f 1 <<< "$start_line")
    else
        echo "Function '$function' not found in file '$file'" >&2
        return 1
    fi

    local start_token; start_token=$(find_start_token "$processed_file" "$start_lineno")
    local end_token; end_token=${end_tokens[$start_token]}
    local start_tokens_seen=0
    local end_tokens_seen=0
    local tokens
    while IFS='' read -r line; do
        echo "$line"
        IFS=$' \t\n'
        mapfile -t tokens < <(clean_string "$line" | process_tokens_in_line)
        for token in "${tokens[@]}"; do
            if [[ "$token" == "$start_token" ]]; then
                start_tokens_seen=$(( start_tokens_seen + 1 ))
            elif [[ "$token" == "$end_token" ]]; then
                end_tokens_seen=$(( end_tokens_seen + 1 ))
            fi
            if (( end_tokens_seen == start_tokens_seen )); then
                break 2
            fi
        done
    done < <(tail -n +"$start_lineno" "$processed_file")
}

process_file() {
    local concatenated_lines char line
    IFS=''
    while read -r line; do
        read line_suppressed_backslash <<< "$line"
        if [[ "${line: -1}" == '\' && "${line_suppressed_backslash: -1}" != '\' ]]; then
            concatenated_lines+="${line::-1}"
            char='\'
        else
            char=''
            concatenated_lines+="$line"
            echo "$concatenated_lines"
            concatenated_lines=''
        fi
    done
    IFS=$' \t\n'
    [[ "$concatenated_lines" ]] && echo "${concatenated_lines}$char"
}

process_tokens_in_line() {
    local token
    local -a tokens_in_line
    read -ra tokens_in_line
    for token in "${tokens_in_line[@]}"; do
        grep -Eo '^(\(|\(\(|\[\[|\{|\)|\)\)|\]\]|\}|for|while|until|done|if|fi|select|case|esac)$' <<< "$token"
    done
}

find_start_token() {
    local first_token
    local processed_file=$1
    local start_lineno=$2
    local line
    while read -r line; do
        first_token=$(echo "$line" | process_tokens_in_line | head -n 1)
        [[ "$first_token" ]] && break
    done < <(tail -n +"$start_lineno" "$processed_file")
    echo "$first_token"
}

print_function_names() {
    [[ "$file" ]] || return 1
    {
        grep -Pon "[A-Za-z][A-Za-z0-9_]*\s*\(\s*\)" "$file" | sed -e 's/\s*(.*//' -e '/^\s*$/d'
        grep -Eon "^\s*function\s*[A-Za-z][A-Za-z0-9_]*" "$file" | sed -e 's/\s*function\s*//g' -e '/^\s*$/d'
    } | sort -n -k 1,1 -t ':' | column -ts ':'
}

file=$1
function=$2
if [[ "$function" ]]; then
    print_function_definition
elif [[ "$file" ]]; then
    print_function_names
else
    echo "Usage: $(basename $0) FILE [FUNCTION]" >&2
    exit 1
fi
