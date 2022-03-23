
#!/bin/bash
printf '%s \n'  "-----------------------"
printf '%s \n'  "    AKS cluster"
printf '%s \n'  "-----------------------"

# Check required variables
VARSAREOK=true

if  [ -z "$AZURE_LOCATION" ]; then echo AZURE_LOCATION must be set && VARSAREOK=false; fi
if  [ -z "${C1PROJECT}" ]; then echo ${C1PROJECT} must be set && VARSAREOK=false; fi
if  [ -z "$AZUREAKSNODES" ]; then echo AZUREAKSNODES must be set && VARSAREOK=false; fi

if  [ "$VARSAREOK" = "false" ]; then 
   read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)" 
fi

# Create Resource Group:
# -----------------------
#AKS Resource Group
[ ${VERBOSE} -eq 1 ] &&  printf '%s\n' "Azure Resource Group "
export AZURE_GROUP=( `az group list -o json| jq -r  ".[]|select(.name|test(\"${C1PROJECT}\"))|.name"` )
[ ${VERBOSE} -eq 1 ] &&  printf '%s\n' "found existing AZURE_GROUP (${AZURE_GROUP}) with name of this project (${C1PROJECT})"

if [[ "${AZURE_GROUP}" = "" ]]; then
  printf '%s\n' "Creating Resource Group: ${C1PROJECT}"
  dummy=`az group create --name ${C1PROJECT} --location ${AZURE_LOCATION}`
else
  printf "%s\n" "Reusing existing Resource Group ${C1PROJECT}"
fi
export AZURE_GROUP=( `az group list -o json| jq -r  ".[]|select(.name|test(\"${C1PROJECT}\"))|.name"` )


#AKS cluster
AZURE_CLUSTER_exists="false"
export AZURE_CLUSTERS=( `az aks list -o json| jq -r '.[].name'` )
for i in "${!AZURE_CLUSTERS[@]}"; do
  #printf "%s" "cluster $i =  ${AZURE_CLUSTERS[$i]}.........."
  if [[ "${AZURE_CLUSTERS[$i]}" =~ "${C1PROJECT}" ]]; then
      printf "%s\n" "Reusing existing AKS cluster ${C1PROJECT}"
      AZURE_CLUSTER_exists="true"
      break
  fi
done

if [[ "${AZURE_CLUSTER_exists}" != "true" ]]; then
    #printf '%s\n' "Creating AKS cluster: ${C1PROJECT}"
    starttime=`date +%s`
    printf '%s\n' "Creating a ${AZUREAKSNODES}-node AKS cluster named \"${C1PROJECT}\" in location ${AZURE_LOCATION}"

    printf '%s\n' " This typically takes between 2 and 10 minutes (started at: `date`)"
    # https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create
    DUMMY=`az aks create --resource-group ${C1PROJECT} --name ${C1PROJECT} --node-count $AZUREAKSNODES --enable-addons monitoring  --load-balancer-managed-outbound-ip-count 1 --generate-ssh-keys`
    endtime="$(date +%s)"
    #printf '%s\n' "Elapsed time: $((($endtime-$starttime)/60)) minutes"
    endtime=`date +%s`
    if [[ `az aks list --resource-group ${C1PROJECT} | jq -r ".[].name"` = "${C1PROJECT}" ]]; then
       printf '\n%s\n' " AKS cluster ${C1PROJECT} created.  Elapsed time: $((($endtime-$starttime)/60)) minutes"
    else
       printf '\n%s\n' "ERROR: Failed to create AKS cluster ${C1PROJECT}"
    fi
fi

#Configure kubectl:
printf '%s \n'  "Configuring credentials for kubectl"
az aks get-credentials --resource-group ${C1PROJECT} --name ${C1PROJECT}


