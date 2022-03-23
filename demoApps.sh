
#!/bin/bash
printf '%s\n' "----------------------"
printf '%s\n' "   Adding Demo-apps   "
printf '%s\n' "----------------------"

export DSSC_HOST=`kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`.nip.io
#checking required variables
VARSAREOK=true
if  [ -z "$AZURE_LOCATION" ]; then echo AZURE_LOCATION must be set && VARSAREOK=false; fi
if  [ -z "$AZURE_ORGANIZATION" ]; then echo AZURE_ORGANIZATION must be set && VARSAREOK=false; fi
if  [ -z "$AZURE_ORGANIZATION_URL" ]; then echo AZURE_ORGANIZATION_URL must be set && VARSAREOK=false; fi
if  [ -z "${APP1_GIT_URL}" ]; then echo APP1_GIT_URL must be set && VARSAREOK=false; fi
#if  [ -z "${APP2_GIT_URL}" ]; then echo APP2_GIT_URL must be set && VARSAREOK=false; fi
#if  [ -z "${APP3_GIT_URL}" ]; then echo APP3_GIT_URL must be set && VARSAREOK=false; fi
if  [ "$VARSAREOK" = false ]; then exitdebug 1 ; fi

function setupApp {
  #${1}=appname e.g. ${APP1}, ${APP2} 
  #${2}=downloadURL for application on public git ${APP1_GIT_URL}
  cd ${APPSDIR}
  printf '%s\n' " Cloning ${1} from public git"
  git clone ${2} ${1}  1>/dev/null 2>/dev/null
  cd ${1}
 #####
 # git checkout newauth
 #####
  rm -rf .git
 ##### 
  #update Dockerfile for newauth to C1
  #sed -i 's/#accountbased //g' Dockerfile 
 ####
  git init 1>/dev/null 2>/dev/null
  #read  -n 1 -p "Press ENTER to continue" dummyinput
  printf '%s\n'  " Creating internal Azure GIT for ${1}"
  AZURE_GIT_REPO_JSON=`az repos create --name ${1} --project ${C1PROJECT} --organization ${AZURE_ORGANIZATION_URL}`
  [ ${VERBOSE} -eq 1 ] && printf "%s\n" printf "AZURE_GIT_REPO_JSON=${AZURE_GIT_REPO_JSON}"
  printf '%s\n'  " Initializing git for internal Azure GIT"
  git remote add azure https://${AZURE_DEVOPS_EXT_PAT}@${AZURE_ORGANIZATION_URL//https:\/\//}/${C1PROJECT}/_git/${1}  
  git config --global user.email ${C1PROJECT}@example.com
  git config --global user.name ${C1PROJECT}
  git config --global push.default simple
  git add .   
  git commit -m "Initial commit by \"demoApps.sh\""  1>/dev/null #2>/dev/null
  printf '%s\n'  " Pushing ${1} to internal Azure GIT"
  git push azure master   1>/dev/null 2>/dev/null
  
  cd $PROJECTDIR
}   
#end of function------------------------------------------------------------------------------------------

az devops configure --default project=${AZURE_ORGANIZATION_URL}

# Create UniqueID for this project
# some things in Azure devOps have to be unique
##  e.g. ACR names must be globally unique; see below
#check if we already have a running deployment 

if [ -f "${C1PROJECT}_UID.txt" ]; then
  export AZURE_PROJECT_UID_OLD=`cat "${C1PROJECT}_UID.txt"`
  echo ${AZURE_PROJECT_UID_OLD} > "${C1PROJECT}_UID_OLD.txt"
fi
#printf '%s\n' "AZURE_PROJECT_UID_OLD = ${AZURE_PROJECT_UID_OLD}"

#create a new UID 
export AZURE_PROJECT_UID="${C1PROJECT}$(openssl rand -hex 4)"
printf '%s\n' "Created new Azure Project UID for naming ACR etc...${AZURE_PROJECT_UID}"
## (it is not a real UID, but in combination with the ${C1PROJECT} name it is close enough)
printf '%s' "${AZURE_PROJECT_UID}" > "${C1PROJECT}_UID.txt"

# Azure ACR
## if old ACR exists, then delete it first
## ACR names must be globally unique, see above
if [ "${AZURE_PROJECT_UID_OLD}" != "" ];then
  printf '%s\n' "Deleting old ACR registry ${AZURE_PROJECT_UID_OLD}"
  az acr delete -n ${AZURE_PROJECT_UID_OLD} -g ${C1PROJECT} -y
