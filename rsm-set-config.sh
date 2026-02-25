#!/usr/bin/env bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"
ZBX_DEFAULTS="${DIR}/.zbx-defaults"

main()
{
    write_default O_DBHOST $(get_ini /opt/zabbix50/scripts/rsm.conf db_host)
    write_default O_DBUSER $(get_ini /opt/zabbix50/scripts/rsm.conf db_user)
    write_default O_DBNAME $(get_ini /opt/zabbix50/scripts/rsm.conf db_name)
    write_default O_DBPASS $(get_ini /opt/zabbix50/scripts/rsm.conf db_password)
}

get_ini()
{
    local file="$1"
    local key="$2"

    local target_section=""
    local current_section=""
    local value=""

    # get our section from local
    while IFS= read -r line; do
	# get rid of comments and whitespaces
        line="${line%%;*}"
        line="${line%%#*}"
	line="$(echo -n "$line" | xargs)"

        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^local[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            target_section="${BASH_REMATCH[1]}"
            break
        fi
    done < "$file"

    [[ -z "$target_section" ]] && return 1

    # find key in the appropriate section
    while IFS= read -r line; do
	# get rid of comments and whitespaces
        line="${line%%#*}"
        line="${line%%;*}"
        line="$(echo -n "$line" | xargs)"
        [[ -z "$line" ]] && continue

	# find needed section
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

	# get the key if ours
        if [[ "$current_section" == "$target_section" && "$line" =~ ^$key[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            value="${BASH_REMATCH[1]}"
            echo "$value"
            return 0
        fi
    done < "$file"

    return 1
}

write_default()
{
    o=$1
    v=$2

    # return if already set
    /bin/grep -q "^$o=$v$" $ZBX_DEFAULTS 2>/dev/null && return

    # add entry if missing
    if ! /bin/grep -q "^$o=" $ZBX_DEFAULTS 2>/dev/null; then
	echo $o=$v >> $ZBX_DEFAULTS
	return;
    fi

    # replace otherwise
    sed -i "s|^$o=.*|$o=$v|" $ZBX_DEFAULTS
}

main
