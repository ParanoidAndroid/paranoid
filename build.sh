#!/bin/bash

# Get current path
DIR="$(cd `dirname $0`; pwd)"

# Colorize and add text parameters
red=$(tput setaf 1)             #  red
grn=$(tput setaf 2)             #  green
blu=$(tput setaf 4)             #  blue
cya=$(tput setaf 6)             #  cyan
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldgrn=${txtbld}$(tput setaf 2) #  green
bldblu=${txtbld}$(tput setaf 4) #  blue
bldcya=${txtbld}$(tput setaf 6) #  cyan
txtrst=$(tput sgr0)             # Reset

# Local defaults, can be overriden by env.
: ${PREFS_FROM_SOURCE:="false"}
#: ${USE_CCACHE="true"}
#: ${CCACHE_DIR:="$DIR/../ccache"}
: ${THREADS="16"}

DEVICE="$1"
EXTRAS="$2"

# get current version
if [ -r vendor/pa/config/pa_common.mk ]; then
	VENDOR="pa"
	MAJOR=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MAJOR = *' | sed  's/PA_VERSION_MAJOR = //g')
	MINOR=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MINOR = *' | sed  's/PA_VERSION_MINOR = //g')
	MAINTENANCE=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MAINTENANCE = *' | sed  's/PA_VERSION_MAINTENANCE = //g')
elif [ -r vendor/cm/config/common.mk ]; then
	VENDOR="cm"
	MAJOR=$(cat $DIR/vendor/cm/config/common.mk | grep 'PRODUCT_VERSION_MAJOR = *' | sed  's/PRODUCT_VERSION_MAJOR = //g')
	MINOR=$(cat $DIR/vendor/cm/config/common.mk | grep 'PRODUCT_VERSION_MINOR = *' | sed  's/PRODUCT_VERSION_MINOR = //g')
	MAINTENANCE=$(cat $DIR/vendor/cm/config/common.mk | grep 'PRODUCT_VERSION_MAINTENANCE = *' | sed  's/PRODUCT_VERSION_MAINTENANCE = //g')
else
	VENDOR="aosp"
	MAJOR=4
	MINOR=2
	MAINTENANCE=1
fi
VERSION=$VENDOR-$MAJOR.$MINOR$MAINTENANCE

# if we have not extras, reduce parameter index by 1
if [ "$EXTRAS" == "true" ] || [ "$EXTRAS" == "false" ]; then
	SYNC="$2"
	UPLOAD="$3"
else
	SYNC="$3"
	UPLOAD="$4"
fi

# get time of startup
res1=$(date +%s.%N)

# get ccache size at start
if [ -n "${USE_CCACHE}" ]; then
	export USE_CCACHE
	if [ -n "${CCACHE_DIR}" ]; then
		export CCACHE_DIR
		[ ! -d "${CCACHE_DIR}" ] && mkdir -p "${CCACHE_DIR}" && chmod ug+rwX "${CCACHE_DIR}"
		cache1=$(du -sh ${CCACHE_DIR} | awk '{print $1}')
	fi
fi

# we don't allow scrollback buffer
echo -e '\0033\0143'
clear

echo -e "${cya}Building ${bldcya}Android $VERSION for $DEVICE${txtrst}";
echo -e "${bldgrn}Start time: $(date) ${txtrst}"

[ -n "${USE_CCACHE}" ] && echo -e "${cya}Building using CCACHE${txtrst}"
[ -n "${CCACHE_DIR}" ] && echo -e "${bldgrn}CCACHE: location = [${txtrst}${grn}${CCACHE_DIR}${bldgrn}], size = [${txtrst}${grn}${cache1}${bldgrn}]${txtrst}"

if [ -d vendor/pa ]; then
	echo -e "${cya}"
	./vendor/pa/tools/getdevicetree.py $DEVICE
	echo -e "${txtrst}"
else
	echo -e "${bldcya}Not PA tree, skipping prebuilts${txtrst}"
fi


# decide what command to execute
case "$EXTRAS" in
	threads)
		echo -e "${bldblu}Please write desired threads followed by [ENTER]${txtrst}"
		read threads
		THREADS=$threads
	;;
	clean|cclean)
		echo -e "${bldblu}Cleaning intermediates and output files${txtrst}"
		rm -f vendor/pa/prebuilt/common/.get-prebuilts vendor/cm/proprietary/.get-prebuilts
		if [ $EXTRAS == cclean ] && [ -n "${CCACHE_DIR}" ]; then
			echo "${bldblu}Cleaning ccache${txtrst}"
			prebuilts/misc/linux-x86/ccache/ccache -C -M 5G
		fi
		make clean > /dev/null
	;;
esac

# sync with latest sources
if [ "$SYNC" == "true" ]; then
	echo -e ""
	echo -e "${bldblu}Fetching latest sources${txtrst}"
	repo sync -j"$THREADS"
	echo -e ""
fi

if [ -r vendor/cm/get-prebuilts ]; then
	if [ -r vendor/cm/proprietary/.get-prebuilts ]; then
		echo -e "${bldgrn}Already downloaded prebuilts${txtrst}"
	else
		echo -e "${bldblu}Downloading prebuilts${txtrst}"
		pushd vendor/cm > /dev/null
		rm -f proprietary/.get-prebuilts
		./get-prebuilts && touch proprietary/.get-prebuilts
		popd > /dev/null
	fi
elif [ -r vendor/pa/get-prebuilts ]; then
	if [ -r vendor/pa/prebuilt/common/.get-prebuilts ]; then
		echo -e "${bldgrn}Already downloaded prebuilts${txtrst}"
	else
		echo -e "${bldblu}Downloading prebuilts${txtrst}"
		pushd vendor/pa > /dev/null
		rm -f prebuilt/common/.get-prebuilts
		./get-prebuilts && touch prebuilt/common/.get-prebuilts
		popd > /dev/null
	fi
else
	echo -e "${bldcya}Not CM/PA tree, skipping prebuilts${txtrst}"
fi

# setup environment
echo -e ""
echo -e "${bldblu}Setting up environment${txtrst}"
. build/envsetup.sh

# lunch/brunch device
if [ -d vendor/pa ]; then
	echo -e ""
	echo -e "${bldblu}Lunching device [$DEVICE]${txtrst}"
	export PREFS_FROM_SOURCE
	lunch "pa_$DEVICE-userdebug";

	echo -e "${bldblu}Starting compilation${txtrst}"
	mka bacon
	echo -e ""
else
	echo -e ""
	echo -e "${bldblu}Brunching device [$DEVICE]${txtrst}"
	brunch $DEVICE
	echo -e ""
fi

if [ -n "${CCACHE_DIR}" ]; then
	# get ccache size
	cache2=$(du -sh ${CCACHE_DIR} | awk '{print $1}')
	echo -e "${bldgrn}cccache size is ${txtrst} ${grn}${cache2}${txtrst} (was ${grn}${cache1}${txtrst})"
fi

# finished? get elapsed time
res2=$(date +%s.%N)
echo -e "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1) / 60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds)${txtrst}"
