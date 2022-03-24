# Push of MoneyX app with LOW security thresholds (no vulnerabilities allowed)
export CURRENTAPP="moneyx"
STARTDIR=`pwd`
cd ${APPSDIR}/${CURRENTAPP}
#set all thresholds in the app from 300 to 0
sed -i 's/": 300/": 0/g'  azure-pipelines.yml #change the security thresholds in the ${CURRENTAPP} app
echo " "  >>README.md  #ensure that we have a change, regardless if the above sed command made anychanges
echo "pushing to internal master branch"  
git add . && git commit -m "strict security checks at buildtime"  && git push azure master
cd "${STARTDIR}"
