
STARTDIR=`pwd`
#echo "usage: add the name of the app to be pushed as a parameter"
#echo "       if no parameter is added, ${APP1} is pushed"
if [[ -z ${1} ]]; then
    STARTDIR=`pwd`
    cd ${APPSDIR}/moneyx
    sed -i 's/": 0/": 300/g'  azure-pipelines.yml #change the security thresholds in the moneyx app
    echo " "  >>README.md  #ensure that we have a change, regardless if the above sed command made anychanges
    echo "pushing to master branch (20210303)"  
    git add . && git commit -m "allowing risky builds"   &&  git push azure master
    cd "${STARTDIR}"
#else
#    if [ "${1}" = "${APP1}" ] || [ "${1}" = "${APP2}" ] || [ "${1}" = "${APP3}" ]; then
#            cd ${APPSDIR}/${1}
#        sed -i 's/": 0/": 300/g'  azure-pipelines.yml #change the security thresholds in the ${1} app
#        echo " "  >>README.md  #ensure that we have a change, regardless if the above sed command made anychanges
#        echo "pushing to master branch "  #updated (20210303)
#        git add . && git commit -m "allowing risky builds"   &&  git push azure master
#        cd "${STARTDIR}"
#    else
#        echo "The provided parameter does not match any application"
#        echo "try \"${APP1}\" \"${APP2}\" \"${APP3}\""
#    fi
fi
    

