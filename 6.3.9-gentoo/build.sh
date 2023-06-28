#!/bin/bash
# This script allows users to simplify the Kernel
# configuration and building process.
# https://github.com/saloniamatteo/kernel

# Sub-architecture number (24 = Haswell, 34 = Rocket Lake)
ARCHVER=24
# Name of the Kernel .config file in local directory
CONFIGFILE="config"
# How many threads to use to build Kernel
JOBS="-j4"
# Kernel version
KVER="6.3.9"
# Kernel "patch" version
PVER="-gentoo"
# Full Kernel version
KERNVER="${KVER}${PVER}"
# Location of this directory (custom directory)
CUSTDIR="/usr/src/usr-kernel"
# Location of Clear Linux patch directory
CLEARDIR="$CUSTDIR/clear-patches"
# Location of included patches
PATCHDIR="$CUSTDIR/patches"
# Location of v4l2loopback directory
V4L2DIR="$CUSTDIR/v4l2loopback"
# Location of CPU family optimizations directory
CFODIR="$CUSTDIR/kernel_compiler_patch"
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
		echo "Could not find Kernel directory."
		exit
	fi
	fi
else if [ ! -d $KERNELDIR ]; then
	echo "KERNELDIR $KERNELDIR is invalid."
	exit
fi
fi

# Check if user directory exists
if [ ! -d "$USRDIR" ]; then
	echo "Could not find Custom Kernel directory."
	exit
fi

# Check that required files exist in user directory
# Note: we don't check if patches exist because
# we can apply them optionally
if [ ! -f "$USRDIR/config" ]; then
	echo "Config is missing from Custom Kernel directory."
	exit
fi

# If argument is "-h" or "--help", print exit codes
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	printf "Flags:
-b,--skip-build Skip building the Kernel
-c,--skip-cfg   Skip copying Kernel configuration
-d,--distcc     Use distcc to speed up compilation
-e,--ccache     Use ccache to speed up compilation
-f,--fastmath   Build Kernel with Unsafe Fast Math [*]
-h,--help       Print this help and exit
-l,--clearl-ps  Enable Clear Linux patches [*]
-m,--menuconfig Run 'make menuconfig' in Kernel directory and exit
-o,--cpu-opts   Build Kernel with CPU family optimisations [*]
-p,--patches    Apply user patches (recommended)
-v,--v4l2       Build v4l2loopback Kernel module

Note:
    - All options marked with '[*]', when enabled, may or may not
	  improve the performance of the Kernel at runtime, at the cost
	  of slightly longer compilation time, and/or slightly higher Kernel size.
    - Clear Linux patches are HIGHLY recommended for Intel CPUs.
    - Distcc is recommended if it is properly set up, as it uses
	  the computing power of other hosts to compile the Kernel.
    - CCache is recommended only when recompiling the same Kernel multiple times.
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
V4L2DIR=$V4L2DIR
USRDIR=$USRDIR
"
	exit
fi

cd $KERNELDIR

# Revert and remove any patches first
echo "Reverting and removing pre-existing patches (if any)" && for p in *.patch; do echo "Reverting patch $p..."; patch -Rfsp1 -i $p; done
rm *.patch

if ! [[ $@ =~ "-c" || $@ =~ "--skip-cfg" ]]; then
	echo "Copying config" &&
	cp $USRDIR/$CONFIGFILE $KERNELDIR/config &&
	cp config .config ||
	exit
else
	echo "Skipping copying config.."
fi

if [[ $@ =~ "-l" || $@ =~ "--clearl-ps" ]]; then
	echo "Copying Clear Linux patches"
	cp $CLEARDIR/0001-sched-cpuset-Fix-dl_cpu_busy-panic-due-to-empty-cs-c.patch $KERNELDIR || exit
	cp $CLEARDIR/0001-sched-migrate.patch                                        $KERNELDIR || exit
	cp $CLEARDIR/0002-sched-core-add-some-branch-hints-based-on-gcov-analy.patch $KERNELDIR || exit
	cp $CLEARDIR/0{006,007,008,051,102,104,105,106,108,109,111,112,118}*.patch   $KERNELDIR || exit
	cp $CLEARDIR/0{120,122,123,130,131,135,158}*.patch                           $KERNELDIR || exit
fi

