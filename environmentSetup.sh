#!/bin/bash
printf '%s\n' "-------------------------------------"
printf '%s\n' "     Installing / Checking Tools     "
printf '%s\n' "-------------------------------------"

VARSAREOK=true

# Validating the shell
if [ -z "$BASH_VERSION" ]; then
    printf '%s\n' "Error: this script requires the BASH shell!"
    read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
fi

# Installing packages  
printf '%s\n'  "Updating Package Manager"
if  [ -x "$(command -v apt-get)" ] ; then
  sudo apt-get -qq update 1>/dev/null 2>/dev/null
  sudo apt-get -qq install ca-certificates curl apt-transport-https lsb-release gnupg jq -y
else
   printf '%s' "Cannot install packages... no supported package manager found, must run on Debian/Ubuntu"
  read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
fi 

# Installing jq
if ! [ -x "$(command -v jq)" ] ; then
    printf '%s\n'  "installing jq"
    if  [ -x "$(command -v apt-get)" ] ; then
      sudo apt-get install jq -y
    elif  [ -x "$(command -v yum)" ] ; then
      sudo yum install jq -y
    else
      printf '%s' "Cannot install jq... no supported package manager found"
      read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
    fi 
else
    printf '%s\n' "Using existing jq.  Version : `jq --version 2>/dev/null`"
fi

# Installing kubectl
printf '%s\n' "Installing/upgrading kubectl...."
sudo curl --silent -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
sudo chmod +x /usr/local/bin/kubectl

# Installing helm
if ! [ -x "$(command -v helm)" ] ; then
    printf '%s\n'  "installing helm...."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
else
    printf '%s\n'  "Using existing helm.  Version" `helm version  | awk -F',' '{ print $1 }' | awk -F'{' '{ print $2 }' | awk -F':' '{ print $2 }' | sed 's/"//g'`
fi

# set additional variables
export PROJECTDIR=`pwd` 
export WORKDIR=${PROJECTDIR}/work
export APPSDIR=${PROJECTDIR}/apps
mkdir -p ${WORKDIR}
mkdir -p ${APPSDIR}
export LC_COLLATE=C  # IMPORTANT setting of LC_LOCATE for the pattern testing the variables
export C1AUTHHEADER="Authorization:	ApiKey ${C1APIKEY}"
export C1CSAPIURL="https://container.${C1REGION}.cloudone.trendmicro.com/api"
export C1CSENDPOINTFORHELM="https://container.${C1REGION}.cloudone.trendmicro.com"
export C1ASAPIURL="https://application.${C1REGION}.cloudone.trendmicro.com"
export DSSC_HOST_FILTER=".status.loadBalancer.ingress[].ip"

# Generating names for Apps, Stack, Pipelines, ECR, CodeCommit repo,..."
#generate the names of the apps from the git URL
export APP1=moneyx
#export APP1=`echo ${APP1_GIT_URL} | awk -F"/" '{print $NF}' | awk -F"." '{ print $1 }' | tr -cd '[:alnum:]'| awk '{ print tolower($1) }'`
#export APP2=`echo ${APP2_GIT_URL} | awk -F"/" '{print $NF}' | awk -F"." '{ print $1 }' | tr -cd '[:alnum:]'| awk '{ print tolower($1) }'`
#export APP3=`echo ${APP3_GIT_URL} | awk -F"/" '{print $NF}' | awk -F"." '{ print $1 }' | tr -cd '[:alnum:]'| awk '{ print tolower($1) }'`

# checking dockerlogin
printf "%s" "Validating Docker login..."
DOCKERLOGIN=`docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_PASSWORD 2>/dev/null`
[ ${VERBOSE} -eq 1 ] && printf "\n%s\n" "DOCKERLOGIN= $DOCKERLOGIN"
if [[ ${DOCKERLOGIN} == "Login Succeeded" ]];then 
  printf "%s\n" "OK"; 
else 
  printf "%s\n" "Docker Login Failed.  Please check the Docker Variables in 00_define.var.sh"
  read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
fi
#TODO script does not stop when login fails !!!!

