#Cleanup Groups in C1AS
#This script expects your C1API key to be stored in the C1APIKEY variable
export C1APIKEY="YOUR_CLOUD_ONE_API_KEY"

#this script will delete all groups in C1AS that *begin* *with* GROUPS_TO_BE_DELETED
export GROUPS_TO_BE_DELETED="YOUR_GROUPS_TO_BE_DELETED_STRING"
export C1AUTHHEADER="Authorization:	ApiKey ${C1APIKEY}"

# get all existing groups from your C1AS account
readarray -t C1ASGROUPS <<< `curl --silent --location --request GET "${C1ASAPIURL}/accounts/groups" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' | jq -r ".[].name"`
#printf "%s" "Found the following groups =  ${C1ASGROUPS[@]}"
readarray -t C1ASGROUPIDS <<< `curl --silent --location --request GET "${C1ASAPIURL}/accounts/groups" --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1' | jq -r ".[].group_id"`
#printf "%s" "...with the following IDs =  ${C1ASGROUPS[@]}"

for i in "${!C1ASGROUPS[@]}"
do
  printf "%s\n" "C1AS: found group ${C1ASGROUPS[$i]} with ID ${C1ASGROUPIDS[$i]}"
  # regex matching... deleting every group that starts with ${GROUPS_TO_BE_DELETED} converted to uppercase
  if [[ "${C1ASGROUPS[$i]}" =~ "${GROUPS_TO_BE_DELETED^^}" ]]
  then
    printf "%s\n" "Deleting old Group object ${C1ASGROUPS[$i]} with id ${C1ASGROUPIDS[$i]} in C1AS"
    curl --silent --location --request DELETE "${C1ASAPIURL}/accounts/groups/${C1ASGROUPIDS[$i]}"   --header 'Content-Type: application/json' --header "${C1AUTHHEADER}" --header 'api-version: v1'
  fi
done
