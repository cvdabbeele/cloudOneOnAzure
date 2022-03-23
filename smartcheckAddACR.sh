#!/bin/bash
#printf "Checking required variables..."
printf '%s\n' "-------------------------------------------"
printf '%s\n' "   Adding ACR repository to Smart Check:   "
printf '%s\n' "-------------------------------------------"
[ ${VERBOSE} -eq 1 ] && echo "getting DSSC_HOST"
export DSSC_HOST=`kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`.nip.io
VARSAREOK=true
if  [ -z "${DSSC_USERNAME}" ]; then echo DSSC_USERNAME must be set && VARSAREOK=false; fi
if  [ -z "${DSSC_PASSWORD}" ]; then echo DSSC_PASSWORD must be set && VARSAREOK=false; fi
if  [ -z "${DSSC_HOST}" ]; then echo DSSC_HOST must be set && VARSAREOK=false; fi
if  [ "$VARSAREOK" = false ]; then exit 1 ; fi

#printf "Get a DSSC_BEARERTOKEN \n"
#-------------------------------
#az acr list --resource-group ${C1PROJECT} --output table
echo "ACR update"
[ ${VERBOSE} -eq 1 ] && echo "Doing az acr update"
[ ${VERBOSE} -eq 1 ] && az acr update -n ${AZURE_ACR} --admin-enabled true
dummy=`az acr update -n ${AZURE_ACR} --admin-enabled true`
#az acr credential show --name ${AZURE_ACR}
[ ${VERBOSE} -eq 1 ] && echo "Doing az acr list"
[ ${VERBOSE} -eq 1 ] && az acr list --resource-group ${C1PROJECT} 
export ACR_URL=`az acr list --resource-group ${C1PROJECT} | jq -r '.[].loginServer'`
[ ${VERBOSE} -eq 1 ] && echo ACR_URL=${ACR_URL}
[ ${VERBOSE} -eq 1 ] && echo "Doing az acr credential show"
[ ${VERBOSE} -eq 1 ] && az acr credential show --name ${AZURE_ACR}
export ACR_USERNAME=`az acr credential show --name ${AZURE_ACR} | jq -r '.username'`
[ ${VERBOSE} -eq 1 ] && echo ACR_USERNAME=${ACR_USERNAME}
export ACR_PASSWORD=`az acr credential show --name ${AZURE_ACR} | jq -r '.passwords[0].value'`
[ ${VERBOSE} -eq 1 ] && echo ACR_PASSWORD="[redacted]"

# Get a DSSC_BEARERTOKEN
#------------------------
export AZURE_ACR_LOGINSERVER="${AZURE_PROJECT_UID}.azurecr.io"
#export AZURE_ACR_LOGINSERVER=`az acr list --resource-group ${C1PROJECT} --output json| jq -r ".[]|select(.name|test(\"${APP1}\"))|.loginServer"`
#echo ${AZURE_ACR_LOGINSERVER}

[ ${VERBOSE} -eq 1 ] && echo "Getting DSSC_BEARERTOKEN"
[ ${VERBOSE} -eq 1 ] && curl -s -k -X POST https://${DSSC_HOST}/api/sessions -H "Content-Type: application/json"  -H "Api-Version: 2018-05-01" -H "cache-control: no-cache" -d "{\"user\":{\"userid\":\"${DSSC_USERNAME}\",\"password\":\"${DSSC_PASSWORD}\"}}" 

export DSSC_BEARERTOKEN=`curl -s -k -X POST https://${DSSC_HOST}/api/sessions -H "Content-Type: application/json"  -H "Api-Version: 2018-05-01" -H "cache-control: no-cache" -d "{\"user\":{\"userid\":\"${DSSC_USERNAME}\",\"password\":\"${DSSC_PASSWORD}\"}}" | jq -r '.token'`
[ ${VERBOSE} -eq 1 ] && echo DSSC_BEARERTOKEN=$DSSC_BEARERTOKEN

[ ${VERBOSE} -eq 1 ] && echo "Getting DSSC_REGISTRIES"
[ ${VERBOSE} -eq 1 ] && curl -s -k -X GET https://${DSSC_HOST}/api/registries -H "Content-Type: application/json" -H "Api-Version: 2018-05-01" -H "Authorization: Bearer $DSSC_BEARERTOKEN" -H "cache-control: no-cache"
export DSSC_REGISTRIES=(`curl -s -k -X GET https://${DSSC_HOST}/api/registries -H "Content-Type: application/json" -H "Api-Version: 2018-05-01" -H "Authorization: Bearer $DSSC_BEARERTOKEN" -H "cache-control: no-cache" | jq ".registries[].name"`)
 ACRALREADYADDED="false"
 for i in "${!DSSC_REGISTRIES[@]}"
 do
   [ ${VERBOSE} -eq 1 ] && echo DSSC_REGISTRIES="${DSSC_REGISTRIES[$i]}"
   if [[ "${DSSC_REGISTRIES[$i]}" =~ "${C1PROJECT}" ]] ; then  
     [ ${VERBOSE} -eq 1 ] && echo "Found registry \"${DSSC_REGISTRIES[$i]}\" belonging to this project"
     ACRALREADYADDED="true"
   else  
     [ ${VERBOSE} -eq 1 ] && echo "found ACR of other project"
   fi
 done 
 

if [[ "${ACRALREADYADDED}" == "true" ]] ; then  
  printf '%s\n ' "ACR repository already added to Smart Check..."
else
  printf '%s ' "Adding ACR repository to Smart Check..." 
   [ ${VERBOSE} -eq 1 ] && echo "..and getting DSSC_REPOID"
  export DSSCADDACRJSON=`curl -s -k -X POST https://${DSSC_HOST}/api/registries?scan=true -H "Content-Type: application/json" -H   "Api-Version: 2018-05-01" -H "Authorization: Bearer $DSSC_BEARERTOKEN" -H 'cache-control: no-cache' -d "{\"name\":\"ACR  Registry__${AZURE_ACR}\",\"description\":\"added by ${C1PROJECT}\n\",\"host\":\"${AZURE_ACR_LOGINSERVER}\",\"credentials\":  {\"username\":\"${ACR_USERNAME}\",\"password\":\"$ACR_PASSWORD\"},\"insecureSkipVerify\":"true"}"`
  [ ${VERBOSE} -eq 1 ] && echo "${DSSCADDACRJSON}"
  export DSSC_REPOID=`echo $DSSCADDACRJSON| jq '.id' 2>/dev/null`
  [ ${VERBOSE} -eq 1 ] && echo "DSSC_REPOID=${DSSC_REPOID}" 

  if [ "${DSSC_REPOID}" == "null" ] || [ -z "${DSSC_REPOID}" ]; then
     printf '\n%s\n'  "ERROR: Failed to add ACR registry ${AZURE_PROJECT_UID}.azurecr.io to SmartCheck"
  else
      printf '%s\n' "ACR added with id: ${DSSC_REPOID}"
  fi
  
fi

#TODO: write a test to verify if the Repository was successfully added
