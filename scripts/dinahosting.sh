#!/bin/bash

# update type A record of hostname at Dinahostng DNS provider
# https://en.dinahosting.com/api/documentation#generador-de-codigo
update_host() {
    extract_domain $1
    extract_subdomain $1
    curl -u $AUTH_USER:$AUTH_PASS -d "domain=$EXT_DOMAIN&hostname=$EXT_SUBDOMAIN&ip=$NEW_IP&oldIp=&command=Domain_Zone_UpdateTypeA&responseType=Xml" https://dinahosting.com/special/api.php	
}