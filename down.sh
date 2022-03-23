#! /bin/bash

#still WIP state... needs work
printf '%s\n' "----------------------"
printf '%s\n' "Terminating environment"
printf '%s\n' "----------------------"
# check for variabels
#-----------------------
. ./00_define_vars.sh

VARSAREOK=true
if  [ -z "${AZURE_LOCATION}" ]; then echo AZURE_LOCATION must be set && VARSAREOK=false; fi
if  [ -z "${C1PROJECT}" ]; then echo ${C1PROJECT} must be set && VARSAREOK=false; fi
####if  [ "$VARSAREOK" = false ]; then exit ; fi

#remove this project's cluster from c1cs
C1CSCLUSTERS=(`\
curl --silent --location --request GET "${C1CSAPIURL}/clusters" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' \
 | jq -r ".clusters[] | select(.name == \"${C1PROJECT}\").id"`)

for i in "${!C1CSCLUSTERS[@]}"
do
  printf "%s\n" "C1CS: Removing cluster ${C1CSCLUSTERS[$i]}"
  curl --silent --location --request DELETE "${C1CSAPIURL}/clusters/${C1CSCLUSTERS[$i]}" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' 
done 


# remove this project's Policy from c1cs
C1CSPOLICIES=(`\
curl --silent --location --request GET "${C1CSAPIURL}/policies" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' \
 | jq -r ".policies[] | select(.name == \"${C1PROJECT}\").id"`)

for i in "${!C1CSPOLICIES[@]}"
do
  printf "%s\n" "C1CS: Removing policy ${C1CSPOLICIES[$i]}"
  curl --silent --location --request DELETE "${C1CSAPIURL}/policies/${C1CSPOLICIES[$i]}" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' 
done 


# remove this project's Scanner from c1cs
C1CSSCANNERS=(`\
curl --silent --location --request GET "${C1CSAPIURL}/scanners" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' \
 | jq -r ".scanners[] | select(.name == \"${C1PROJECT}\").id"`)

for i in "${!C1CSSCANNERS[@]}"
do
  printf "%s\n" "C1CS: Removing scanner ${C1CSSCANNERS[$i]}"
  curl --silent --location --request DELETE "${C1CSAPIURL}/scanners/${C1CSSCANNERS[$i]}" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' 
done 


#delete c1cs 
printf '%s\n' "C1CS: Removing from cluster"
helm_c1cs=`helm list -n c1cs -o json | jq -r '.[].name'`
if [[ "${helm_c1cs}" == "trendmicro-c1cs" ]]; then
  printf "%s" "Uninstalling C1CS... "
  helm delete trendmicro-c1cs -n c1cs
fi

# remove these project groups from c1as
readarray -t C1ASGROUPS <<< `curl --silent --location --request GET "${C1ASAPIURL}/accounts/groups" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' | jq -r ".[].name"`
readarray -t DUMMYARRAYTOFIXSYNTAXCOLORINGINVSCODE <<< `pwd `
[ ${VERBOSE} -eq 1 ] &&  printf "%s" "C1ASGROUPS[@] =  ${C1ASGROUPS[@]}"
readarray -t C1ASGROUPIDS <<< `curl --silent --location --request GET "${C1ASAPIURL}/accounts/groups" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' | jq -r ".[].group_id"`
readarray -t DUMMYARRAYTOFIXSYNTAXCOLORINGINVSCODE <<< `pwd `

for i in "${!C1ASGROUPS[@]}"
do
  #printf "%s\n" "C1AS: found group ${C1ASGROUPS[$i]} with ID ${C1ASGROUPIDS[$i]}"
  if [[ "${C1ASGROUPS[$i]}" == "${C1PROJECT^^}-${APP1^^}" ]]; 
  then
    printf "%s\n" "C1AS: Removing old Group object ${C1PROJECT^^}-${APP1^^}"
    curl --silent --location --request DELETE "${C1ASAPIURL}/accounts/groups/${C1ASGROUPIDS[$i]}"   --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' 
  fi
  #if [[ "${C1ASGROUPS[$i]}" == "${C1PROJECT^^}-${APP2^^}" ]]; 
  #then
  #  printf "%s\n" "Deleting old Group object ${C1PROJECT^^}-${APP2^^} in C1AS"
  #  curl --silent --location --request DELETE "${C1ASAPIURL}/accounts/groups/${C1ASGROUPIDS[$i]}"   --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' 
  #fi
  #if [[ "${C1ASGROUPS[$i]}" == "${C1PROJECT^^}-${APP3^^}" ]]; 
  #then
  #  printf "%s\n" "Deleting old Group object ${C1PROJECT^^}-${APP3^^} in C1AS"
  #  curl --silent --location --request DELETE "${C1ASAPIURL}/accounts/groups/${C1ASGROUPIDS[$i]}"   --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' 
  #fi

done 


