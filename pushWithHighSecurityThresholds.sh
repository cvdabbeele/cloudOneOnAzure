# Push of MoneyX app with high security thresholds (lots of vulnerabilities allowed)
export CURRENTAPP="moneyx"
STARTDIR=`pwd`
cd ${APPSDIR}/${CURRENTAPP}
#set all thresholds in the app from 0 to 300
sed -i 's/": 0/": 300/g'  azure-pipelines.yml #change the security thresholds in the ${CURRENTAPP} app
echo " "  >>README.md  #ensure that we have a change, regardless if the above sed command made anychanges
echo "pushing to internal master branch"  
git add . && git commit -m "allowing risky builds"   &&  git push azure master
cd "${STARTDIR}"
