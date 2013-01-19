#!/bin/bash

# Version 2.0.1

# We don't allow scrollback buffer
echo -e '\0033\0143'
clear

# Get current path
DIR="$(cd `dirname $0`; pwd)"
OUT="$(readlink $DIR/out)"
[ -z "${OUT}" ] && OUT="${DIR}/out"

# Prepare output customization commands
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

# Local defaults, can be overriden by environment
: ${PREFS_FROM_SOURCE:="false"}
: ${USE_CCACHE:="false"}
: ${CCACHE_NOSTATS:="false"}
: ${CCACHE_DIR:="$(dirname $OUT)/ccache"}
: ${THREADS:="$(cat /proc/cpuinfo | grep "^processor" | wc -l)"}

# If there is more than one jdk installed, use latest 6.x
if [ "`update-alternatives --list javac | wc -l`" -gt 1 ]; then
	JDK6=$(dirname `update-alternatives --list javac | grep "\-6\-"` | tail -n1)
	JRE6=$(dirname ${JDK6}/../jre/bin/java)
	export PATH=${JDK6}:${JRE6}:$PATH
fi
JVER=$(javac -version  2>&1 | head -n1 | cut -f2 -d' ')

# Import command line parameters
DEVICE="$1"
EXTRAS="$2"

# Get build version
if [ -r vendor/pa/config/pa_common.mk ]; then
	VENDOR="pa"
	MAJOR=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MAJOR = *' | sed  's/PA_VERSION_MAJOR = //g')
	MINOR=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MINOR = *' | sed  's/PA_VERSION_MINOR = //g')
	MAINTENANCE=$(cat $DIR/vendor/pa/config/pa_common.mk | grep 'PA_VERSION_MAINTENANCE = *' | sed  's/PA_VERSION_MAINTENANCE = //g')
elif [ -r vendor/cm/build.sh ]; then
	VENDOR="jb"
	MAJOR=$(cat $DIR/vendor/cm/config/common.mk | grep 'JELLY_BEER_VERSION_MAJOR := *' | sed  's/JELLY_BEER_VERSION_MAJOR := //g')
	MINOR=$(cat $DIR/vendor/cm/config/common.mk | grep 'JELLY_BEER_VERSION_MINOR := *' | sed  's/JELLY_BEER_VERSION_MINOR := //g')
	MAINTENANCE=$(cat $DIR/vendor/cm/config/common.mk | grep 'JELLY_BEER_VERSION_MAINTENANCE := *' | sed  's/JELLY_BEER_VERSION_MAINTENANCE := //g')
elif [ -r vendor/cm/config/common.mk ]; then
	VENDOR="cm"
	MAJOR=$(cat $DIR/vendor/cm/config/common.mk | grep 'PRODUCT_VERSION_MAJOR = *' | sed  's/PRODUCT_VERSION_MAJOR = //g')
	MINOR=$(cat $DIR/vendor/cm/config/common.mk | grep 'PRODUCT_VERSION_MINOR = *' | sed  's/PRODUCT_VERSION_MINOR = //g')
	MAINTENANCE=$(cat $DIR/vendor/cm/config/common.mk | grep 'PRODUCT_VERSION_MAINTENANCE = *' | sed  's/PRODUCT_VERSION_MAINTENANCE = //g')
else
	VENDOR="aosp"
	MAJOR=$(cat $DIR/build/core/version_defaults.mk | grep 'PLATFORM_VERSION := *' | awk '{print $3}' | cut -f2 -d= | cut -f1 -d.)
	MINOR=$(cat $DIR/build/core/version_defaults.mk | grep 'PLATFORM_VERSION := *' | awk '{print $3}' | cut -f2 -d= | cut -f2 -d.)
	MAINTENANCE=$(cat $DIR/build/core/version_defaults.mk | grep 'PLATFORM_VERSION := *' | awk '{print $3}' | cut -f2 -d= | cut -f3 -d.)
fi
VERSION=$VENDOR-$MAJOR.$MINOR.$MAINTENANCE

