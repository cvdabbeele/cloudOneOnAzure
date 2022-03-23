#!/bin/bash
# update: 220311ß16Ö46
# . ./pipelines.sh ; ./pushWithHighSecurityThresholds.sh  DEPLOYMENT OK (x2), but first pipeline run fails due to missing ${DSSCxxxx  variables

# . ./pushWithHighSecurityThresholds.sh  ========DEPLOYMENT OK 
# up AFTER UP   . ./up.sh ; ./pushWithHighSecurityThresholds.sh  ====DEPLOMENT FAILS
# initial . ./up.sh ==========  deployment FAILS

printf '%s\n' "------------------------------"
printf '%s\n' "   Creating Azure pipelines   "
printf '%s\n' "------------------------------"


function createPipeline {
  #  ${1}=${APPx}
  export IMAGEREPOSITORY="${1//[[:digit:]]/}"
  #echo IMAGEREPOSITORY=$IMAGEREPOSITORY
  export CONTAINERREGISTRY="${AZURE_ACR}.azurecr.io"
  #echo CONTAINERREGISTRY="${CONTAINERREGISTRY}"
  export IMAGEPULLSECRET="${AZURE_PROJECT_UID}"
  #echo IMAGEPULLSECRET=$IMAGEPULLSECRET
  #export ENVIRONMENT="${1}.${C1PROJECT}-default"
  export ENVIRONMENT="${1}"
  #echo ENVIRONMENT=$ENVIRONMENT
  

  # cd into app
  cd ${APPSDIR}/${1}

  # check if old pipeline already exits; delete it if does 
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "Checking if old pipeline already exits; delete it if does "
  export AZPIPELINEID=(`az pipelines list  --project "${C1PROJECT}" 2>/dev/null| jq -r ".[] | select(.name== \"${1}\").id"  `)
  echo $AZPIPELINEID
  if  [[ ! -z "${AZPIPELINEID}" ]]; then 
    echo "Deleting old pipeline with id ${AZPIPELINEID}"
    [ ${VERBOSE} -eq 1 ] && az pipelines delete --id $AZPIPELINEID --project ${C1PROJECT} -y  
    az pipelines delete --id $AZPIPELINEID --project ${C1PROJECT} -y  2>/dev/null
  fi  

  #create azure-pipelines.yml
  printf '%s\n' "Creating azure-pipelines.yml file"
  export APP=${1}
  #TODO expand to APP2 and APP3
  export TREND_AP_KEY=${APP1KEY}
  export TREND_AP_SECRET=${APP1SECRET}
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "APP=${1}"

  echo "Cleaning up any old existing deployments"
  kubectl delete deployment ${APP}  2>/dev/null
  echo "Cleaning up any old existing services"
  kubectl delete service ${APP}  2>/dev/null

  envsubst < "${PROJECTDIR}/azure-pipelines.sample.yml"  > "./azure-pipelines.yml"
  #cp "${PROJECTDIR}/azure-pipelines.sample.yml" ./azure-pipelines.yml

  #sed -i "s/'\$(SERVICECONNECTIONFORDOCKERREGISTRY)'/${SERVICECONNECTIONFORDOCKERREGISTRY}/g" ./azure-pipelines.yml
  #sed -i "s/\$(_SERVICECONNECTIONFORDOCKERREGISTRY)/${SERVICECONNECTIONFORDOCKERREGISTRY}/g" ./azure-pipelines.yml

  export TAG="dummyTag"
  #cat ./azure-pipelines.yml

  #create manifests directory
  mkdir -p manifests

  #create deployment.yml
  #TODO need to scale this to multiple apps and define PORT with the right port number for each app; now using port 8080 
  export PORT="8080"
  printf '%s\n' "Creating manifests/deployment.yml"
  envsubst < "${PROJECTDIR}/deployment.sample.yml"  > ./manifests/deployment.yml
  #cat ./manifests/deployment.yml

  #create service.yml
  printf '%s\n' "Creating manifests/service.yml"
  envsubst <  "${PROJECTDIR}/service.sample.yml" >./manifests/service.yml
  [ ${VERBOSE} -eq 1 ] &&  cat ./manifests/service.yml && printf '\n'

  sed -i "s/IMAGEREPOSITORY/${IMAGEREPOSITORY}/g" ./manifests/service.yml
  sed -i "s/PORT/${80}/g" ./manifests/service.yml

 #pushing changes to azure git repo
   printf '%s\n' "Pushing manifests to Azure Git repo"
   [ ${VERBOSE} -eq 1 ] && DUMMY=`git add . `
   DUMMY=`git add . 2>/dev/null`
   [ ${VERBOSE} -eq 1 ] && DUMMY=`git commit -m "Initial commit by CloudOneOnAzure" `
   DUMMY=`git commit -m "Pipeline configuration still in progress.  This run will fail" 2>/dev/null`
   [ ${VERBOSE} -eq 1 ] && DUMMY=`git push azure master`
   DUMMY=`git push azure master 2>/dev/null`

  #printf '%s\n' "--------------------------3. Testing Docker Login to ACR, using Username {ACR_USERNAME} and ACR_PASSWORD (redacted)"
  #docker login  ${AZURE_PROJECT_UID}.azurecr.io -u ${ACR_USERNAME} -p ${ACR_PASSWORD} 

  #Testing Docker Login to ACR, using Service Principal SP_APP_ID and SP_PASSWD"
  #printf '%s\n' "--------------------------4a.Testing Docker Login to ACR, using Service Principal SP_APP_ID and SP_PASSWD"
  #docker login ${AZURE_PROJECT_UID}.azurecr.io  -u $SP_APP_ID  -p $SP_PASSWD

  # create azure devops pipeline for ${1}
  printf "%s" "Creating azure devops pipeline for ${1}"
  export PIPELINECREATERESULT=`az pipelines create --name ${1} \
    --description "Pipeline for ${1}" \
    --project "${C1PROJECT}" \
    --repository "${1}" \
    --branch master  \
    --repository-type tfsgit \
    --yml-path "azure-pipelines.yml"`
    # note: the "--yml-path" is the path to the pipelineFile in the REPO
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "PIPELINECREATERESULT=$PIPELINECREATERESULT"
  export PIPELINEID=`echo ${PIPELINECREATERESULT} | jq -r ".definition.id"`
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "   PIPELINEID=" $PIPELINEID
  #NOTE: the above throws the following error:
  # input containerRegistry references service connection xxx which could not be found. The service connection does not exist or has not been authorized for use.
  # that is correct, but the service connection cannot be assigned to the pipeline until the PIPELINEID is known ...  catch22 problem

  # printf '%s\n' "Saving existing pipeline variables to AZ_PIPELINE_VARS.tmp"
  #az pipelines variable list  --pipeline-name ${1} --project ${C1PROJECT} >  AZ_PIPELINE_VARS.tmp
  printf '%s' "Pushing variables to Azure pipelines "
 
  export PIPELINE_VARS=(SERVICECONNECTIONFORKUBERNETES IMAGEPULLSECRET APP PULL_AUTH DSSC_HOST DSSC_USERNAME DSSC_TEMPPW DSSC_PASSWORD DSSC_REGUSER DSSC_REGPASSWORD TREND_AP_KEY TREND_AP_SECRET AZURE_ACR_LOGINSERVER C1PROJECT TAG ACR_USERNAME ACR_PASSWORD )

  for pipelineVar in ${PIPELINE_VARS[@]}; do
      [ ${VERBOSE} -eq 1 ] && printf '%s\n' "${pipelineVar}=${!pipelineVar}"
      printf '%s' "." 
      DUMMY=`az pipelines variable create --pipeline-name ${1} --project ${C1PROJECT} --name ${pipelineVar} --value ${!pipelineVar} 2>/dev/null`
      [ ${VERBOSE} -eq 1 ] && printf '%s\n' ${DUMMY}
  done
  printf '\n' 

  # granting pipeline the permissions to use Service Endpoints
  # https://github.com/Azure/azure-devops-cli-extension/issues/960
  # ERROR; "This pipeline needs permission to access a resource before this run can continue to Build stage"
  # -> it is the service-connections that needs permissions
  cat <<EOF > params.json
  {
      "pipelines": [
          {
              "id": "${PIPELINEID}",
              "authorized": "true"
          }
      ]
  }
EOF

  printf '%s\n' "Granting pipeline the permissions to use Service Endpoint for Registry access"
  DUMMY=`az devops invoke --area pipelinepermissions --organization ${AZURE_ORGANIZATION_URL} --resource pipelinePermissions --route-parameters project=${C1PROJECT} resourceType=endpoint resourceId=${SERVICECONNECTIONFORDOCKERREGISTRY} --in-file params.json --http-method PATCH --api-version "5.1-preview1"`
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "$DUMMY"


  printf '%s\n' "Granting pipeline the permissions to use Service Endpoint for Kubernetes deployment"
  DUMMY=`az devops invoke --area pipelinepermissions --organization ${AZURE_ORGANIZATION_URL} --resource pipelinePermissions --route-parameters project=${C1PROJECT} resourceType=endpoint resourceId=${SERVICECONNECTIONFORKUBERNETES} --in-file params.json --http-method PATCH --api-version "5.1-preview1"`
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "$DUMMY"


  # Allow Pipeline access to Environment
  printf '%s\n' "Granting pipeline the permissions to the Environment"
  #get the Azure Environment ID 
  AZENVIRONMENTID=`az devops invoke --area distributedTask --organization ${AZURE_ORGANIZATION_URL} --resource environments --route-parameters project=${C1PROJECT} --organization ${AZURE_ORGANIZATION_URL}  --api-version "6.0-preview" -o json | jq -r --arg PROJECT_ID ${AZURE_PROJECT_UID} ".value[] | select(.name==\"${1}\") | .id"`
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "AZENVIRONMENTID=$AZENVIRONMENTID"
  DUMMY=`az devops invoke --area pipelinepermissions --organization ${AZURE_ORGANIZATION_URL} --resource pipelinePermissions --route-parameters project=${C1PROJECT}  resourceType=environment resourceId=${AZENVIRONMENTID} --in-file params.json --http-method PATCH --api-version "6.0-preview" `
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" "$DUMMY"

  #triggering a pipeline run
  printf '%s\n' "Triggering a pipeline run for ${1}"
  printf '%s\n' "Pushing changes to ${1} registry"
  echo " " >>README.md
  DUMMY=`git add . 2>/dev/null`
  DUMMY=`git commit -m "First commit by \"add_demoApps\"" 2>/dev/null`
  DUMMY=`git push azure master 2>/dev/null`  

  #printf '%s\n' "Saving Service-endpoints AFTER pipeline create to serviceEndpointsAfterPipeline.json"
  az devops service-endpoint list --detect true --project ${C1PROJECT}  > serviceEndpointsAfterPipeline.json
  #printf '%s\n' "Saved to serviceEndpointsAfterPipeline.json"

  #printf '%s\n' "--------------------------4b.Testing Docker Login to ACR, using Service Principal SP_APP_ID and SP_PASSWD"
  #docker login ${AZURE_PROJECT_UID}.azurecr.io  -u $SP_APP_ID  -p $SP_PASSWD

  #returning to the main project directory
  cd ${PROJECTDIR}

}  ## end of function createPipeline












