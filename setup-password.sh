#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script prompts for credentials for other scripts to use

# AIX lacks sudo. Only prompt if SUDO_PASSWORD_SET is not set in the environment.
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
if [[ $(command -v sudo 2>/dev/null) ]] && [[ -z "${SUDO_PASSWORD_SET+x}" ]]
then

    # Some sudo are too old and can't handle -E option. Check for it now.
    # https://www.sudo.ws/pipermail/sudo-users/2020-March/006327.html
    count=$(sudo -E -h 2>&1 | grep -i -c illegal)
    if [ "$count" -ne 0 ]
    then
        # sudo does not accept -E
        count=$(grep -i -c 'sudo -E' build-bc.sh)
        if [ "$count" -ne 0 ]
        then
            printf "\n"
            printf "Sudo is too old. Please run fix-sudo.sh\n"
            [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
        fi
    fi

    printf "\n"
    printf "If you enter a sudo password, then it will be used for installation.\n"
    printf "If you don't enter a password, then ensure INSTX_PREFIX is writable.\n"
    printf "To avoid sudo and the password, just press ENTER and it won't be used.\n"
    printf "\n"

    IFS="" read -r -s -p "Please enter password for sudo: " SUDO_PASSWORD
    printf "\n"

    # Smoke test the password
    if [[ -n "$SUDO_PASSWORD" ]]
    then
        # Attempt to drop the cached authentication, if present.
        # The -k option is not ubiquitous. It may fail.
        printf "\n" | sudo -kS >/dev/null 2>&1

        # Now, test the password
        if printf "%s\n" "$SUDO_PASSWORD" | sudo -S ls >/dev/null 2>&1;
        then
            printf "The sudo password appears correct\n"
        else
            printf "The sudo password appears incorrect\n"
            [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
        fi
    else
        printf "The sudo password was not provided\n"
    fi

    # I would like to avoid exporting this...
    export SUDO_PASSWORD

    # Don't prompt for future passwords
    export SUDO_PASSWORD_SET=yes
fi

# Sneak this in here
bash ./setup-directories.sh

[[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
