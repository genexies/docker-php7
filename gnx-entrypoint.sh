#!/bin/bash

set -e

log() {
	echo -e >&2 "[${1}]\t$(date +%Y-%m-%d:%H:%M:%S.%N)\t${2}"
}

sudorun() {
	sudo bash -c "$1"
}

# ################################################################################
# ################################################################################
# ################################################################################
# CUSTOM PRE-entry-point...
# ################################################################################
# ################################################################################
# ################################################################################


# noop

# ################################################################################
# ################################################################################
# ################################################################################
# config.php values
# ################################################################################
# ################################################################################
# ################################################################################
if [ -n "$MYSQL_PORT_3306_TCP" ]; then
	if [ -z "$DB_HOST" ]; then
		DB_HOST='mysql'
	else
		log WARN 'both DB_HOST and MYSQL_PORT_3306_TCP found'
		log WARN "  Connecting to DB_HOST ($DB_HOST)"
		log WARN '  instead of the linked mysql container'
	fi
fi

if [ -z "$DB_HOST" ]; then
	log ERROR 'missing DB_HOST and MYSQL_PORT_3306_TCP environment variables'
	log ERROR '  Did you forget to --link some_mysql_container:mysql or set an external db'
	log ERROR '  with -e DB_HOST=hostname:port?'
	exit 1
fi

# if we're linked to MySQL, and we're using the root user, and our linked
# container has a default "root" password set up and passed through... :)
: ${DB_USER:=root}
if [ "$DB_USER" = 'root' ]; then
	: ${DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi
: ${DB_NAME:=wordpress}

if [ -z "$DB_PASSWORD" ]; then
	log ERROR 'missing required DB_PASSWORD environment variable'
	log ERROR '  Did you forget to -e DB_PASSWORD=... ?'
	log ERROR
	log ERROR '  (Also of interest might be DB_USER and DB_NAME.)'
fi

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
	key="$1"
	value="$2"
	regex="(['\"])$(sed_escape_lhs "$key")\2\s*,"
	if [ "${key:0:1}" = '$' ]; then
		regex="^(\s*)$(sed_escape_lhs "$key")\s*="
	fi
	sed -ri "s/($regex\s*)(['\"]).*\3/\1$(sed_escape_rhs "$(php_escape "$value")")/" /var/www/html/config.php
}

# ################################################################################
# ################################################################################
# ################################################################################
# Deploy PHP app
# ################################################################################
# ################################################################################
# ################################################################################

while [ "$REPOSITORIES" ]; do
	i=${REPOSITORIES%%;*}
	repo_id=$(echo "${i}" | sed -e 's/[^A-Za-z0-9._-]/_/g')
	log DEBUG "Cloning repo ${i} in /tmp/${repo_id} ..."
	mkdir -p /tmp/${repo_id}
	chown www-data /tmp/${repo_id}
	sudorun "git clone ${i} /tmp/${repo_id}"
	log INFO "Done cloning repo ${i}"

	log DEBUG "Installing repo ${i} in /var/www/html ..."
	sudorun "cd /tmp/${repo_id} && git --work-tree=/var/www/html checkout -f"
	log INFO "Done installing repo ${i}"
	[ "$REPOSITORIES" = "$i" ] && \
		REPOSITORIES='' || \
		REPOSITORIES="${REPOSITORIES#*;}"
done

# wp-config.php might be different among environments...
log INFO "Configuring Wordpress using environment ${ENVIRONMENT} ..."
sudorun "cp -f /var/www/html/config.${ENVIRONMENT}.php /var/www/html/config.php"
sudorun "cp -f /var/www/html/htaccess.${ENVIRONMENT}.txt /var/www/html/.htaccess"
sudorun "cp -f /var/www/html/robots.${ENVIRONMENT}.txt /var/www/html/robots.txt"

chmod 444 config.php .htaccess robots.txt

# Now, inject DB config from container execution env...
set_config 'DB_HOST' "$DB_HOST"
set_config 'DB_USER' "$DB_USER"
set_config 'DB_PASSWORD' "$DB_PASSWORD"
set_config 'DB_NAME' "$DB_NAME"
set_config 'DB_TABLE' "$DB_TABLE"
set_config 'BASE_HREF' "$BASE_HREF"

# Run original parameter (CMD in image / command in container)
cd /var/www/html
exec "$@"