# If there is no extra parameter, reduce parameters index by 1
if [ "$EXTRAS" == "true" ] || [ "$EXTRAS" == "false" ]; then
	SYNC="$2"
	UPLOAD="$3"
else
	SYNC="$3"
	UPLOAD="$4"
fi

# Get start time
res1=$(date +%s.%N)

# Get ccache size at start
if [ "${USE_CCACHE}" == "true" ]; then
	CCACHE="$(which ccache)"
	if [ -n "${CCACHE}" ]; then
		echo -e "${bldblu}Using system ccache [${CCACHE}]${txtrst}"
	elif [ -r "${DIR}/prebuilts/misc/linux-x86/ccache/ccache" ]; then
		CCACHE="${DIR}/prebuilts/misc/linux-x86/ccache/ccache"
		echo -e "${bldblu}Using prebuilt ccache [${CCACHE}]${txtrst}"
	else
		echo -e "${bldblu}No ccache found, disabling ccache usage${txtrst}"
		unset USE_CCACHE
		unset CCACHE_DIR
		unset CCACHE_NOSTATS
		unset CCACHE
	fi

	if [ -n "${CCACHE}" ]; then
		CCACHE_OPT="ccache=${CCACHE}"
		if [ -n "${CCACHE_DIR}" ]; then
			export CCACHE_DIR
			if [ ! -d "${CCACHE_DIR}" ]; then
				mkdir -p "${CCACHE_DIR}"
				chmod ug+rwX "${CCACHE_DIR}"
				${CCACHE} -C -M 5G
				cache1=0
			fi
		else
			CCACHE_DIR="${HOME}/.ccache"
		fi
	fi

	if [ -z "${cache1}" ]; then
		if [ "${CCACHE_NOSTATS}" == "true" ]; then
			cache1=$(du -sh ${CCACHE_DIR} | awk '{print $1}')
		else
			cache1=$(${CCACHE} -s | grep "^cache size" | awk '{print $3$4}')
		fi
	fi
else
	unset USE_CCACHE
	unset CCACHE_DIR
	unset CCACHE_NOSTATS
	unset CCACHE
fi

echo -e "${cya}Building ${bldcya}Android $VERSION for $DEVICE using Java-$JVER${txtrst}";
echo -e "${bldgrn}Start time: $(date) ${txtrst}"

[ -n "${USE_CCACHE}" ] && export USE_CCACHE && echo -e "${cya}Building using CCACHE${txtrst}"
[ -n "${CCACHE_DIR}" ] && export CCACHE_DIR && echo -e "${bldgrn}CCACHE: location = [${txtrst}${grn}${CCACHE_DIR}${bldgrn}], size = [${txtrst}${grn}${cache1}${bldgrn}]${txtrst}"

if [ -d vendor/pa ]; then
	echo -e "${cya}"
	./vendor/pa/tools/getdevicetree.py $DEVICE
	echo -en "${txtrst}"
else
	echo -e "${bldcya}Not PA tree, skipping device tree${txtrst}"
fi
echo -e ""

