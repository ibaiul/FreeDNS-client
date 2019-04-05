#!/bin/bash

# update type A record of hostname at FreeDNS DNS provider
#
# Successful response, entry is updated:
# > Updated $1 to x.x.x.x in 0.029 seconds
#
# Successful response with force option, entry was already up to date:
# > ERROR: Address x.x.x.x has not changed.
#
# Error response, with wrong credentials or hostname does not exist:
# > ERROR: Unable to locate this record (changed password recently? deleted and re-created this dns entry?) (double check username/password are correct)
update_host() {
    OUTPUT=$(curl -s -u $AUTH_USER:$AUTH_PASS https://freedns.afraid.org/nic/update?hostname=$1)
    # check if curl failed
    EXIT=$(echo $?)
    if [ $EXIT -ne 0 ]; then
        ERRORS+=("Failed to update $1. Curl exited with code $EXIT")
        return 1
    fi
    # check if update failed
    grep "Unable to locate" <<< "$OUTPUT"
    if [ $? -eq 0 ]; then
        ERRORS+=("Failed to update $1. Output: $OUTPUT")
        return 2
    fi
}
