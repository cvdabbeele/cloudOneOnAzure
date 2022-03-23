#AzureKubernetesService AKS

#Quickstart
#https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

#start the AzureCloudShell
#--------------------------
#  https://portal.azure.com -> click the > icon at the top right of the screen

MAINSTARTTIME=`date +%s`

# import variables
. ./00_define_vars.sh

# environmentSetup
. ./environmentSetup.sh

# create cluster
. ./aksCluster.sh

# create groups in C1AS
. ./C1AS.sh

# add C1CS
. ./C1CS.sh

# add the demo apps
. ./demoApps.sh

# setup azure CodePipeline
. ./pipelines.sh

# add ACR to SmartCheck 
. ./smartcheckAddACR.sh

printf '%s\n'  "You can now kick off sample pipeline-builds of MoneyX"
printf '%s\n'  " e.g. by running ./pushWithHighSecurityThresholds.sh"
printf '%s\n'  " e.g. by running ./pushWithMalware.sh"

MAINENDTIME=`date +%s`
printf '%s\n' "Script run time = $((($MAINENDTIME-$MAINSTARTTIME)/60)) minutes"
 
# create report
#still need to ensure that either "latest" gets scanned or that $TAG gets exported from the pipeline
# plus: data on Snyk findings is not visible in the report
# docker run --network host mawinkler/scan-report:dev -O    --name "${TARGET_IMAGE}"    --image_tag latest    --service "${DSSC_HOST}"    --username "${DSSC_USERNAME}"    --password "\"${DSSC_PASSWORD}"\"
#end