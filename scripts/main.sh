#!/bin/bash

################################################################################
#
# freedns
#
# NAME
#     freedns - Update DNS records of type A
#
# SYNOPSIS
#     freedns.sh -a <action> [OPTIONS]
#     freedns.sh -a start
#     freedns.sh -a stop
#     freedns.sh -a status
#     freedns.sh -a update-dns [OPTIONS]
#
# DESCRIPTION
#     Utility for updating DNS type A records of services attached to the local
#     server which has a dynamic public IP.
#
#     Updates DNS records when the local server's external dynamic IP does not 
#     match the resolved IP through DNS lookups.
#
#     Master hosts:
#     These hosts are considered to be the primary nodes of the underlaying 
#     services (websites, webapps, etc.) accesible through these hostnames.
#     For the hostnames located in the master.conf file, the DNS entries will 
#     always be updated in case of the current dynamic IP not matching the 
#     hostname IP.
#
#     Shadow hosts (experimental):
#     These hosts are considered to be the secondary nodes of certain services 
#     that should only become the master/primary nodes temporarily when the 
#     original master nodes are not available due to network issues, hardware 
#     failure, etc.
#     This feature is intended to be used in servers with low resources and/or 
#     unstable network connections (home internet connections) that will only 
#     load certain services when the original primary node is not reachable.
#     The main goal of the shadow servers is to provide basic "high" availability 
#     simulating master/shadow roles of cluster setups.
#     Consider carefully enabling this feature since it might not be suitable for
#     services that have persistent states like the ones using databases to store 
#     information since this tool does not take care of replicating the data 
#     across the master/shadow nodes and can cause data corruption if persistent 
#     data is not in sync inbetween both nodes.
#     For the hostnames located in the shadow.conf file, an attempt to access the 
#     service will be made first and in case the host not being reachable with a 
#     200 HTTP status code, the local server will assume that the service is down 
#     and it will try to become the master of it by updating the DNS entry to the 
#     local server's external IP.
#
#     Credentials:
#     A configuration file named credentials.conf can be provided for 
#     authenticating DNS update requests to freedns.afraid.org. Alternatively 
#     the credentials can be passed through parameters.
#     If you run this tool as a systemd service, the use of the credential file 
#     is recommended.
#     If you run this tool by other methods like a Jenkins job, then parameters 
#     are a valid and secure option.
#
# OPTIONS
#     -v, --verbose
#             Enable debug logs at /var/log/freedns/freedns.log
#             Default: disabled
#             Actions: all
#
#     -h, --help
#             Show help.
#
#     -a, --action <action>
#             Action to be performed. Available actions are:
#             start      -> Starts freedns as a systemd service which will add a 
#                           cron job that will check every 5 minutes if the 
#                           dynamic IP of the server has changed and if any DNS 
#                           update is required.
#             stop       -> Stops freedns service and removes the cron job.
#             status     -> Check the status of the freedns service.
#             update-dns -> Check if any host declared in the config files 
#                           requires to updated to point to the current dynamic 
#                           external IP of the local server.
#
#     -d, --dns <dns_provider_name>
#             Set the DNS service provider.
#             Currently supported values: freedns, dinahosting
#             Default: freedns
#             Actions: update-dns
#
#     -u, --user <auth_user>
#             Provide the FreeDNS user instead of using the credentials file. 
#             If no user or password is provided throught the arguments, the 
#             credentials config file will be used.
#             Default taken from: /etc/freedns/credentials.conf
#             Actions: update-dns
#
#     -p, --pass <auth_password>
#             Provide the FreeDNS password instead of using the credentials file. 
#             If no user or password is provided throught the arguments, the 
#             credentials config file will be used.
#             Default taken from: /etc/freedns/credentials.conf
#             Actions: update-dns
#
#     -m, --master <hostname1,hostname2,...>
#             Provide a comma separated list of master hosts to check instead of
#             using the configuration file.
#             Default taken from: /etc/freedns/master.conf
#             Actions: update-dns
#
#     -s, --shadow <hostname1,hostname2,...>
#             Provide a comma separated list of shadow hosts to check instead of
#             using the configuration file.
#             Default taken from: /etc/freedns/shadow.conf
#             Actions: update-dns
#
#     -cf, --credential-file <credentials_config_path>
#             Use the provided credentials file instead of the default one.
#             Default: /etc/freedns/credentials.conf
#             Actions: update-dns
#
#     -mf, --master-file
#             Use the provided master file instead of the default one.
#             Default: /etc/freedns/master.conf
#             Actions: update-dns
#
#     -sf, --shadow-file
#             Use the provided shadow file instead of the default one.
#             Default: /etc/freedns/shadow.conf
#             Actions: update-dns
#
#     -nl, --no-log
#             Ĺog only to stdout and stderr and do not log to file
#             Default: disabled
#             Actions: update-dns
#
# TODO
#     Lock executions:
#     - Default connect timeout of curl is 120s, so if several unreachable hosts 
#       are found it could happen that several executions overlap
#     - Try a lock file or a PID file to avoid this situation. Need traps?
#     - Exit error when overlap so that cron and jenkins acknowledge failures 
#       and send emails
#     Create freedns user and group
#     - Modify spec file to include this and modify service
#     - Add jenkins to freedns group to avoid running as root
#
################################################################################

