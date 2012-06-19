#!/bin/bash

# Colorize and add text parameters
txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldgrn=${txtbld}$(tput setaf 2) #  green
bldblu=${txtbld}$(tput setaf 4) #  blue
bldcya=${txtbld}$(tput setaf 6) #  cyan
bldwht=${txtbld}$(tput setaf 7) #  white
txtrst=$(tput sgr0)             # Reset

ARGUMENTS="$1"
SYNC="$2"
CLEAN="$3"

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
       densitytrigger="128"
       device="galaxys2"
       manufacturer="samsung"
       echo -e "${bldcya}Building ${bldgrn}ParanoidAndroid ${bldcya}for International Samsung Galaxy S2 ${txtrst}";;
   maguro)
       densitytrigger="192"
       device="maguro"
       manufacturer="samsung"
       echo -e "${bldcya}Building ${bldgrn}ParanoidAndroid ${bldcya}for International Samsung Galaxy Nexus ${txtrst}";;
   galaxys3)
       densitytrigger="192"
       device="i9300"
       manufacturer="samsung"
       echo -e "${bldcya}Building ${bldgrn}ParanoidAndroid ${bldcya}for International Samsung Galaxy S3 ${txtrst}";;
   toro)
       densitytrigger="192"
       device="toro"
       manufacturer="samsung"
       echo -e "${bldcya}Building ${bldgrn}ParanoidAndroid ${bldcya}for Verizon Samsung Galaxy Nexus ${txtrst}";;
   toroplus)
       densitytrigger="192"
       device="toroplus"
       manufacturer="samsung"
       echo -e "${bldcya}Building ${bldgrn}ParanoidAndroid ${bldcya}for Sprint Samsung Galaxy Nexus ${txtrst}";;
   *)
       echo -e "${bldred}Please input device name ${txtrst}"
       exit;;
esac

# change density for trigger on tablet mode
echo -e "${bldblu}Overwriting density for trigger density ${txtrst}"
cd device/$manufacturer/$device/
git reset --hard >/dev/null
find ./ -type f -exec sed -i 's|ro.sf.lcd_density=.*|ro.sf.lcd_density='$densitytrigger'|' {} \;

cd ./../../..

echo -e ""

# sync with latest sources
if [ "$SYNC" == "true" ]
then
   echo -e "${bldblu}Fetching latest sources ${txtrst}"
   repo sync -j16
   echo -e ""
fi

echo -e "${bldblu}Setting up environment ${txtrst}"

# setup environment
. build/envsetup.sh

echo -e ""
echo -e "${bldblu}Lunching device ${txtrst}"

# lunch device
lunch "cm_$device-userdebug";

echo -e ""
echo -e "${bldblu}Starting compilation ${txtrst}"

# start compilation
brunch "cm_$device-userdebug";
echo -e ""

# finished? get elapsed time
res2=$(date +%s.%N)
echo "${bldgrn}Total time elapsed: $(echo "($res2 - $res1)/60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds) ${txtrst}"
