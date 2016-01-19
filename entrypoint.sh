#!/usr/bin/env bash

set -e

DIRECTORY="/var/www/html"
INITIALIZATION_SCRIPT="${DIRECTORY}/initialize.sh"

source /auxiliary-functions.sh

clone_repositories "${REPOSITORIES}" "${DIRECTORY}"

if [ -f "${INITIALIZATION_SCRIPT}" ]; then
    chmod u+x "${INITIALIZATION_SCRIPT}"
    log 'INFO' "Initialization: Executing ${INITIALIZATION_SCRIPT}"
    "${INITIALIZATION_SCRIPT}"
fi

# Run original parameter (CMD in image / command in container)
cd /var/www/html
exec "$@"