unset $HISTFILE

CRON_CMD="*/5 * * * * /opt/freedns/freedns.sh -v -a update-dns"
DNS_PROVIDER=freedns
MASTER_FILE=/etc/freedns/master.conf
SHADOW_FILE=/etc/freedns/shadow.conf
CREDENTIAL_FILE=/etc/freedns/credentials.conf
LOG_FILE=/var/log/freedns/freedns.log
INSTALL_DIR=/opt/freedns
#exec 3>&1 1>>$LOG_FILE 2>&1

main() {
    get_options "$@"

    CRON_TEMP_FILE=/var/lib/freedns/crontab.tmp
    case "$ACTION" in
        start)
            RESULT=$(crontab -l | grep -F "$CRON_CMD")
            if [ ! -z "$RESULT" ]; then
                exit 0;
            fi
            # copy the content of crontab to a temporary file
            crontab -l >$CRON_TEMP_FILE
            # add our freedns cron job to the temporary file
            printf '%s\n' "$CRON_CMD" >>$CRON_TEMP_FILE
            # override crontab content with the content in the temporary file
            crontab $CRON_TEMP_FILE && rm -f $CRON_TEMP_FILE
            log "Service started."
            ;;
        update-dns)
            update_dns $AUTH_USER $AUTH_PASS
            ;;
        status)
            RESULT=$(crontab -l | grep -F "$CRON_CMD")
            if [ $? == 0 ]; then
                echo "Freedns service is ON."
            else
                echo "Freedns service is OFF."
            fi
            ;;
        stop)
            RESULT=$(crontab -l | grep -F "$CRON_CMD")
            if [ -z "$RESULT" ]; then
                exit 0;
            fi
            # escape '*' and '/' of the cron command to avoid sed getting confused
            ESCAPED_CRON_CMD=$(echo "$CRON_CMD" | sed 's/\*/\\\*/g' | sed 's/\//\\\//g')
            # copy the content of crontab besides our freedns cron job to a temporary file
            crontab -l | sed -e "/$ESCAPED_CRON_CMD/d" >$CRON_TEMP_FILE
            # override crontab content with the content in the temporary file
            crontab $CRON_TEMP_FILE && rm -f $CRON_TEMP_FILE
            log "Service stopped."
            ;;
        *)
            log "Unknown action found: $ACTION" >&2
            exit 1
            ;;
    esac
}

