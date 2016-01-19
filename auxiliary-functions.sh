#!/usr/bin/env bash

log() {
    LEVEL="${1}"
    MESSAGE="${2}"
    TIMESTAMP=$(date +%Y-%m-%d:%H:%M:%S.%N)
	echo -e >&2 "[${LEVEL}]\t${TIMESTAMP}\t${MESSAGE}"
}

sudorun() {
	sudo bash -c "${1}"
}

# see http://stackoverflow.com/a/2705678/433558
sed_escape_lhs() {
	echo "$@" | sed 's/[]\/$*.^|[]/\\&/g'
}

sed_escape_rhs() {
	echo "$@" | sed 's/[\/&]/\\&/g'
}

php_escape() {
	php -r 'var_export((string) $argv[1]);' "$1"
}

set_config() {
	key="${1}"
	value="${2}"
	file="${3}"
	regex="(['\"])$(sed_escape_lhs "$key")\2\s*,"
	if [ "${key:0:1}" = '$' ]; then
		regex="^(\s*)$(sed_escape_lhs "$key")\s*="
	fi
	sed -ri "s/($regex\s*)(['\"]).*\3/\1$(sed_escape_rhs "$(php_escape "$value")")/" "${3}"
}

clone_repositories() {
    REPOSITORIES="${1}" # Separated by ;
    DIRECTORY="${2}"
    while [ "${REPOSITORIES}" ]; do
        i=${REPOSITORIES%%;*}
        repo_id=$(echo "${i}" | sed -e 's/[^A-Za-z0-9._-]/_/g')
        log DEBUG "Cloning repo ${i} in /tmp/${repo_id} ..."
        mkdir -p /tmp/${repo_id}
        chown www-data /tmp/${repo_id}
        sudorun "git clone ${i} /tmp/${repo_id}"
        log INFO "Done cloning repo ${i}"

        log DEBUG "Installing repo ${i} in ${DIRECTORY} ..."
        sudorun "cd /tmp/${repo_id} && git --work-tree=${DIRECTORY} checkout -f"
        log INFO "Done installing repo ${i}"
        [ "$REPOSITORIES" = "$i" ] && \
            REPOSITORIES='' || \
            REPOSITORIES="${REPOSITORIES#*;}"
    done
}