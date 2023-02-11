#!/bin/bash
# This script allows users to simplify the Kernel
# configuration and building process.
# https://github.com/saloniamatteo/kernel

# Sub-architecture number (24= Haswell, 34 = Rocket Lake)
ARCHVER=34
# Name of the Kernel .config file in local directory
CONFIGFILE="config.pc"
# How many threads to use to build Kernel
JOBS="-j6"
# Kernel version
KVER="6.1"
# Kernel "patch" version
PVER="_p5-pf"
# Full Kernel version
KERNVER="${KVER}${PVER}"
# Location of this directory (custom directory)
CUSTDIR="/usr/src/usr-kernel"
# Location of Clear Linux patch directory
CLEARDIR="$CUSTDIR/clear-patches"
# Location of included patches
PATCHDIR="$CUSTDIR/patches"
# Location of Kernel-specific user directory
USRDIR="$CUSTDIR/$KERNVER"
# Set this variable if your Kernel is not located under /usr/src/
#KERNELDIR=""

# Note: ARCHVER is the sub-architecture number,
# which will be used to apply optimizations for your specific CPU.
# Down below is a list of numbers and their corresponding CPU.
#
#   1. AMD Opteron/Athlon64/Hammer/K8 (MK8)
#   2. AMD Opteron/Athlon64/Hammer/K8 with SSE3 (MK8SSE3)
#   3. AMD 61xx/7x50/PhenomX3/X4/II/K10 (MK10)
#   4. AMD Barcelona (MBARCELONA)
#   5. AMD Bobcat (MBOBCAT)
#   6. AMD Jaguar (MJAGUAR)
#   7. AMD Bulldozer (MBULLDOZER)
#   8. AMD Piledriver (MPILEDRIVER)
#   9. AMD Steamroller (MSTEAMROLLER)
#  10. AMD Excavator (MEXCAVATOR)
#  11. AMD Zen (MZEN)
#  12. AMD Zen 2 (MZEN2)
#  13. AMD Zen 3 (MZEN3)
#  14. Intel P4 / older Netburst based Xeon (MPSC)
#  15. Intel Core 2 (MCORE2)
#  16. Intel Atom (MATOM)
#  17. Intel Nehalem (MNEHALEM)
#  18. Intel Westmere (MWESTMERE)
#  19. Intel Silvermont (MSILVERMONT)
#  20. Intel Goldmont (MGOLDMONT)
#  21. Intel Goldmont Plus (MGOLDMONTPLUS)
#  22. Intel Sandy Bridge (MSANDYBRIDGE)
#  23. Intel Ivy Bridge (MIVYBRIDGE)
#  24. Intel Haswell (MHASWELL)
#  25. Intel Broadwell (MBROADWELL)
#  26. Intel Skylake (MSKYLAKE)
#  27. Intel Skylake X (MSKYLAKEX)
#  28. Intel Cannon Lake (MCANNONLAKE)
#  29. Intel Ice Lake (MICELAKE)
#  30. Intel Cascade Lake (MCASCADELAKE)
#  31. Intel Cooper Lake (MCOOPERLAKE)
#  32. Intel Tiger Lake (MTIGERLAKE)
#  33. Intel Sapphire Rapids (MSAPPHIRERAPIDS)
#  34. Intel Rocket Lake (MROCKETLAKE)
#  35. Intel Alder Lake (MALDERLAKE)
#  36. Generic-x86-64 (GENERIC_CPU)
#  37. Generic-x86-64-v2 (GENERIC_CPU2)
#  38. Generic-x86-64-v3 (GENERIC_CPU3)
#  39. Generic-x86-64-v4 (GENERIC_CPU4)
#  40. Intel-Native optimizations autodetected by GCC (MNATIVE_INTEL)
#  41. AMD-Native optimizations autodetected by GCC (MNATIVE_AMD)

# Check if KERNELDIR is set
if [ -z ${KERNELDIR} ]; then
	# Try to set kernel directory to /usr/src/linux-$KERNVER;
	# If it does not exist, try /usr/src/linux
	if [ -d "/usr/src/linux-$KERNVER" ]; then
		KERNELDIR="/usr/src/linux-$KERNVER"
	else if [ -d "/usr/src/linux" ]; then
		KERNELDIR="/usr/src/linux"
	else
		echo "Could not find Kernel directory! "
		exit -1
	fi
	fi