# update DNS action
update_dns () {
    # check compatibility with DNS provider
    DNS_PROVIDER_SCRIPT="${INSTALL_DIR}/${DNS_PROVIDER}.sh"
    if [[ -f $DNS_PROVIDER_SCRIPT && -r $DNS_PROVIDER_SCRIPT ]]; then
        . $DNS_PROVIDER_SCRIPT
        verbose "Loaded $DNS_PROVIDER_SCRIPT file."
    else
        log "Error: Unsupported DNS provider $DNS_PROVIDER found. Missing or non readable script at: $DNS_PROVIDER_SCRIPT" >&2
        exit 1
    fi
    verbose "DNS provider: $DNS_PROVIDER"

    # check credentials were set
    if [[ -z "$AUTH_USER" && -z "$AUTH_PASS" ]]; then
        if [[ -f $CREDENTIAL_FILE && -r $CREDENTIAL_FILE ]]; then
            . ${CREDENTIAL_FILE}
        else
            log "User and password were not provided and credentials file was not found or was not readable." >&2
            exit 1
        fi
    fi
    if [ -z "$AUTH_USER" ]; then
        log "User name was not provided." >&2
        exit 1
    fi
    if [ -z "$AUTH_PASS" ]; then
        log "Password was not provided." >&2
        exit 1
    fi
    verbose "User: $AUTH_USER"

    # check current ip
    NEW_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    verbose "Current IP: $NEW_IP"

    # master
    if [[ ${#MASTERS[@]} -gt 0 ]]; then
        for DOMAIN in "${MASTERS[@]}"; do
            process_host "$DOMAIN" "master"
        done
    elif [[ -f $MASTER_FILE && -r $MASTER_FILE ]]; then
        while IFS= read -r DOMAIN; do
            process_host "$DOMAIN" "master"
        done <"$MASTER_FILE"
    else
        log "Master config file $MASTER_FILE was not found or was not readable." >&2
    fi
    # shadow
    if [[ ${#SHADOWS[@]} -gt 0 ]]; then
        for DOMAIN in "${SHADOWS[@]}"; do
            process_host "$DOMAIN" "shadow"
        done
    elif [[ -f $SHADOW_FILE && -r $SHADOW_FILE ]]; then
        while IFS= read -r DOMAIN; do
            process_host "$DOMAIN" "shadow"
        done <"$SHADOW_FILE"
    else
        log "Shadow config file $SHADOW_FILE was not found or was not readable." >&2
    fi
}

# process a master or shadow host
process_host() {
    TRIMMED_DOMAIN=$(trim $1)
    if [[ $TRIMMED_DOMAIN = \#* ]] ; then
        verbose "Ignoring $2: $TRIMMED_DOMAIN"
    elif [ -z $TRIMMED_DOMAIN ]; then
        verbose "Ignoring $2: $TRIMMED_DOMAIN" >&2
    else
        log "Processing $2: $TRIMMED_DOMAIN"
        if [ "$2" = "master" ]; then
            update_host_if_needed $TRIMMED_DOMAIN
        else
            #CODE=$(curl --head --location --write-out %{http_code} --silent --output /dev/null https://$TRIMMED_DOMAIN --connect-timeout 60)
            CODE=$(curl --head --location --write-out %{http_code} --silent --output /dev/null https://$TRIMMED_DOMAIN)
            if [[ $CODE -ne 200 ]]; then
                log "$TRIMMED_DOMAIN is not available. Status: $CODE. Assuming control."
                update_host_if_needed $TRIMMED_DOMAIN
            else
                verbose "$TRIMMED_DOMAIN is available. Status: $CODE. Nothing to do."
            fi
        fi
    fi
}

# update host DNS if IP has changed
update_host_if_needed() {
    HOST_IP=$(dig +short $1)
    if [ "$NEW_IP" != "$HOST_IP" ]; then
        log "Updating $1"
        update_host $1
    else
        verbose "$1 IP and current IP are equal. Do nothing."
    fi
}

# Get options from positional parameters
get_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help | more
                exit
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -a|--action)
                ACTION="$2"
                shift
                ;;
            -d|--dns)
                DNS_PROVIDER="$2"
                shift
                ;;
            -u|--user)
                AUTH_USER="$2"
                shift
                ;;
            -p|--pass)
                AUTH_PASS="$2"
                shift
                ;;
            -m|--master)
                IFS=',' read -r -a MASTERS <<< "$2"
                if [[ ${#MASTERS[@]} -eq 0 ]]; then
                    log "Invalid master list specified." >&2
                    exit 1
                fi
                shift
                ;;
            -s|--shadow)
                IFS=',' read -r -a SHADOWS <<< "$2"
                if [[ ${#SHADOWS[@]} -eq 0 ]]; then
                    log "Invalid shadow list specified." >&2
                    exit 1
                fi
                shift
                ;;
            -cf|--credential-file)
                CREDENTIAL_FILE="$2"
                shift
                ;;
            -mf|--master-file)
                MASTER_FILE="$2"
                shift
                ;;
            -sf|--shadow-file)
                SHADOW_FILE="$2"
                shift
                ;;
            -nl|--no-log)
                LOG_FILE=/dev/null
                ;;
            *)
                log "Error: Unrecognized option $1" >&2
                exit 1
                ;;
        esac
        shift
    done
}

# extract subdomain
extract_subdomain() {
    EXT_SUBDOMAIN=$(echo $1 | awk -F. '{if(NF<2||NF>4)exit 1;if(NF==2)print"";if(NF==3)print$1;if(NF==4)print$1"."$2}')
    if [ $? -ne 0 ]; then
        log "Error: Could not extract subdomain from $1" >&2
        exit 1
    fi
}

# extract domain
extract_domain() {
    EXT_DOMAIN=$(echo $1 | awk -F. '{if(NF<2||NF>4)exit 1;print$(NF-1)"."$NF}')
    if [ $? -ne 0 ]; then
        log "Error: Could not extract domain from $1" >&2
        exit 1
    fi
}

# Trim string
trim() {
    echo "$1" | sed 's/^[ \t]*//;s/[ \t]*$//'
}

# Log to file
function log {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a $LOG_FILE
}

# Log is verbosity is enabled
function verbose {
    if [[ ${VERBOSE} == true ]]; then
        log "$*"
    fi
}

# Formatting codes
BOLD=`tput bold`
RESET=`tput sgr0`

# Show help
show_help() {
    docstring="$( grep -Pzo "(#{10,}\K)(\n#[^#]+.*)*" ${0} | sed -e 's/^# //g' -e 's/^#//g' )"
    regex="^(\s*)(-.+, --[^[:space:]]+)(.*)$"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "NAME"* ]]; then
            printf "${BOLD}NAME${RESET}\n"
        elif [[ "$line" == "SYNOPSIS"* ]]; then
            printf "${BOLD}SYNOPSIS${RESET}\n"
        elif [[ "$line" == "DESCRIPTION"* ]]; then
            printf "${BOLD}DESCRIPTION${RESET}\n"
        elif [[ "$line" == "OPTIONS"* ]]; then
            printf "${BOLD}OPTIONS${RESET}\n"
        elif [[ "$line" == "TODO"* ]]; then
            printf "${BOLD}TODO${RESET}\n"
        elif [[ "$line" =~ $regex ]]; then
            printf "%s${BOLD}%s${RESET}%s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        else
            printf "%s\n" "$line"
        fi
    done <<< "$docstring"
    printf "\n"
}

main "$@"
