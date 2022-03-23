
# trict security settings
STARTDIR=`pwd`
cd  ../apps/${APP1}
echo " "  >> README.md  #ensure that we have a change, regardless if the above sed command made anychanges
git add . && git commit -m "strict security checks at buildtime"  && git push azure master
cd $STARTDIR



STARTDIR=`pwd`
#echo "usage: add the name of the app to be pushed as a parameter"  THIS IS STILL WIP 
#echo "       if no parameter is added, ${APP1} is pushed"   
if [[ -z ${1} ]]; then
    STARTDIR=`pwd`
    cd ../apps/moneyx
    sed -i 's/": 300/": 0/g'  azure-pipelines.yml #change the security thresholds in the c1-app-sec-moneyx app
    echo " "  >>README.md  #ensure that we have a change, regardless if the above sed command made anychanges
    echo "pushing to master branch (20210303)"  
    git add . && git commit -m "strict security checks at buildtime"  && git push azure master
    cd "${STARTDIR}"
#else
#    if [ "${1}" = "${APP1}" ] || [ "${1}" = "${APP2}" ] || [ "${1}" = "${APP3}" ]; then
#        cd ../apps/${1}
#        sed -i 's/": 300/": 0/g'  azure-pipelines.yml #change the security thresholds in the c1-app-sec-moneyx app
#        echo " "  >>README.md  #ensure that we have a change, regardless if the above sed command made anychanges
#        echo "pushing to master branch "  #updated (20210303)
#        git add . && git commit -m "allowing risky builds"   &&  git push azure master
#        cd "${STARTDIR}"
#    else
#        echo "The provided parameter does not match any application"
#        echo "try \"${APP1}\" \"${APP2}\" \"${APP3}\""
#    fi
fi
    

