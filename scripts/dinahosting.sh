#!/bin/bash

# update type A record of hostname at Dinahostng DNS provider
# Reference: https://en.dinahosting.com/api/documentation
#
# Successful response, entry is updated:
# <?xml version="1.0" encoding="UTF-8"?>
# <xml><response><trId>xxxxxxxx</trId><responseCode>1000</responseCode><message>Success.</message>
# <command>Domain_Zone_UpdateTypeA</command></response></xml>
#
# Error response, invalid credentials:
# <?xml version="1.0" encoding="UTF-8"?>
# <xml><response><trId>xxxxxxxx</trId><responseCode>2200</responseCode><errors>
# <error><message>Authentication error.</message><code>2200</code><parameter/></error>
# </errors><command>Domain_Zone_UpdateTypeA</command></response></xml>
#
# Error response, invalid domain:
# <?xml version="1.0" encoding="UTF-8"?>
# <xml><response><trId>xxxxxxxx</trId><responseCode>2201</responseCode><errors>
# <error><message>Authorization error.</message><code>2201</code><parameter/></error>
# </errors><command>Domain_Zone_UpdateTypeA</command></response></xml>
#
# Error response, invalid hostname:
# <?xml version="1.0" encoding="UTF-8"?>
# <xml><response><trId>xxxxxxxx</trId><responseCode>2303</responseCode><errors>
# <error><message>Param "hostname" value doesn't exist.</message><code>2303</code><parameter>hostname</parameter></error>
# </errors><command>Domain_Zone_UpdateTypeA</command></response></xml>
#
# Error response, invalid IP:
# <?xml version="1.0" encoding="UTF-8"?>
# <xml><response><trId>xxxxxxxx</trId><responseCode>2001</responseCode><errors>
# <error><message>Required param "ip" is missing.</message><code>2003</code><parameter>ip</parameter></error>
# <error><message>Param "ip" value syntax is not valid.</message><code>2005</code><parameter>ip</parameter></error>
# </errors><command>Domain_Zone_UpdateTypeA</command></response></xml>
update_host() {
    extract_domain $1
    extract_subdomain $1
    OUTPUT=$(curl -s -u $AUTH_USER:$AUTH_PASS -d "domain=$EXT_DOMAIN&hostname=$EXT_SUBDOMAIN&ip=$NEW_IP&oldIp=&command=Domain_Zone_UpdateTypeA&responseType=Xml" https://dinahosting.com/special/api.php)
    # check if curl failed
    EXIT=$(echo $?)
    if [ $EXIT -ne 0 ]; then
        ERRORS+=("Failed to update $1. Curl exited with code $EXIT")
        return 1
    fi
    # check if update failed
    # TODO We could parse the response code from the XML or JSON output properly but that would require to add another binary dependency
    grep "Success" <<< "$OUTPUT"
    if [ $? -ne 0 ]; then
        ERRORS+=("Failed to update $1. Output: $OUTPUT")
        return 2
    fi
}
