#!/bin/bash

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
ARGUMENTS="$1"
EXTRAS="$2"

# if we have not extras, reduce parameter index by 1
if [ "$EXTRAS" == "true" ]
then
   SYNC="$2"
   CLEAN="$3"
else
   SYNC="$3"
   CLEAN="$4"
fi

# get time of startup
res1=$(date +%s.%N)

if [ "$CLEAN" == "true" ]
then
 
   # we don't allow scrollback buffer
   echo -e '\0033\0143'
   clear
fi

# decide what device to build for
case "$ARGUMENTS" in
   galaxys2)
       densitytrigger="128"
       device="galaxys2"
       manufacturer="samsung"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid ${txtrst}${cya}for International Samsung Galaxy S2 ${txtrst}";;
   maguro)
       densitytrigger="192"
       device="maguro"
       manufacturer="samsung"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid ${txtrst}${cya}for International Samsung Galaxy Nexus ${txtrst}";;
   galaxys3)
       densitytrigger="192"
       device="i9300"
       manufacturer="samsung"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid ${txtrst}${cya}for International Samsung Galaxy S3 ${txtrst}";;
   toro)
       densitytrigger="192"
       device="toro"
       manufacturer="samsung"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid ${txtrst}${cya}for Verizon Samsung Galaxy Nexus ${txtrst}";;
   toroplus)
       densitytrigger="192"
       device="toroplus"
       manufacturer="samsung"
       echo -e "${cya}Building ${bldcya}ParanoidAndroid ${txtrst}${cya}for Sprint Samsung Galaxy Nexus ${txtrst}";;
   *)
       echo -e "${bldred}Please input device name ${txtrst}"
       exit;;
esac

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
   forceupdate)
       rm paranoid/.manifest;;
esac

echo -e ""
echo -e "${bldblu}Copying device manifest ${txtrst}"
cp paranoid/manifests/"${device}_manifest.xml" .repo/local_manifest.xml
if [ ! -f paranoid/.manifest ]
then
    loadmanifest="true"
    echo -e ""
    echo -e "${bldblu}Syncing device sources ${txtrst}"
    repo sync -j"$THREADS"
    touch paranoid/.manifest
fi

echo -e ""
# download prebuilt files
echo -e "${bldblu}Downloading prebuilts ${txtrst}"
cd vendor/cm
./get-prebuilts
cd ./../..

echo -e ""
# sync with latest sources
if [ "$SYNC" == "true" ] && [ "$loadmanifest" != "true" ]
then
   echo -e "${bldblu}Fetching latest sources ${txtrst}"
   repo sync -j"$THREADS"
   echo -e ""
fi

echo -e "${bldblu}Setting up environment ${txtrst}"

# setup environment
. build/envsetup.sh

echo -e ""
echo -e "${bldblu}Lunching device ${txtrst}"

# lunch device
lunch "pa_$device-userdebug";

echo -e ""
echo -e "${bldblu}Starting compilation ${txtrst}"

# start compilation
#brunch "pa_$device-userdebug";
echo -e ""

# finished? get elapsed time
res2=$(date +%s.%N)
echo "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1)/60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds) ${txtrst}"
