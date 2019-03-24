#!/bin/bash

# update type A record of hostname at FreeDNS DNS provider
update_host() {
    curl -u $AUTH_USER:$AUTH_PASS https://freedns.afraid.org/nic/update?hostname=$1
}