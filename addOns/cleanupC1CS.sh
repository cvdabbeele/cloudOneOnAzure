# delete C1CS clusters, scanners and policies that _contain_ $TOBEDELETED
export TOBEDELETED="YOUR_CONTAINERS_TO_BE_DELETED_STRING"

echo "Deleting clusters"
C1CSCLUSTERS=(`\
curl --silent --location --request GET "${C1CSAPIURL}/clusters" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' \
 | jq -r ".clusters[] | select(.name |contains(\"${TOBEDELETED}\")).id"`)
#jq -r '.[]|select(.displayName | contains("${TOBEDELETED}")) | .appId, .displayName'
echo ${C1CSCLUSTERS[@]}

for i in "${!C1CSCLUSTERS[@]}"
do
  printf "%s\n" "C1CS: Removing scanners ${C1CSSCANNERS[$i]}"
  curl --silent --location --request DELETE "${C1CSAPIURL}/scanners/${C1CSSCANNERS[$i]}" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1'
done


echo "Deleting scanners"
C1CSSCANNERS=(`\
curl --silent --location --request GET "${C1CSAPIURL}/scanners" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' \
 | jq -r ".scanners[] | select(.name |contains(\"${TOBEDELETED}\")).id"`)
#jq -r '.[]|select(.displayName | contains("${TOBEDELETED}")) | .appId, .displayName'
echo ${C1CSSCANNERS[@]}


for i in "${!C1CSSCANNERS[@]}"
do
  printf "%s\n" "C1CS: Removing scanner ${C1CSSCANNERS[$i]}"
  curl --silent --location --request DELETE "${C1CSAPIURL}/scanners/${C1CSSCANNERS[$i]}" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1'
done



echo "Deleting policies"
C1CSpolicies=(`\
curl --silent --location --request GET "${C1CSAPIURL}/policies" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1' \
 | jq -r ".policies[] | select(.name |contains(\"${TOBEDELETED}\")).id"`)
#jq -r '.[]|select(.displayName | contains("${TOBEDELETED}")) | .appId, .displayName'
echo ${C1CSpolicies[@]}


for i in "${!C1CSpolicies[@]}"
do
  printf "%s\n" "C1CS: Deleting policy ${C1CSpolicies[$i]}"
  curl --silent --location --request DELETE "${C1CSAPIURL}/policies/${C1CSpolicies[$i]}" \
--header 'Content-Type: application/json' \
--header "${C1AUTHHEADER}"  \
--header 'api-version: v1'
done