# pulling/cloning common parts
printf "\n%s\n" "Cloning/pulling deployC1CSandC1AS"
#mkdir -p deployC1CSandC1AS
rm -rf deployC1CSandC1AS
git clone https://github.com/cvdabbeele/deployC1CSandC1AS.git 
#git clone https://github.com/cvdabbeele/C1CS.git deployC1CSandC1AS
cp deployC1CSandC1AS/*.sh ./
rm -rf deployC1CSandC1AS

#can I create a C1AS opbject? (validating C1APIkeyb)
export C1ASRND="test_"$(openssl rand -hex 4)
export C1ASRND=${C1ASRND}

export PAYLOAD="{ \"name\": \"${C1PROJECT}_${C1ASRND}\"}"
printf "%s" "Validating C1API key by creating C1AS Group object ${C1PROJECT}_${C1ASRND} in C1AS..."
export C1ASGROUPCREATERESULT=`\
curl --silent --location --request POST "${C1ASAPIURL}/accounts/groups/" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1'  --data-raw "${PAYLOAD}" \
`
[ ${VERBOSE} -eq 1 ] &&  printf "%s" "C1ASGROUPCREATERESULT=$C1ASGROUPCREATERESULT"
APPSECKEY=`printf "%s" "${C1ASGROUPCREATERESULT}" | jq -r ".credentials.key"`
[ ${VERBOSE} -eq 1 ] &&  printf "%s\n" APPSECKEY=$APPSECKEY
APPSECRET=`printf "%s" "${C1ASGROUPCREATERESULT}" | jq   -r ".credentials.secret"`
[ ${VERBOSE} -eq 1 ] &&  printf "%s\n" APPSECRET=$APPSECRET
if [[ "$APPSECKEY" == "null"  ]];then
   printf "\n%s\n" "Failed to create group object in C1AS for ${1}"; 
   read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
else
  printf "%s\n" "OK"
  #deleting C1AS test object
  printf "%s\n" "Deleting test Group object ${C1PROJECT}_${C1ASRND} in C1AS"

  readarray -t C1ASGROUPS <<< `curl --silent --location --request GET "${C1ASAPIURL}/accounts/groups" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' | jq -r ".[].name"`
  readarray -t DUMMYARRAYTOFIXSYNTAXCOLORINGINVSCODE <<< `pwd `
  [ ${VERBOSE} -eq 1 ] &&  echo C1ASGROUPS[@] =  ${C1ASGROUPS[@]}
  readarray -t C1ASGROUPIDS <<< `curl --silent --location --request GET "${C1ASAPIURL}/accounts/groups" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' | jq -r ".[].group_id"`
  readarray -t DUMMYARRAYTOFIXSYNTAXCOLORINGINVSCODE <<< `pwd `

  for i in "${!C1ASGROUPS[@]}"; do
    [ ${VERBOSE} -eq 1 ] && printf "%s"  "Checking Group ${C1ASGROUPS[$i]}"
    [ ${VERBOSE} -eq 1 ] && printf "%s\n"  "..with groupID ${C1ASGROUPIDS[$i]}"
    #printf "%s\n" "C1AS: found group ${C1ASGROUPS[$i]} with ID ${C1ASGROUPIDS[$i]}"
    if [[ "${C1ASGROUPS[$i]}" == "${C1PROJECT^^}_${C1ASRND^^}" ]]; then
      printf "%s\n" "Deleting old Group object ${C1PROJECT}_${C1ASRND} in C1AS"
      curl --silent --location --request DELETE "${C1ASAPIURL}/accounts/groups/${C1ASGROUPIDS[$i]}"   --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' 
    fi
  done 
fi

# ----------------
#  Azure specific 
# ----------------
export PLATFORM="AZURE"
export DSSC_SUBJECTALTNAME="*.nip.io"

# Install azure cli
if  [ ! -x "$(command -v az  2>/dev/null)" ] ; then 
  printf '%s\n'  "Installing AzureCli"
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Install az extensions
if [[ "`az extension list | grep \"azure-devops\"`" = "" ]]; then
  printf '%s\n' "Adding Azure-devops extensions "
  az extension add --name azure-devops
fi


# Download and install the Microsoft signing key:
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

# Add the Azure CLI software repository:
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list > /dev/null

# Login to Azure
export AZLOGGEDIN=`az account get-access-token --query "expiresOn" --output tsv 2>/dev/null`
if [[ -z "${AZLOGGEDIN}" ]]; then
  printf '%s\n' "Logging in to Azure...  Follow the instructions below to login.  The script will continue after you have logged in via the browser on your workstation"
  DUMMY=`az login`
  [ ${VERBOSE} -eq 1 ] &&  printf '%s\n' "${DUMMY}"
fi

#login to Azure devops
printf '%s\n' "Logging in to the pre-created organization in Az DEVOPS, using the pre-created Personal Access Token (PAT)" 
{ ERROR=$(echo $AZURE_DEVOPS_EXT_PAT | az devops login --organization ${AZURE_ORGANIZATION_URL} 2>&1 1>&$out); } {out}>&1
if [[ "${ERROR}" =~ "ERROR" ]]; then
  printf '%s\n' "ERROR: Could not login to AZ devops; check your AZURE_DEVOPS_EXT_PAT and your AZURE_ORGANIZATION variables in the 00_define_vars.sh file"
  read -p "Press CTRL-C to exit script, or Enter to continue anyway"
else
  printf '%s\n' "logged in"
fi
# https://github.com/Azure/azure-devops-cli-extension/issues/486
# explicit logingould required and even throwing an error
# as long as $AZURE_DEVOPS_EXT_PAT is defined, login will be transparent
#printf '%s\n' "The above-mentioned warning on \"Failed to store PAT using keyring\" is expected"
#printf '%s\n' "and can be IGNORED"

# set azure devops default organization
[ ${VERBOSE} -eq 1 ] && printf '%s\n' "Setting Azure devops default organization"
az devops configure --default project=${AZURE_ORGANIZATION_URL}

# check if the defined AZURE_SUBSCRIPTION_NAME exists
[ ${VERBOSE} -eq 1 ] && printf '%s\n' "Checking Azure subscription..."
#TODO fix subscription names with spaces
AZ_SUBSCRIPTIONS=(`az account list | jq -r ".[].name"`)
[ ${VERBOSE} -eq 1 ] &&  printf '%s\n' "AZ_SUBSCRIPTIONS=${AZ_SUBSCRIPTIONS[@]}"
export AZ_SUBSCRIPTION_OK="false"
for AZ_SUBSCRIPTION in ${AZ_SUBSCRIPTIONS[@]}; do 
    [ ${VERBOSE} -eq 1 ] && printf '%s\n' "${AZ_SUBSCRIPTION}"
    if [[ ${AZ_SUBSCRIPTION} = ${AZURE_SUBSCRIPTION_NAME} ]];then
      AZ_SUBSCRIPTION_OK="true"
    fi
done 
if [[ ${AZ_SUBSCRIPTION_OK} = "true" ]];then
  printf '%s\n' "Setting default Azure subscription to ${AZURE_SUBSCRIPTION_NAME}"
  # set azure default subscription
  az account set --subscription "${AZURE_SUBSCRIPTION_NAME}"
else
    printf '%s\n' "The AZURE_SUBSCRIPTION_NAME as defined in 00_define_vars.sh does not exist"
    read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
fi



# checking variables by format
# Declaring associative arrays (mind the capital 'A')
declare -A VAROK
declare -A VARFORMAT
# set list of VARS_TO_VALIDATE_BY_FORMAT
#VARS_TO_VALIDATE_BY_FORMAT=(C1REGION C1CS_RUNTIME C1PROJECT DSSC_AC C1APIKEY AZUREAKSNODES AZURE_DEVOPS_EXT_PAT)
VARS_TO_VALIDATE_BY_FORMAT=(C1REGION C1CS_RUNTIME C1PROJECT AZUREAKSNODES AZURE_DEVOPS_EXT_PAT)
# set the expected FORMAT for each variable
#  ^ is the beginning of the line anchor
#  [...] is a character class definition
#  [[...]]{nn} is the number of repeats
#  * is "zero-or-more" repetition
#  $ is the end of the line anchor
# in the IF comparison, the "=~" means the right hand side is a regex expression
VARFORMAT[C1REGION]="^(us-1|in-1|gb-1|jp-1|de-1|au-1|ca-1|sg-1|trend-us-1)$"
VARFORMAT[C1CS_RUNTIME]="^(true|false)$"
VARFORMAT[C1PROJECT]="^[a-z0-9]*$"
#VARFORMAT[DSSC_AC]='^[A-Z]{2}-[[:alnum:]]{4}-[[:alnum:]]{5}-[[:alnum:]]{5}-[[:alnum:]]{5}-[[:alnum:]]{5}-[[:alnum:]]{5}$'
#VARFORMAT[C1APIKEY]='^[[:alnum:]]{27}:[[:alnum:]]{66}$'
VARFORMAT[AZUREAKSNODES]='^[1-5]'
VARFORMAT[AZURE_DEVOPS_EXT_PAT]='^[[:alnum:]]{52}$'   

# Check all variables from the VARS_TO_VALIDATE_BY_FORMAT list
VARSAREOK="true"
for i in "${VARS_TO_VALIDATE_BY_FORMAT[@]}"; do
  [ ${VERBOSE} -eq 1 ] && printf "%s"  "checking variable ${i}    "
  if [[ ${!i} =~ ${VARFORMAT[$i]} ]];then
    VAROK[$i]="true"
   [ ${VERBOSE} -eq 1 ] && printf "%s\n"  "OK"
  else
    VAROK[$i]="false"
    VARSAREOK="false"
    printf "%s\n" "Variable ${i} has a wrong format. "
    printf "%s\n" "     Contents =  ${!i} " 
    printf "%s\n" "     Expected format must be ${VARFORMAT[$i]} "
  fi
done


# quick-check other variables
#if  [ -z "$DOCKERHUB_USERNAME" ]; then echo DOCKERHUB_USERNAME must be set && VARSAREOK=false; fi
#if  [ -z "$DOCKERHUB_PASSWORD" ]; then echo DOCKERHUB_PASSWORD must be set && VARSAREOK=false; fi
if  [ -z "$DSSC_PASSWORD" ]; then printf '%s\n' "DSSC_PASSWORD must be set && VARSAREOK=false"; fi
if  [ -z "$DSSC_REGPASSWORD" ]; then printf '%s\n' "DSSC_REGPASSWORD must be set && VARSAREOK=false"; fi
if  [ -z "$DSSC_NAMESPACE" ]; then printf '%s\n' "DSSC_NAMESPACE must be set && VARSAREOK=false"; fi
if  [ -z "$DSSC_USERNAME" ]; then printf '%s\n' "DSSC_USERNAME must be set && VARSAREOK=false"; fi
if  [ -z "$DSSC_TEMPPW" ]; then printf '%s\n' "DSSC_TEMPPW must be set && VARSAREOK=false"; fi
if  [ -z "$DSSC_HOST" ]; then printf '%s\n' "DSSC_HOST must be set && VARSAREOK=false"; fi
if  [ -z "$DSSC_REGUSER" ]; then printf '%s\n' "DSSC_REGUSER must be set && VARSAREOK=false"; fi

if  [ -z "$APP1_GIT_URL" ]; then printf '%s\n' "APP1_GIT_URL must be set && VARSAREOK=false"; fi
#if  [ -z "$APP2_GIT_URL" ]; then printf '%s\n' "APP2_GIT_URL must be set && VARSAREOK=false"; fi
#if  [ -z "$APP3_GIT_URL" ]; then printf '%s\n' "APP3_GIT_URL must be set && VARSAREOK=false"; fi


if [[ ${VARSAREOK} == "true" ]]; then
  echo "All variables checked out ok"
else
  echo "Please correct the above-mentioned variables in your 00_define_vars.sh file"
  read -p "Press CTRL-C to exit script, or Enter to continue anyway (script will fail)"
fi


#TODO: AZURE PAT checking ?
#TDOD 