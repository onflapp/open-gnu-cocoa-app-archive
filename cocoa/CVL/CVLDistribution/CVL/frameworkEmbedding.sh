#!/bin/sh

# Inspired by MOKit instructions
# http://mokit.sf.net/
#
# Rewrite install_name in the embedded frameworks
# Note we do not bother to change the debug or profile variants since those are
# never directly linked against at static link time.

if [ $# -lt 2 ]; then \
    echo "Usage: `basename $0` applicationExecutablePath frameworkName [frameworkName ...]"
    echo "applicationPath = path to application executable (not the wrapper!)"
    echo "frameworkName = list of embedded framework names, from most dependant to independant (relative to each others)"
    echo "                frameworks have to be located in application.app/Contents/Frameworks"
    exit 1
fi

# For tests
#TARGET_BUILD_DIR=/Developer/Products/stephane
#PRODUCT_NAME=Uniboard
#WRAPPER_EXTENSION=app
# From most dependant to independant!
#embeddedFrameworkNames="UniboardModel SenTestingKit SenFoundation"
#applicationExecutable="${TARGET_BUILD_DIR}/${PRODUCT_NAME}.${WRAPPER_EXTENSION}/Contents/MacOS/${PRODUCT_NAME}"


# Parse arguments
embeddedFrameworkNames=""
applicationExecutable=""
for argument in $*; do {
    if [ -z "$applicationExecutable" ]; then \
        applicationExecutable="$argument"
    else
        embeddedFrameworkNames="$embeddedFrameworkNames $argument"
    fi
}; done
#frameworksLocation="${TARGET_BUILD_DIR}/${PRODUCT_NAME}.${WRAPPER_EXTENSION}/Contents/Frameworks"
frameworksLocation="`dirname ${applicationExecutable}`/../Frameworks"
chmod u+w "${applicationExecutable}"

for frameworkName in $embeddedFrameworkNames; do {
    # Get framework current version
    frameworkVersion=`ls -al "${frameworksLocation}/${frameworkName}.framework/Versions/Current" | sed 's/^\(.*-> \(.*\)\)$/\2/'`
    
    # Get framework executable
    frameworkExecutable="${frameworksLocation}/${frameworkName}.framework/Versions/${frameworkVersion}/${frameworkName}"
    
    # Get original install name
    originalInstallName=`otool -L ${frameworkExecutable} | sed -e '1 d' -e 's/^\([[:blank:]]*\)\(.*\)\( (.*\)$/\2/' -e q`
    
    # Get dependant frameworks
    dependencies=`otool -L ${frameworkExecutable} | sed -e '1,2 d' -e 's/^\([[:blank:]]*\)\(.*\)\( (.*\)$/\2/' | xargs basename`
    
    chmod u+w "${frameworkExecutable}"

    for dependency in $dependencies; do {
        for frameworkName2 in $embeddedFrameworkNames; do {
            if [ $dependency = $frameworkName2 -a $frameworkName2 != $frameworkName ]; then \
            {
                frameworkVersion2=`ls -al "${frameworksLocation}/${frameworkName2}.framework/Versions/Current" | sed 's/^\(.*-> \(.*\)\)$/\2/'`    
                frameworkExecutable2="${frameworksLocation}/${frameworkName2}.framework/Versions/${frameworkVersion2}/${frameworkName2}"
                originalInstallName2=`otool -L ${frameworkExecutable} | grep ${frameworkName2}.framework | sed 's/^\([[:blank:]]*\)\(.*\)\( (.*\)$/\2/'`
                newInstallName2="@executable_path/../Frameworks/${frameworkName2}.framework/Versions/${frameworkVersion2}/${frameworkName2}"
                echo "In ${frameworkExecutable}, relocating ${originalInstallName2} as ${newInstallName2}" 
                install_name_tool -change "${originalInstallName2}" "${newInstallName2}" "${frameworkExecutable}"
                
            } fi;
        }; done
    }; done    
    
    # Rewrite install_name of framework
    newInstallName="@executable_path/../Frameworks/${frameworkName}.framework/Versions/${frameworkVersion}/${frameworkName}"
    echo "Relocating ${frameworkExecutable} as ${newInstallName}" 
    install_name_tool -id "${newInstallName}" "${frameworkExecutable}"

    # Rewrite install_name in the app
    echo "Relocating ${frameworkExecutable} as ${newInstallName} in application" 

    # We re-search originalInstallName, in application, because might be different.
    originalInstallName=`otool -L ${applicationExecutable} | grep ${frameworkName}.framework | sed -e 's/^\([[:blank:]]*\)\(.*\)\( (.*\)$/\2/'`
#    echo "install_name_tool -change ${originalInstallName} ${newInstallName} ${applicationExecutable}"
    install_name_tool -change "${originalInstallName}" "${newInstallName}" "${applicationExecutable}"

    chmod a-w "${frameworkExecutable}"
}
done

chmod a-w "${applicationExecutable}"