#set default project
#az devops configure --default project=${AZURE_ORGANIZATION_URL}

export DSSC_HOST=`kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
export DSSC_HOST=${DSSC_HOST//./-}.nip.io

VARSAREOK=true
if  [ -z "${AZURE_LOCATION=}" ]; then echo AZURE_LOCATION= must be set && VARSAREOK=false; fi
if  [ -z "${C1PROJECT}" ]; then echo ${C1PROJECT} must be set && VARSAREOK=false; fi
if  [ -z "${AZURE_ORGANIZATION}" ]; then echo AZURE_ORGANIZATION must be set  && VARSAREOK=false; fi
if  [ -z "${APP1}" ]; then echo APP1 must be set && VARSAREOK=false; fi
if  [ -z "${APP1_GIT_URL}" ]; then echo APP1_GIT_URL must be set  && VARSAREOK=false; fi
#if  [ -z "${APP2}" ]; then echo APP2 must be set && VARSAREOK=false; fi
#if  [ -z "${APP2_GIT_URL}" ]; then echo APP2_GIT_URL must be set  && VARSAREOK=false; fi
#if  [ -z "${APP3}" ]; then echo APP3 must be set && VARSAREOK=false; fi
#if  [ -z "${APP3_GIT_URL}" ]; then echo APP3_GIT_URL must be set  && VARSAREOK=false; fi
if  [ "$VARSAREOK" = false ]; then  
   read -p "Fix the above-mentioned variables and press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
fi

#create ImagePullSecret for SmartCheck
DUMMY=`az acr update -n ${AZURE_ACR} --admin-enabled true`
export ACR_CREDENTIALS=$(az acr credential show --name ${AZURE_ACR})
export ACR_PASSWORD=$(jq -r '.passwords[] | select(.name=="password") | .value' <<< $ACR_CREDENTIALS)
export ACR_USERNAME=$(jq -r '.username' <<< $ACR_CREDENTIALS)
export PULL_AUTH="{\"username\":\"${ACR_USERNAME}\",\"password\":\"${ACR_PASSWORD}\"}"
#echo ACR_PASSWORD=${ACR_PASSWORD}
#echo ACR_USERNAME=${ACR_USERNAME}
#printf '%s\n' "--------------------------1. Testing Docker Login to ACR, using Username {ACR_USERNAME} and ACR_PASSWORD (redacted)"
#docker login  ${AZURE_PROJECT_UID}.azurecr.io -u ${ACR_USERNAME} -p ${ACR_PASSWORD} 

#delete old ServicePrincipals
# Note the following command deletes all SPs that CONTAIN "${C1PROJECT}"
# We have to use this loose comparison because the SPs are created by Azure and Azure also defines the name of the SP.  The name is not an exact match with the #${C1PROJECT}, but luckilly, it does CONTAIN it
SPs=(`az ad sp list --show-mine | jq -r ".[]| select (.appDisplayName | contains(\"${C1PROJECT}\")).appId"`) 
for SP in ${SPs[@]}; do echo "Deleting Service Principal ${SP}"  && az ad sp delete --id ${SP}; done

# create a Service Principal (and password in the same action) to register ACR with AAD 
# this is required to create login-credentials for SmartCheck for logging in to ACR 
# Default permissions are for docker pull access. Modify the '--role' argument 
# to one of the following:
# acrpull:     pull only
# acrpush:     push and pull
# owner:       push, pull, and assign roles

export SP_PASSWD=""
printf '%s\n' "Creating new Service Principal ${AZURE_PROJECT_UID} (including a password)"
export SP_PASSWD=$(az ad sp create-for-rbac --name ${AZURE_PROJECT_UID} --query password --output tsv )
#export SP_PASSWD=$(az ad sp create-for-rbac --name ${AZURE_PROJECT_UID} --scopes $ACR_REGISTRY_ID --role owner --query password --output tsv )
if [ -z "${SP_PASSWD}" ]; then
  printf '%s\n' "Failed to create a new Service Principal"  
  read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
  printf '%s\n' 
fi
printf '%s\n' "Getting Service Principal Id"
export SERVICEPRINCIPALID=$(az ad sp list --display-name ${AZURE_PROJECT_UID} | jq -r ".[].objectId")
#printf '%s\n' "Service Principal Id=${SERVICEPRINCIPALID}"
export SP_APP_ID=$(az ad sp list --display-name ${AZURE_PROJECT_UID} | jq -r ".[].appId")
#printf '%s\n' "SP_APP_ID=$SP_APP_ID"

kubectl create secret docker-registry ${C1PROJECT}dockersecret \
    --namespace default \
    --docker-server=${AZURE_ACR}.azurecr.io \
    --docker-username=${SERVICEPRINCIPALID} \
    --docker-password=${SP_PASSWD}  2>/dev/null

# Testing AZ ACR Login, using token
printf '%s' "Testing AZ ACR Login, using token..."
az acr login --name ${AZURE_PROJECT_UID}

#delete old ServiceEndpoints
printf '%s\n' "Checking old Service Endpoints"

SEs=(`az devops service-endpoint list --detect true --project ${C1PROJECT} --organization ${AZURE_ORGANIZATION_URL} | jq -r ".[] | select(.serviceEndpointProjectReferences[].name = \"${C1PROJECT}\") | .id"`)
echo Service Endpoint are $SEs
for SE in ${SEs[@]}; do 
  printf '%s\n' "Deleting old Service Endpoint ${SE} for this project"  
  az devops service-endpoint delete --id ${SE} --organization ${AZURE_ORGANIZATION_URL} --project ${C1PROJECT} -y
done

#create a ServiceEndpoint and a SERVICECONNECTIONFORDOCKERREGISTRY

# list all service endpoints
#printf '%s\n' "list all service endpoints"
#az devops service-endpoint list --detect true --project ${C1PROJECT}

# create a service endpoint of type "dockerregistry" for use in the pipeline (SERVICECONNECTIONFORDOCKERREGISTRY)
# source : https://github.com/Azure/azure-devops-cli-extension/issues/706
# source : https://roadtoalm.com/2020/02/26/creating-an-azure-container-registry-service-connection-in-azure-devops-with-your-own-serviceprincipal/
# using Username/Password auth: https://docs.microsoft.com/en-us/azure/devops/cli/service-endpoint?view=azure-devops

export ROLE_ACR_PUSH=`az role definition list --name AcrPush | jq -r ".[].name"`
export ACR_URL=`az acr list --resource-group ${C1PROJECT} | jq -r '.[].loginServer'`

#alternatively: "servicePrincipalId": "placeholder",
#alternatively: "servicePrincipalId": "${SERVICEPRINCIPALID}"
#serviceprincipalkey seems to be ignored

cat <<EOF > service-endpoint.json
{
    "authorization": {
        "scheme": "UsernamePassword",
        "parameters": {
          "email": "",
          "registry": "https://${ACR_URL}",
          "username": "${ACR_USERNAME}",
          "password": "${ACR_PASSWORD}"
        }
    },
    "data": {
        "appObjectId": "",
        "azureSpnPermissions": "",
        "azureSpnRoleAssignmentId": "",
        "registryId": "${ACR_REGISTRY_ID}",
        "registrytype": "Others",
        "spnObjectId": "",
        "subscriptionId": "`az account show | jq -r '.id'`",
        "subscriptionName": "`az account show | jq -r '.name'`"
    },
    "description": "",
    "groupScopeId": null,
    "name": "ACRserviceConnectionFor${AZURE_ACR}",
    "operationStatus": null,
    "readersGroup": null,
    "serviceEndpointProjectReferences": null,
    "type": "dockerregistry",
    "url": "https://${AZURE_ACR}.azurecr.io",
    "isShared": false,
    "owner": "library"
}
EOF

#create new ServiceEndpoint for ACR access
printf '%s' "Creating new ServiceEndpoint for ACR access..."
export SERVICE_ENDPOINT_NAME="serviceConnectionForACR${AZURE_ACR}"
export SERVICECONNECTIONFORDOCKERREGISTRY=`az devops service-endpoint create --service-endpoint-configuration service-endpoint.json --organization ${AZURE_ORGANIZATION_URL} --project "${C1PROJECT}" --verbose 2>/dev/null| jq -r ".id"`
if [[ ! -z ${SERVICECONNECTIONFORDOCKERREGISTRY}  ]];then
  printf '%s\n' " created; id=${SERVICECONNECTIONFORDOCKERREGISTRY}"
  echo ${SERVICECONNECTIONFORDOCKERREGISTRY} > work/SERVICECONNECTIONFORDOCKERREGISTRY.json
else
  printf "\n%s\n" "ERROR: Failed to create Service Conection for ACR"
  read  -n 1 -p "Press ENTER to deploy pipelines_v2c.sh or CTRL-C to break" dummyinput
fi
#echo SERVICECONNECTIONFORDOCKERREGISTRY="${SERVICECONNECTIONFORDOCKERREGISTRY}"

DUMMY=`az devops service-endpoint update --id ${SERVICECONNECTIONFORDOCKERREGISTRY} --enable-for-all true --organization ${AZURE_ORGANIZATION_URL} --project ${C1PROJECT}`
#az devops invoke --http-method patch --area build --resource authorizedresources --debug --route-parameters project=${C1PROJECT} --api-version 5.0-preview --in-file ./service-endpoint.json --encoding ascii
[ ${VERBOSE} -eq 1 ] && printf "%s\n" "${DUMMY}"


# create a service endpoint of type "kubernetes" for use in the pipeline 
# https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments-kubernetes?view=azure-devops
cat <<EOF > service-endpoint-kubernetes.json
{
  "authorization": {
        "scheme": "Kubernetes",
        "parameters": {
          "azureEnvironment": "AzureCloud",
          "azureTenantId": "`az account show | jq -r .tenantId`"
          }
    },
  "createdBy": {},
  "data": {
      "authorizationType": "AzureSubscription",
      "azureSubscriptionId": "`az account show --query id --output tsv`",
      "azureSubscriptionName": "`az account show --query name --output tsv`",
      "clusterId": "/subscriptions/`az account show --query id --output tsv`/resourcegroups/${C1PROJECT}/providers/Microsoft.ContainerService/managedClusters/${C1PROJECT}",
      "namespace": "default",
      "clusterAdmin": "true"

    },
    "isShared": false,
    "name": "serviceConnectionForKubernetes${AZURE_ACR}",
    "owner": "library",
    "type": "kubernetes",
    "url": "`kubectl config view --minify -o 'jsonpath={.clusters[0].cluster.server}'`",
    "administratorsGroup": null,
    "description": "serviceConnectionForKubernetes${AZURE_ACR}",
    "groupScopeId": null,
    "operationStatus": null,
    "readersGroup": null,
    "serviceEndpointProjectReferences": [
      {
        "description": "",
        "name": "${C1PROJECT}-default",
        "projectReference": {
          "id": "`az devops project list --organization ${AZURE_ORGANIZATION_URL} | jq -r ".value[] | select(.name==\"$C1PROJECT\")|.id"`",
          "name": "`az devops project list --organization ${AZURE_ORGANIZATION_URL} | jq -r ".value[]| select(.name==\"$C1PROJECT\")|.name"`"
        }
      }
    ]
}
EOF
printf '%s' "Creating new ServiceEndpoint for kubernetes access"
export SERVICE_ENDPOINT_NAME="serviceConnectionForACR${AZURE_ACR}"
export SERVICECONNECTIONFORKUBERNETES=""
export SERVICECONNECTIONFORKUBERNETES=`az devops service-endpoint create --service-endpoint-configuration service-endpoint-kubernetes.json --organization ${AZURE_ORGANIZATION_URL} --project "${C1PROJECT}" --verbose | jq -r ".id"`
#echo SERVICECONNECTIONFORKUBERNETES="${SERVICECONNECTIONFORKUBERNETES}"
if [[ ! -z ${SERVICECONNECTIONFORKUBERNETES}  ]];then
  printf '%s\n' " id=${SERVICECONNECTIONFORKUBERNETES}"
else
  printf "\n%s\n" "ERROR: Failed to create Service Conection for K8S"
  read  -n 1 -p "Press ENTER to deploy pipelines_v2c.sh or CTRL-C to break" dummyinput
fi
#az devops service-endpoint update --id ${SERVICECONNECTIONFORKUBERNETES} --enable-for-all true  --org ${AZURE_ORGANIZATION_URL} -p ${C1PROJECT}

#az devops invoke --http-method patch --area build --resource authorizedresources --debug --route-parameters project=${C1PROJECT} --api-version 5.0-preview --in-file ./service-endpoint-kubernetes.json --encoding ascii




createPipeline ${APP1}
#createPipeline ${APP2}
#createPipeline ${APP3}