fi
## create new ACR  (ACRs must have a globally unique name)
printf '%s\n' "Creating Azure ACR registry ${AZURE_PROJECT_UID}"
export AZURE_ACR=`az acr create -n ${AZURE_PROJECT_UID} -g ${C1PROJECT} --sku Standard | jq -r ".name"`
printf '%s\n' "Created Azure ACR registry ${AZURE_ACR}.azurecr.io"

export AZURE_ACR_REPO_ID=`az acr list --resource-group ${C1PROJECT} --output json| jq -r ".[]|select(.name|test(\"${AZURE_ACR}\"))|.id"` 
#export AZURE_ACR_LOGINSERVER=`az acr list --resource-group ${C1PROJECT} --output json| jq -r ".[]|select(.name|test(\"${AZURE_ACR}\"))|.loginServer"`
export AZURE_ACR_LOGINSERVER="${AZURE_PROJECT_UID}.azurecr.io"
export ACR_REGISTRY_ID=`az acr list --resource-group ${C1PROJECT} --output json| jq -r ".[]|select(.name|test(\"${AZURE_ACR}\"))|.id"`

if [ "`az acr login --name  ${AZURE_PROJECT_UID}`" == "Login Succeeded" ];then  
  printf '%s\n' "  Login to ACR is successful"
else
  printf '%s\n' "  ERROR: failed to login to ACR"
fi

# Creating Service Principal to register ACR with AAD 
# this is required to create login-credentials for SmartCheck for logging in to ACR 
# Default permissions are for docker pull access. Modify the '--role' argument 
# to one of the following:
# acrpull:     pull only
# acrpush:     push and pull
# owner:       push, pull, and assign roles

# SERVICE_PRINCIPAL_NAME: Must be unique 
#####SERVICE_PRINCIPAL_NAME=${AZURE_PROJECT_UID}

#check if old service principal exists and delete it
#####if [ ! -z "${AZURE_PROJECT_UID_OLD}" ];then  
#####  #running the delete with empty AZURE_PROJECT_UID_OLD would delete ALL your SPs !!!
#####  SPs=(`az ad sp list --show-mine | jq -r ".[]| select (.appDisplayName == \"${AZURE_PROJECT_UID_OLD}\").appId"`) && for SP in ${SPs[@]}; do echo "Deleting old Service Principal ${SP}"  && az ad sp delete --id ${SP}; done
#####fi

#check if current service principal exists and delete it
#####if [ ! -z "${AZURE_PROJECT_UID}" ];then  
#####  #running the delete with empty AZURE_PROJECT_UID would delete ALL your SPs !!!
#####  SPs=(`az ad sp list --show-mine | jq -r ".[]| select (.appDisplayName == \"${AZURE_PROJECT_UID}\").appId"`) && for SP in ${SPs[@]}; do echo "Deleting old Service Principal ${SP}"  && az ad sp delete --id ${SP}; done
##### fi

##### #create new ServicePrincipal (and password in the same action)
##### printf '%s\n' "Creating new Service Principal ${AZURE_PROJECT_UID} (including a password)"
##### export SP_PASSWD=$(az ad sp create-for-rbac --name ${AZURE_PROJECT_UID} --scopes $ACR_REGISTRY_ID --role owner --query password --output tsv )
##### if [ -z "${SP_PASSWD}" ]; then
#####   printf '%s\n' "Failed to create a new Service Principal"  
#####   printf '%s\n' "----------------------------------------"
#####   printf '%s\n' "Error: The directory object quota limit for the Principal has been exceeded"
#####   printf '%s\n' "probably you still have old SPs that should be deleted"
#####   printf '%s\n' "this is the list of you Service Principals"
#####   printf '%s\n' "------------------------------------------"
#####   az ad sp list --show-mine | jq -r ".[]| [.appDisplayName, .appId, .oauth2Permissions[].adminConsentDescription]| @tsv"
#####   printf '%s\n' "Delete the ones that you no longer need."
#####   printf '%s\n' "Use the following commands:"
#####   printf '%s\n' "1. Define a variable with (sub-)string of the name of the SPs to be deleted"
#####   printf '%s\n' "SPsToDelete=\"testSP\""
#####   printf '%s\n' "1. Delete them as follows:"
    # SPs=(`az ad sp list --show-mine | jq -r ".[]| select (.appDisplayName | contains(\"${SPsToDelete}\")).appId"`) && for SP in ${SPs[@]}; do echo "deleting ${SP}"  && az ad sp delete --id ${SP}; done