else if [ ! -d $KERNELDIR ]; then
	echo "KERNELDIR $KERNELDIR is invalid!"
	exit -1
fi
fi

# Check if user directory exists
if [ ! -d "$USRDIR" ]; then
	echo "Could not find Custom Kernel directory! "
	exit -2
fi

# Check that required files exist in user directory
# Note: we don't check if patches exist because
# we can apply them optionally;
# we don't check for build.sh because
# how are we running this script?
if [ ! -f "$USRDIR/config" ]; then
	echo "Config is missing from Custom Kernel directory! "
	exit -3
else if [ ! -f "$CUSTDIR/modprobed.db" ]; then
	echo "Modprobed.db is missing from Custom Kernel directory! "
	exit -4
fi
fi

# If argument is "-h" or "--help", print exit codes
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	printf "Exit codes:
-10		Successfully printed help
-4		Cannot find modprobed.db  in $CUSTDIR
-3		Cannot find Kernel config in $USRDIR
-2		Could not find Custom Kernel directory
-1		Could not find Kernel directory
00		Successfully built Kernel
01		Failed to copy config
03		Failed to copy modprobed.db
07		Failed to copy Clear Linux/user patches
08		Failed to set config values
09		Failed to run make olddefconfig
10		Failed to run make oldconfig
11		Failed to run make localmodconfig
12		Failed to copy config to config.last
13		Failed to run make clean
14		Failed to run make $JOBS
15		Failed to run make $JOBS modules_prepare
16		Failed to run make $JOBS modules_install
17		Failed to run make $JOBS install
99		Ran 'make menuconfig' with -m option

Flags:
-b,--skip-build	Skip building the Kernel
-c,--skip-cfg	Skip copying Kernel configuration
-d,--modprobed	Build only Kernel modules defined in modprobed.db
-e,--ccache	Use ccache to speed up compilation
-f,--fastmath	Build Kernel with Fast Math (unsafe)	[*]
-F,--fastmath-s	Build Kernel with Fast Math (safe)	[*]
-g,--graphite	Build Kernel with Graphite		[*]
-h,--help	Print this help and exit
-l,--clearl-ps	Enable Clear Linux patches		[*]
-m,--menuconfig	Run 'make menuconfig' in Kernel directory and exit
-p,--patches	Apply user patches (recommended)

Note: all options marked with '[*]', when enabled,
may or may not improve the performance of the Kernel at runtime,
at the cost of slightly longer compilation time,
and/or slightly higher Kernel size.

Note 2: Clear Linux patches are HIGHLY recommended for Intel CPUs.
Results may vary.

Variables:
ARCHVER=$ARCHVER
CONFIGFILE=$CONFIGFILE 
JOBS=$JOBS
KVER=$KVER
PVER=$PVER
KERNVER=$KERNVER
CUSTDIR=$CUSTDIR
CLEARDIR=$CLEARDIR
PATCHDIR=$PATCHDIR
USRDIR=$USRDIR
"
	exit -10
fi

cd $KERNELDIR

# Revert and remove any patches first
echo "Reverting and removing pre-existing patches (if any)" && for p in *.patch; do echo "Reverting patch $p..."; patch -Rfsp1 -i $p; done
rm *.patch

if ! [[ $@ =~ "-c" || $@ =~ "--skip-cfg" ]]; then
	echo "Copying config" &&
	cp $USRDIR/$CONFIGFILE $KERNELDIR/config &&
	cp config .config ||
	exit 1
else
	echo "Skipping copying config.."
fi

if [[ $@ =~ "-d" || $@ =~ "--modprobed" ]]; then
	echo "Copying modprobed.db" &&
	cp $USRDIR/modprobed.db $KERNELDIR ||
	exit 3
else
	echo "Skipping building modules according to modprobed.db.."
fi

if [[ $@ =~ "-l" || $@ =~ "--clearl-ps" ]]; then
	echo "Copying Clear Linux patches"
	cp $CLEARDIR/0{102,104,105,106,108,109,111,112,118,119,120,122,123,128}*.patch $KERNELDIR || exit 7
	cp $CLEARDIR/itmt2.patch $KERNELDIR || exit 7
