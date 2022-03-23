#!/bin/bash
printf '%s\n' "--------------------------"
printf '%s\n' "     Scan Immage(-s)      "
printf '%s\n' "--------------------------"

printf '%s\n' "(re-)Defining variables"
. ../00_define_vars.sh
printf '%s\n' ""
declare -a IMAGES && IMAGES=()  #declare and empty the array
declare -a IMAGES_FLATENED  && IMAGES_FLATENED=()  
declare -A IMAGE_TAGS && IMAGE_TAGS=()   #ASSOCIATIVE Array (!)

export DSSC_HOST="`kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`.nip.io"
export AZURE_ACR=`az acr list | jq -r ".[].name"`
export REGISTRY_HOST=${AZURE_ACR}.azurecr.io
export ACR_CREDENTIALS=$(az acr credential show --name ${AZURE_ACR})
export ACR_PASSWORD=$(jq -r '.passwords[] | select(.name=="password") | .value' <<< $ACR_CREDENTIALS)
export ACR_USERNAME=$(jq -r '.username' <<< $ACR_CREDENTIALS)


if [ ! -d "vulnerability-management" ]; then
  git clone https://github.com/mawinkler/vulnerability-management.git
fi

dummy=`echo ${DOCKERHUB_PASSWORD}| docker login --username ${DOCKERHUB_USERNAME} --password-stdin 2>/dev/null`
if [[ "$dummy" != "Login Succeeded" ]];then
   echo "Failed to login to Docker Hub"
   return "Failed to login to Docker Hub"
fi

if [ -z "${1}" ];then
  printf '%s\n' "No image name passed in script parameters.  Creating array with sample images"
  IMAGES=("ubuntu" "redhat/ubi8-minimal" "alpine" "wordpress" "busybox" "redis" "node" "python" "django" "centos" "tomcat" )
else
  IMAGES=(${1})
fi

export LENGTH=${#IMAGES[@]}
#LENGTH=2
export IMAGE_TAG="latest"
# find ACR of this project
#TODO this can be done cleaner; what if there are more than one...

for((i=0;i<${LENGTH};++i)) do
    IMAGES_FLATENED[${i}]=`echo ${IMAGES[$i]} | sed 's/\///'| sed 's/-//'`
    printf '%s\n' "image ${i} = ${IMAGES[$i]} image_clean = ${IMAGES_FLATENED[$i]} "
    echo "-----------------------------"
    echo "PULLING ${IMAGES[$i]}:latest from Docker hub"
    docker pull ${IMAGES[$i]}:latest

    #login to ACR
    if [ "`az acr login --name  ${AZURE_ACR}`" == "Login Succeeded" ];then  
      printf '%s\n' "  Login to ACR is successful"
    else
      printf '%s\n' "  ERROR: failed to login to ACR"
    fi

    echo "(re)TAGGING ${IMAGES[$i]}:${IMAGE_TAG}   to   ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG}" 
    docker tag ${IMAGES[$i]}:${IMAGE_TAG} ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG}

    echo "PUSHING to ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG}"
    docker push ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG}

    export IMAGE_TAG2=`openssl rand -hex 4`
    echo "(re)TAGGING ${IMAGES[$i]}:${IMAGE_TAG}   to   ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG2}" 
    docker tag ${IMAGES[$i]}:${IMAGE_TAG} ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG2}

    echo "PUSHING to ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG2}"
    docker push ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG2}

    echo "removing local images ${IMAGES[$i]}:${IMAGE_TAG} and ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG}"
    docker rmi ${IMAGES[$i]}:${IMAGE_TAG}
    docker rmi ${REGISTRY_HOST}/${IMAGES_FLATENED[$i]}:${IMAGE_TAG}

    echo "calling smartcheck-scan-action"
    docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
        deepsecurity/smartcheck-scan-action \
            --image-name "${REGISTRY_HOST}/${IMAGES_FLATENED[${i}]}:${IMAGE_TAG}"  \
            --smartcheck-host="${DSSC_HOST}" \
            --smartcheck-user="${DSSC_USERNAME}" \
            --smartcheck-password="${DSSC_PASSWORD}" \
            --image-pull-auth="{\"username\":\"${ACR_USERNAME}\",\"password\":\"${ACR_PASSWORD}\"}" \
            --insecure-skip-tls-verify

   cat <<EOF >./vulnerability-management/cloudone-image-security/scan-report/config.yml
dssc:
  service: "${DSSC_HOST}"
  username: "${DSSC_USERNAME}"
  password: "${DSSC_PASSWORD}"

repository:
  name: "${IMAGES_FLATENED[$i]}"
  image_tag: "${IMAGE_TAG}"

criticalities:
  - defcon1
  - critical
  - high
  - medium
EOF

    CURRENTDIR=`pwd`
    cd ./vulnerability-management/cloudone-image-security/scan-report
    python3 ./scan-report.py 
    cd ${CURRENTDIR}
    mv ./vulnerability-management/cloudone-image-security/scan-report/report*.pdf  ./
    echo "-----------------------------"
done