#remove smartcheck 
helm_smartcheck=`helm list -n ${DSSC_NAMESPACE}  -o json | jq -r '.[].name'`
if [[ "${helm_smartcheck}" =~ "deepsecurity-smartcheck" ]]; then
  printf "%s" "Uninstalling smartcheck... "
  helm delete deepsecurity-smartcheck -n ${DSSC_NAMESPACE}
fi

#delete services
printf "%s\n" "Removing Services from cluster"
for i in `kubectl get services -o json | jq -r '.items[].metadata.name'`
do
  printf "%s" "... "
  kubectl delete service $i
done

#delete deployed apps
printf "%s\n" "Removing Deployments from cluster... "
for i in `kubectl get deployments  -o json | jq -r '.items[].metadata.name'`
do
  kubectl delete deployment $i
done


# deleting AKS cluster
#printf "%s\n" "Checking AKS clusters"
AZURE_CLUSTERS=( `az aks list -o json| jq -r '.[].name'` )
if [[ "${AZURE_CLUSTERS[$i]}" =~ "${C1PROJECT}" ]]; then
   printf "%s\n" "Deleting AKS cluster ${C1PROJECT}.   Please be patient, this can take up to 10 minutes... (started at:`date`)"
   starttime="$(date +%s)"
   az aks delete --name ${C1PROJECT} --resource-group ${C1PROJECT} --yes
   endtime="$(date +%s)"
   printf '%s\n' "deleted in $((($endtime-$starttime)/60)) minutes"
fi

# deleting Resource Group
# this also deletes the ACR

# printf "%s\n" "Checking Resource Groups"
AZURE_GROUPS=(`az group list -o json| jq -r '.[].name'` )
for i in "${!AZURE_GROUPS[@]}"; do
  if [[ "${AZURE_GROUPS[$i]}" == "${C1PROJECT}" ]]; then
    printf '%s\n' "Deleting Resource Group: ${AZURE_GROUPS[$i]}  Please be patient, this can take up to 10 minutes... (started at:`date`)"
    starttime="$(date +%s)"
    az group delete --name ${AZURE_GROUPS[$i]} --yes
    endtime="$(date +%s)"
    printf '%s\n' "deleted in $((($endtime-$starttime)/60)) minutes"
  fi
done

# deleting Project
# printf "%s\n" "Checking Azure Projects"
export AZURE_PROJECT_IDs=(`az devops project list --organization ${AZURE_ORGANIZATION_URL}  --output json| jq -r ".value[]|select(.name|test(\"${C1PROJECT}\"))|.id"` )
[ ${VERBOSE} -eq 1 ] &&  printf "%s" "Found the following Projects:  ${AZURE_PROJECT_IDs[@]}"
if [[ "${AZURE_PROJECT_IDs}" == "" ]]; then
  printf '%s \n' "Azure Project ${AZURE_PROJECT_IDs[@]} not found"
else
  for AZURE_PROJECT_ID in ${AZURE_PROJECT_IDs[@]}; do 
    printf '%s ' "Deleting Azure Project..."
    az devops project delete --id $AZURE_PROJECT_ID --organization ${AZURE_ORGANIZATION_URL}  --output none --yes
  done
fi

#get ${AZURE_PROJECT_UID}
if [ -f "${AZURE_PROJECT}_UID.txt" ]; then
    export AZURE_PROJECT_UID=`cat ${C1PROJECT}_UID.txt`
    #delete ServicePrincipals
    # Note the following command deletes all SPs that CONTAIN "${AZURE_PROJECT_UID}" in the name
    # We have to use this loose comparison because the SPs are created by Azure and Azure also defines the name of the SP.  The name is not an exact match with the #${AZURE_PROJECT_UID}, but luckilly, it does CONTAIN it
    SPs=(`az ad sp list --show-mine | jq -r ".[]| select (.appDisplayName | contains(\"${AZURE_PROJECT_UID}\")).appId"`) 
    [ ${VERBOSE} -eq 1 ] &&  printf "%s" "Found the following Service Principals for this project:  ${SPs[@]}"
    for SP in ${SPs[@]}; do 
      echo "Deleting Service Principal ${SP}"  
      az ad sp delete --id ${SP}
    done
    #delete ServiceEndpoints
    SEs=(`az devops service-endpoint list --detect true --project ${AZURE_PROJECT_UID} 2>/dev/null | jq -r ".[] | select(.serviceEndpointProjectReferences[].name = \"${AZURE_PROJECT_UID}\") | .id"`)
    [ ${VERBOSE} -eq 1 ] &&  printf "%s" "Found the following Service Endpoints for this project: ${SEs[@]}"
    for SE in ${SEs[@]}; do 
      echo "Deleting Service Endpoint ${SE}"  
      az devops service-endpoint delete --id ${SE} -y
    done
else
  printf "%s" "Could not find file with Project UID; could not delete Service Principals and Service Connections.  Manual Cleanup may be needed"
fi

printf '%s \n' "Deleting ~/.kube/config "
rm -rf ~/.kube/config
printf '%s \n' "Deleting ~/apps"
rm -rf ~/apps