# Decide what command to execute
case "$EXTRAS" in
	threads)
		echo -e "${bldblu}Please enter desired building/syncing threads number followed by [ENTER]${txtrst}"
		read threads
		THREADS=$threads
	;;
	clean|cclean)
		echo -e "${bldblu}Cleaning intermediates and output files${txtrst}"
		rm -f vendor/{pa,cm,aosp}/{prebuilt/common/,proprietary/,}.get-prebuilts
		if [ $EXTRAS == cclean ] && [ -n "${CCACHE_DIR}" ]; then
			echo "${bldblu}Cleaning ccache${txtrst}"
			${CCACHE} -C -M 5G
		fi

		[ -d "${DIR}/out" ] && rm -Rf ${DIR}/out/*
	;;
esac

# Fetch latest sources
if [ "$SYNC" == "true" ]; then
	echo -e ""
	echo -e "${bldblu}Fetching latest sources${txtrst}"
	repo sync -j"$THREADS"
	echo -e ""
fi

if [ ! -r "${DIR}/out/versions_checked.mk" ] && [ -n "$(java -version 2>&1 | grep -i openjdk)" ]; then
	echo -e "${bldcya}Your java version still not checked and is candidate to fail, masquerading.${txtrst}"
	JAVA_VERSION="java_version=${JVER}"
fi

if [ -r vendor/cm/get-prebuilts ]; then
	if [ -r vendor/cm/proprietary/.get-prebuilts ]; then
		echo -e "${bldgrn}Already downloaded prebuilts${txtrst}"
	else
		echo -e "${bldblu}Downloading prebuilts${txtrst}"
		pushd vendor/cm > /dev/null
		./get-prebuilts && touch proprietary/.get-prebuilts
		popd > /dev/null
	fi
elif [ -r vendor/pa/get-prebuilts ]; then
	if [ -r vendor/pa/prebuilt/common/.get-prebuilts ]; then
		echo -e "${bldgrn}Already downloaded prebuilts${txtrst}"
	else
		echo -e "${bldblu}Downloading prebuilts${txtrst}"
		pushd vendor/pa > /dev/null
		./get-prebuilts && touch prebuilt/common/.get-prebuilts
		popd > /dev/null
	fi
else
	if [ -r vendor/aosp/.get-prebuilts ]; then
		echo -e "${bldgrn}Already downloaded prebuilts${txtrst}"
	else
		echo -e "${bldblu}Downloading prebuilts${txtrst}"
		pushd vendor/aosp > /dev/null
		./get-prebuilts && touch .get-prebuilts
		popd > /dev/null
	fi
fi

if [ -n "${INTERACTIVE}" ]; then
	echo -e "${bldblu}Dropping to interactive shell${txtrst}"
	echo -en "${bldblu}Remeber to lunch you device:"
	if [ "${VENDOR}" == "pa" ]; then
		echo -e "[${bldgrn}lunch pa_$DEVICE-userdebug${bldblu}]${txtrst}"
	else
		echo -e "[${bldgrn}lunch full_$DEVICE-userdebug${bldblu}]${txtrst}"
	fi
	bash --init-file build/envsetup.sh -i
else
	# Setup environment
	echo -e ""
	echo -e "${bldblu}Setting up environment${txtrst}"
	. build/envsetup.sh
	echo -e ""

	# lunch/brunch device
	if [ -d vendor/pa ]; then
		echo -e "${bldblu}Lunching device [$DEVICE]${txtrst}"
		export PREFS_FROM_SOURCE
		lunch "pa_$DEVICE-userdebug";

		#echo -e "${bldblu}Saving build manifest${txtrst}"
		#repo manifest -o vendor/pa/prebuilt/common/etc/build-manifest.xml -r
		#echo -e ""

		echo -e "${bldblu}Starting compilation${txtrst}"
		mka bacon
	elif [ -d vendor/cm ]; then
		echo -e "${bldblu}Brunching device [$DEVICE]${txtrst}"
		brunch $DEVICE
        else
		echo -ne "${bldblu}Lunching device [$DEVICE]${txtrst}"
		lunch "full_$DEVICE-userdebug";

		echo -e "${bldblu}Starting compilation${txtrst}"
		schedtool -B -n 1 -e ionice -n 1 make -j${THREADS} ${CCACHE_OPT} ${JAVA_VERSION} otapackage
	fi
fi
echo -e ""

if [ -n "${CCACHE_DIR}" ]; then
	# Get ccache size
	if [ "${CCACHE_NOSTATS}" == "true" ]; then
		cache2=$(du -sh ${CCACHE_DIR} | awk '{print $1}')
	else
		cache2=$(prebuilts/misc/linux-x86/ccache/ccache -s | grep "^cache size" | awk '{print $3$4}')
	fi
	echo -e "${bldgrn}ccache size is ${txtrst} ${grn}${cache2}${txtrst} (was ${grn}${cache1}${txtrst})"
fi

# Finished? Get elapsed time
res2=$(date +%s.%N)
echo -e "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1) / 60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds)${txtrst}"
