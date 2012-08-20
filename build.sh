#!/bin/bash

# get current path
reldir=`dirname $0`
cd $reldir
DIR=`pwd`

# Colorize and add text parameters
red=$(tput setaf 1)             #  red
grn=$(tput setaf 2)             #  green
cya=$(tput setaf 6)             #  cyan
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldgrn=${txtbld}$(tput setaf 2) #  green
bldblu=${txtbld}$(tput setaf 4) #  blue
bldcya=${txtbld}$(tput setaf 6) #  cyan
txtrst=$(tput sgr0)             # Reset

THREADS="16"
DEVICE="$1"
EXTRAS="$2"

# get current version
MAJOR=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MAJOR = *' | sed  's/PA_VERSION_MAJOR = //g')
MINOR=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MINOR = *' | sed  's/PA_VERSION_MINOR = //g')
VERSION=$MAJOR.$MINOR

# check if buildtool exist on the environment
if [ -f $DIR/ParanoidBuild.jar ]
then
    JAVA="true"
else
    JAVA="false"
fi

# send interrupted status to server
on_interrupt() {
    if [ "$JAVA" == "true" ] && [ "$UPLOAD" == "true" ]
    then
        java -jar $DIR/ParanoidBuild.jar $device 3
    fi
    exit 0
}


# trap interrupt behaviour
trap on_interrupt SIGINT

# if we have not extras, reduce parameter index by 1
if [ "$EXTRAS" == "true" ] || [ "$EXTRAS" == "false" ]
then
   SYNC="$2"
   UPLOAD="$3"
else
   SYNC="$3"
   UPLOAD="$4"
fi

# get time of startup
res1=$(date +%s.%N)

# we don't allow scrollback buffer
echo -e '\0033\0143'
clear

# decide what device to build for
case "$DEVICE" in
   galaxys2)
       device="galaxys2"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid v$VERSION ${txtrst}${cya}for International Samsung Galaxy S2 ${txtrst}";;
   maguro)
       device="maguro"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid v$VERSION ${txtrst}${cya}for International Samsung Galaxy Nexus ${txtrst}";;
   galaxys3)
       device="i9300"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid v$VERSION ${txtrst}${cya}for International Samsung Galaxy S3 ${txtrst}";;
   toro)
       device="toro"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid v$VERSION ${txtrst}${cya}for Verizon Samsung Galaxy Nexus ${txtrst}";;
   toroplus)
       device="toroplus"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid v$VERSION ${txtrst}${cya}for Sprint Samsung Galaxy Nexus ${txtrst}";;
   marvel)
       device="marvel"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid v$VERSION ${txtrst}${cya}for The HTC Wildfire S ${txtrst}";;
   *)
       echo -e "${bldred}Wrong input, please select a valid device ${txtrst}"
       exit;;
esac

echo -e "${cya}"
./vendor/pa/tools/getdevicetree.py $device
echo -e "${txtrst}"

# decide what command to execute
case "$EXTRAS" in
   threads)
       echo -e "${bldblu}Please write desired threads followed by [ENTER] ${txtrst}"
       read threads
       THREADS=$threads;;
   clean)
       echo -e ""
       echo -e "${bldblu}Cleaning intermediates and output files ${txtrst}"
       make clean > /dev/null;;
esac

# download prebuilt files
echo -e ""
echo -e "${bldblu}Downloading prebuilts ${txtrst}"
cd vendor/cm
./get-prebuilts
cd ./../..

# sync with latest sources
echo -e ""
if [ "$SYNC" == "true" ]
then
   echo -e "${bldblu}Fetching latest sources ${txtrst}"
   repo sync -j"$THREADS"
   echo -e ""
fi

# send building status to server
if [ "$JAVA" == "true" ] && [ "$UPLOAD" == "true" ]
then
java -jar $DIR/ParanoidBuild.jar $device 0
fi

# setup environment
echo -e "${bldblu}Setting up environment ${txtrst}"
. build/envsetup.sh

# lunch device
echo -e ""
echo -e "${bldblu}Lunching device ${txtrst}"
lunch "pa_$device-userdebug";

echo -e ""
echo -e "${bldblu}Starting compilation ${txtrst}"

# start compilation
brunch "pa_$device-userdebug";
echo -e ""

# if we cant upload the file, status 4 will be sent
if [ "$JAVA" == "true" ] && [ "$UPLOAD" == "true" ]
then
    java -jar $DIR/ParanoidBuild.jar $device 1
fi

# finished? get elapsed time
res2=$(date +%s.%N)
echo "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1) / 60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds) ${txtrst}"