#####   printf '%s\n' "SPs=(\`az ad sp list --show-mine | jq -r \".[]| select (.appDisplayName | contains(\\\"\${SPsToDelete}\\\")).appId\"\`) && for SP in \${SPs[@]}; do echo \"deleting \${SP}\"  && az ad sp delete --id \${SP}; done"
#####   read  -n 1 -p "Press CTRL-C to break the script, it will fail anyway" dummyinput
##### else
#####   printf '%s\n' "Service Principal created" 
##### fi

##### printf '%s\n' "SP_PASSWD=[REDACTED]"  #${SP_PASSWD}"
##### #printf '%s\n' "Getting Service Principal Id"
##### export SERVICE_PRINCIPAL_ID=$(az ad sp list --display-name ${AZURE_PROJECT_UID} | jq -r ".[].objectId")
##### printf '%s\n' "Service Principal Id=${SERVICE_PRINCIPAL_ID}"
##### export SP_APP_ID=$(az ad sp list --display-name ${AZURE_PROJECT_UID} | jq -r ".[].appId")
##### echo SP_APP_ID=$SP_APP_ID
##### printf '%s\n' "Testing Docker Login to ACR, using Service Principal SP_APP_ID and SP_PASSWD"
##### docker login ${AZURE_PROJECT_UID}.azurecr.io  -u $SP_APP_ID  -p $SP_PASSWD


# Output the service principal's credentials; use these in your services and
# applications to authenticate to the container registry.
## echo "SERVICE_PRINCIPAL_NAME=$SERVICE_PRINCIPAL_NAME"
## echo "Service principal ID: $SERVICE_PRINCIPAL_ID"           #something like:5763d5a-77db-4af8-8f63-f1d5e4318f19
## echo "Service principal password: $SP_PASSWD"     #something like:tKsc-RTbt34i2jaPR94g9X5pWtQChg~2IE
## echo AZURE_ACR_REPO_ID=$AZURE_ACR_REPO_ID
## echo AZURE_ACR_LOGINSERVER=$AZURE_ACR_LOGINSERVER
## echo ACR_REGISTRY_ID=$ACR_REGISTRY_ID









# AZ devops Project
# Creating an AZ devops project also creates a git repo with the same name
## pipelines also reside under this AzureDevOpsProject (they will be created in pipelines.sh)
## if an old Project with the same name exists, then delete it first
## ##  Project names must be unique within an AD tenant; so must be ${C1PROJECT}; we can just use ${C1PROJECT} for the Project name

export AZURE_DEVOPS_PROJECT_ID=(`az devops project list --organization ${AZURE_ORGANIZATION_URL}  --output json| jq  -r ".value[]|select(.name==\"${C1PROJECT}\")|.id"` )
if [ "${AZURE_DEVOPS_PROJECT_ID}" != "" ]; then
  printf '%s\n' "Deleting old Azure DevOps project ${C1PROJECT} with ID ${AZURE_DEVOPS_PROJECT_ID}"
  DUMMY=`az devops project delete --id ${AZURE_DEVOPS_PROJECT_ID} --organization ${AZURE_ORGANIZATION_URL} -y`
fi
# Create Azure DevOps Project
printf '%s\n' "(re-)Creating Azure DevOps Project "
export AZURE_DEVOPS_PROJECT_ID=`az devops project create --name ${C1PROJECT} --description 'Created by CloudOneOnAzure' --source-control git  --visibility private --organization ${AZURE_ORGANIZATION_URL} --output json| jq  -r ".id"`
    #--output none    
printf '%s\n' "Created Azure DevOps Project ${C1PROJECT} with ID ${AZURE_DEVOPS_PROJECT_ID}"

#set default azure project 
az devops configure --defaults project=${C1PROJECT}

#deleting any potential old Apps
rm -rf ${APPSDIR}
mkdir -p  ${APPSDIR}

# Deploying Apps
printf '%s\n' "Deploying ${APP1} (from ${APP1_GIT_URL})"
setupApp ${APP1} ${APP1_GIT_URL}

#printf '%s\n' "Deploying ${APP2} (from ${APP2_GIT_URL})"
#setupApp ${APP2} ${APP2_GIT_URL}

#printf '%s\n' "Deploying ${APP3} (from ${APP3_GIT_URL})"
#setupApp ${APP3} ${APP3_GIT_URL}

cd $PROJECTDIR

