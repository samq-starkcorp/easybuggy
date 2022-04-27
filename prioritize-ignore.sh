#!/bin/bash
# Prerequisites:
# apt install jq curl
# WS_GENERATEPROJECTDETAILSJSON: true
# WS_PRODUCTNAME
# WS_PROJECTNAME
# WS_USERKEY
# WS_APIKEY
# WS_WSS_URL

# TODO - Add ERROR handling
# TODO - Only works with default branch

WS_PROJECTTOKEN=$(jq -r '.projects | .[] | .projectToken' ./whitesource/scanProjectDetails.json)
WS_URL=$(echo $WS_WSS_URL | awk -F "/agent" '{print $1}')
echo "variables for local debugging"
echo "export WS_APIKEY=<add your key>"
echo "export WS_USERKEY=<add your key>"
echo "export WS_PRODUCTNAME="$WS_PRODUCTNAME
echo "export WS_PROJECTNAME="$WS_PROJECTNAME
echo "export WS_PROJECTTOKEN="$WS_PROJECTTOKEN
echo "export WS_URL="$WS_URL

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'



### getProjectSecurityAlertsbyVulnerabilityReport - finds Green Shields
curl --request POST $WS_URL'/api/v1.3' -H 'Content-Type: application/json'  -d '{ "requestType" : "getProjectSecurityAlertsByVulnerabilityReport", "userKey" : "'$WS_USERKEY'", "projectToken": "'$WS_PROJECTTOKEN'", "format" : "json"}' | jq -r '.alerts[] | select(.euaShield=="GREEN") | .vulnerabilityId' >> greenshields.txt
echo "saving greenshields.txt"

# Get productToken from WS_PRODUCTNAME
WS_PRODUCTTOKEN=$(curl --request POST $WS_URL'/api/v1.3' -H 'Content-Type: application/json'  -d '{ "requestType" : "getAllProducts",   "userKey" : "'$WS_USERKEY'",  "orgToken": "'$WS_APIKEY'"}' | jq -r --arg WS_PRODUCTNAME $WS_PRODUCTNAME '.products[] | select(.productName==$WS_PRODUCTNAME) | .productToken')
echo "getting productToken" $WS_PRODUCTTOKEN

# Get repo default branch projectToken from productToken
REPOTOKEN=$(curl --request POST $WS_URL'/api/v1.3' -H 'Content-Type: application/json'  -d '{ "requestType" : "getAllProjects",   "userKey" : "'$WS_USERKEY'",  "productToken": "'$WS_PRODUCTTOKEN'"}' | jq -r --arg WS_PRODUCTNAME $WS_PRODUCTNAME '.projects[] | select(.projectName==$WS_PRODUCTNAME) | .projectToken')
echo "getting projectToken for repository default branch" $REPOTOKEN

### getProjectAlertsbyType for repo default branch
curl --request POST $WS_URL'/api/v1.3' -H 'Content-Type: application/json' -d '{ "requestType" : "getProjectAlertsByType", "userKey" : "'$WS_USERKEY'", "alertType": "SECURITY_VULNERABILITY",  "projectToken": "'$REPOTOKEN'","format" : "json"}' >> alerts.json
echo "saving alerts.json"

greenshieldlist=$(cat greenshields.txt)
### Get CVE by GREEN Shield
for GREENSHIELDVULN in $greenshieldlist
do
echo -e "${grn}GREENSHIELDVULN: $GREENSHIELDVULN${end}"

IGNORES=$(jq -r --arg GREENSHIELDVULN $GREENSHIELDVULN '.alerts[] | select(.vulnerability.name==$GREENSHIELDVULN)|.alertUuid' alerts.json)
echo "${yel}Ignoring the following alertUuids $IGNORES${end}"

curl --request POST $WS_URL'/api/v1.3' -H 'Content-Type: application/json'  -d '{ "requestType" : "ignoreAlerts", "userKey" : "'$WS_USERKEY'", "orgToken" : "'$WS_APIKEY'", "projectToken" : "'$REPOTOKEN'", "alertUuids" : ["'$IGNORES'"], "comments" : "green shield vulnerabilities are not reachable or exploitable and have been ignored"}'

done