fi

if [[ $@ =~ "-p" || $@ =~ "--patches" ]]; then
	echo "Copying user patches"
	cp $PATCHDIR/0*.patch $KERNELDIR || exit 7
fi

echo "Applying Clear Linux and/or user patches (if any)"
for p in *.patch; do
	echo "Applying patch '$p'..." && patch -Np1 -i $p
done

echo "Setting config values" &&
scripts/config --enable  CONFIG_PSI_DEFAULT_DISABLED &&
scripts/config --disable CONFIG_DEBUG_INFO &&
scripts/config --disable CONFIG_CGROUP_BPF &&
scripts/config --disable CONFIG_BPF_LSM &&
scripts/config --disable CONFIG_BPF_PRELOAD &&
scripts/config --disable CONFIG_BPF_LIRC_MODE2 &&
scripts/config --disable CONFIG_BPF_KPROBE_OVERRIDE &&
scripts/config --disable CONFIG_LATENCYTOP &&
scripts/config --disable CONFIG_SCHED_DEBUG &&
scripts/config --disable CONFIG_KVM_WERROR &&
echo "Setting version..." &&
scripts/setlocalversion --save-scmversion ||
exit 8

echo "Running make olddefconfig" &&
make $JOBS olddefconfig ||
exit 9

echo "Running yes $ARCHVER | make oldconfig && make prepare" &&
yes $ARCHVER | make $JOBS oldconfig && make $JOBS prepare ||
exit 10

if [[ $@ =~ "-d" || $@ =~ "--modprobed" ]]; then
	echo "Running make localmodconfig" &&
	make LSMOD="$KERNELDIR/modprobed.db" $JOBS localmodconfig ||
	exit 11
fi

echo "Copying config to config.last" &&
cp .config config.last ||
exit 12

echo "Running make clean" &&
make $JOBS clean ||
exit 13

if [[ $@ =~ "-m" || $@ =~ "--menuconfig" ]]; then
	make $JOBS menuconfig
	exit 99
fi

if ! [[ $@ =~ "-b" || $@ =~ "--skip-build" ]]; then
	# Don't use build timestap (slows down cache)
	export KBUILD_BUILD_TIMESTAMP=""

	# Math optimizations
	SAFE_FAST_MATH="-fno-math-errno -fno-trapping-math"
	FAST_MATH="-fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math -fno-math-errno -ffinite-math-only -fno-rounding-math -fno-signaling-nans -fcx-limited-range -fexcess-precision=fast"

	# Check if we can use ccache
	if [[ $@ =~ "-e" || $@ =~ "--ccache" ]]; then
		cc="ccache gcc"
	else
		cc="gcc"
	fi

	# Check if Graphite is enabled
	if [[ $@ =~ "-g" || $@ =~ "--graphite" ]]; then
		GRAPHITE="-falign-functions=32 -fgraphite-identity -floop-nest-optimize"
	else
		GRAPHITE=""
	fi

	# Check if unsafe Fast Math is enabled
	if [[ $@ =~ "-f" || $@ =~ "--fastmath" ]]; then
		MATH="$FAST_MATH"
	else
		# Check if safe Fast Math is enabled
		if [[ $@ =~ "-F" || $@ =~ "--fastmath-s" ]]; then
			MATH="$SAFE_FAST_MATH"
		else
			MATH=""
		fi
	fi

	build_start=$(date "+%s")

	echo "Started build at $(date --date=@$build_start)"
	echo "Building Kernel Version $(make kernelrelease)"

	make CC="$cc" KCFLAGS+="$GRAPHITE $MATH" $JOBS || exit 14
	make CC="$cc" $JOBS modules_prepare || exit 15
	make CC="$cc" $JOBS modules_install || exit 16
	make CC="$cc" $JOBS install || exit 17

	build_end=$(date "+%s")
	build_diff=$(expr $build_end - $build_start)

	echo "Finished Kernel build at $(date --date=@$build_end)."
	echo "Took $(date -d@$build_diff -u +%H:%M:%S)."
else
	echo "Skipping building Kernel. Exiting..."
fi