if [[ $@ =~ "-o" || $@ =~ "--cpu-opts" ]]; then
	# Check if CPU family optimizations directory exists
	if [ ! -d "$CFODIR" ]; then
		echo "Could not find CPU family optimisations directory."
		exit
	fi

	echo "Copying CPU family optimisation patches"
	cp $CFODIR/more-uarches-for-kernel-5.17+.patch $KERNELDIR || exit
fi

if [[ $@ =~ "-p" || $@ =~ "--patches" ]]; then
	echo "Copying user patches"
	cp $PATCHDIR/0*.patch $KERNELDIR || exit
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
scripts/config --disable CONFIG_KVM_WERROR ||
exit

#echo "Setting version..." &&
#scripts/setlocalversion --save-scmversion ||

echo "Running make olddefconfig" &&
make $JOBS olddefconfig ||
exit

echo "Running yes $ARCHVER | make oldconfig && make prepare" &&
yes $ARCHVER | make $JOBS oldconfig && make $JOBS prepare ||
exit

echo "Copying config to config.last" &&
cp .config config.last ||
exit

echo "Running make clean" &&
make $JOBS clean ||
exit

if [[ $@ =~ "-m" || $@ =~ "--menuconfig" ]]; then
	make $JOBS menuconfig
	exit
fi

if ! [[ $@ =~ "-b" || $@ =~ "--skip-build" ]]; then
	# Don't use build timestap (slows down cache)
	export KBUILD_BUILD_TIMESTAMP=""

	# Math optimizations
	FAST_MATH="-fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math -fno-math-errno -ffinite-math-only -fno-rounding-math -fno-signaling-nans -fcx-limited-range -fexcess-precision=fast"

	# Check if we can use ccache
	if [[ $@ =~ "-e" || $@ =~ "--ccache" ]]; then
		echo "Using ccache..."
		cc="ccache gcc"
	else
		cc="gcc"
	fi

	# Check if we can use distcc
	if [[ $@ =~ "-d" || $@ =~ "--distcc" ]]; then
		echo "Using distcc..."
		cc="distcc $cc"
	fi

	echo "Compiler command (CC): $cc"

	# Check if Fast Math is enabled
	if [[ $@ =~ "-f" || $@ =~ "--fastmath" ]]; then
		MATH="$FAST_MATH"
	else
		MATH=""
	fi

	# Other optimization flags
	OPTS="-fno-tree-vectorize -mpopcnt"

	build_start=$(date "+%s")

	echo "Started build at $(date --date=@$build_start)"
	echo "Building Kernel Version $(make kernelrelease)"

	make CC="$cc" KCFLAGS="$KCFLAGS $MATH $OPTS" $JOBS || exit
	make CC="$cc" $JOBS modules_prepare || exit
	make CC="$cc" $JOBS modules_install || exit
	make CC="$cc" $JOBS install || exit

	build_end=$(date "+%s")
	build_diff=$(expr $build_end - $build_start)

	echo "Finished Kernel build at $(date --date=@$build_end)."
	echo "Took $(date -d@$build_diff -u +%H:%M:%S)."

	if [[ $@ =~ "-v" || $@ =~ "--v4l2" ]]; then
		# Check if V4L2DIR exists
		if [ ! -d "$V4L2DIR" ]; then
			echo "Could not find v4l2loopback directory.";
			exit
		fi

		build_v4l2_start=$(date "+%s")

		echo "Started v4l2loopback build at $(date --date=@$build_v4l2_start)"

		cd $V4L2DIR

		make $JOBS KERNELRELEASE=$KERNVER || exit
		make KERNELRELEASE=$KERNVER install || exit

		# Reload module dependencies
		depmod -a 

		build_v4l2_end=$(date "+%s")
		build_v4l2_diff=$(expr $build_v4l2_end - $build_v4l2_start)
		build_total=$(expr $build_v4l2_diff + $build_diff)

		echo "Finished v4l2loopback build at $(date --date=@$build_v4l2_end)."
		echo "Took $(date -d@$build_v4l2_diff -u +%H:%M:%S)."
		echo "Total time (Kernel + v4l2loopback): $(date -d@$build_total -u +%H:%M:%S)."
	fi
else
	echo "Skipping building Kernel. Exiting..."
fi
