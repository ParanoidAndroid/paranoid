#!/bin/bash

# Colorize and add text parameters
txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldgrn=${txtbld}$(tput setaf 2) #  green
bldblu=${txtbld}$(tput setaf 4) #  blue
bldwht=${txtbld}$(tput setaf 7) #  white
txtrst=$(tput sgr0)             # Reset

ARGUMENTS="$1"
CLEAN="$2"

# get time of startup
res1=$(date +%s.%N)

if [ "$CLEAN" == "true" ]
then
   # we don't allow scrollback command
   echo -e '\0033\0143'
   clear
fi

# decide what device to build for
case "$ARGUMENTS" in
   galaxys2)
       device="galaxys2"
       echo -e "${bldwht}Building ${bldgrn}ParanoidAndroid ${bldwht}for International Samsung Galaxy S2 ${txtrst}";;
   maguro)
       device="maguro"
       echo -e "${bldwht}Building ${bldgrn}ParanoidAndroid ${bldwht}for International Samsung Galaxy Nexus ${txtrst}";;
   galaxys3)
       device="i9300"
       echo -e "${bldwht}Building ${bldgrn}ParanoidAndroid ${bldwht}for International Samsung Galaxy S3 ${txtrst}";;
   toro)
       device="toro"
       echo -e "${bldwht}Building ${bldgrn}ParanoidAndroid ${bldwht}for Verizon Samsung Galaxy Nexus ${txtrst}";;
   toroplus)
       device="toroplus"
       echo -e "${bldwht}Building ${bldgrn}ParanoidAndroid ${bldwht}for Sprint Samsung Galaxy Nexus ${txtrst}";;
   *)
       echo -e "${bldred}Please input device name ${txtrst}"
       exit;;
esac

# sync with latest sources
echo -e "${bldblu} Fetching latest sources"
repo sync -j16

echo -e "${txtrst}"

# setup environment
. build/envsetup.sh

# lunch device
lunch "cm_$device-userdebug";

# start compilation
brunch "cm_$device-userdebug";

# finished? get elapsed time
res2=$(date +%s.%N)
echo "Total time elapsed:    $(echo "$res2 - $res1"|bc )"
