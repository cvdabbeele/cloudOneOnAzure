
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

printf '%s\n' "Deploying ${APP2} (from ${APP2_GIT_URL})"
setupApp ${APP2} ${APP2_GIT_URL}

printf '%s\n' "Deploying ${APP3} (from ${APP3_GIT_URL})"
setupApp ${APP3} ${APP3_GIT_URL}

cd $PROJECTDIR

