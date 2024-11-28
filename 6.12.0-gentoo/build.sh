#!/bin/bash
# This script allows users to simplify the Kernel
# configuration and building process.
# https://github.com/saloniamatteo/kernel

# Name of the Kernel .config file in local directory
CONFIGFILE="config"
# How many threads to use to build Kernel (T470p = j6, T440p = -j4, PC = -j9)
JOBS="-j6"
# Kernel version
# NOTE: This MUST be of the form x.y.z, otherwise things WILL break!
KVER="6.12.0"
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
# Location of BORE sched patch
BOREDIR="$CUSTDIR/bore-scheduler"
# Location of v4l2loopback directory
V4L2DIR="$CUSTDIR/v4l2loopback"
# Location of CPU family optimizations directory
CFODIR="$CUSTDIR/kernel_compiler_patch"
# Location of Kernel-specific user directory
USRDIR="$CUSTDIR/$KERNVER"
# Set this variable if your Kernel is not located under /usr/src/
#KERNELDIR=""

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

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	printf "Flags:
-b,--skip-build     Do not build the Kernel
-c,--skip-cfg       Do not copy the Kernel config from this directory
-d,--distcc         Use distcc to speed up compilation /!\\
-e,--ccache         Use ccache to speed up compilation /!\\
-f,--fastmath       Build Kernel with Unsafe Fast Math [*]
-h,--help           Print this help and exit
-l,--clearl-ps      Enable Clear Linux patches [*]
-m,--menuconfig     Run 'make menuconfig' in Kernel directory and exit
-o,--cpu-opts       Build Kernel with CPU family optimisations [*]
-p,--patches        Apply provided patches (recommended) [*]
-r,--bore           Build Kernel with BORE scheduler [*]
-v,--v4l2           Build v4l2loopback Kernel module
-z,--vars           Print variables and exit

Note:
  - All options marked with '[*]', when enabled, may improve
    Kernel performance, whether it may be CPU, I/O, network, etc.
  - It is highly recommended to enable Clear Linux patches,
    CPU family optimizations, provided patches, as well as the BORE scheduler.
	Unsafe fast math may have a negligible performance increase,
	depending on your system. Use at your own risk!
  - If you're planning on using v4l2loopback with your own config,
    please read: https://github.com/umlaeute/v4l2loopback/discussions/604

Warning /!\\:
  - Distcc is recommended only if it is properly set up,
    and when you have powerful enough hosts.
  - CCache is recommended only if it is properly set up,
    and only when recompiling the same Kernel multiple times.
"
	exit
fi


if [[ "$1" == "-z" || "$1" == "--vars" ]]; then
	printf "Variables:
CONFIGFILE=$CONFIGFILE
JOBS=$JOBS
KVER=$KVER
PVER=$PVER
KERNVER=$KERNVER
CUSTDIR=$CUSTDIR
CLEARDIR=$CLEARDIR
PATCHDIR=$PATCHDIR
BOREDIR=$BOREDIR
V4L2DIR=$V4L2DIR
USRDIR=$USRDIR
KERNELDIR=$KERNELDIR
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
	CLEAR_PATCHES=(
		"0002-sched-core-add-some-branch-hints-based-on-gcov-analy.patch"
		"0102-increase-the-ext4-default-commit-age.patch"
		"0104-pci-pme-wakeups.patch"
		"0106-intel_idle-tweak-cpuidle-cstates.patch"
		"0108-smpboot-reuse-timer-calibration.patch"
		"0111-ipv4-tcp-allow-the-memory-tuning-for-tcp-to-go-a-lit.patch"
		"0120-do-accept-in-LIFO-order-for-cache-efficiency.patch"
		"0121-locking-rwsem-spin-faster.patch"
		"0122-ata-libahci-ignore-staggered-spin-up.patch"
		"0131-add-a-per-cpu-minimum-high-watermark-an-tune-batch-s.patch"
		"0135-initcall-only-print-non-zero-initcall-debug-to-speed.patch"
		"0136-crypto-kdf-make-the-module-init-call-a-late-init-cal.patch"
		"0158-clocksource-only-perform-extended-clocksource-checks.patch"
		"0161-ACPI-align-slab-buffers-for-improved-memory-performa.patch"
	)

	echo "Copying Clear Linux patches"
	for patch in ${CLEAR_PATCHES[@]}; do
		echo "Copying $patch"
		cp $CLEARDIR/$patch $KERNELDIR || exit
	done
fi

if [[ $@ =~ "-o" || $@ =~ "--cpu-opts" ]]; then
	# Check if CPU family optimizations directory exists
	if [ ! -d "$CFODIR" ]; then
		echo "Could not find CPU family optimisations directory."
		exit
	fi

	echo "Copying CPU family optimisation patches"
	cp "$CFODIR/more-ISA-levels-and-uarches-for-kernel-6.1.79+.patch" $KERNELDIR || exit
fi

if [[ $@ =~ "-p" || $@ =~ "--patches" ]]; then
	echo "Copying user patches"
	cp $PATCHDIR/*.patch $KERNELDIR || exit
fi

if [[ $@ =~ "-r" || $@ =~ "--bore" ]]; then
	# Extract the major version
	# Example: KVER: 6.11.7, KVER_MAJ: 6.11
	KVER_MAJ="${KVER%.*}"

	echo "Copying BORE patch"
	cp $BOREDIR/patches/stable/linux-$KVER_MAJ-bore/*patch $KERNELDIR || exit
fi

echo "Applying Clear Linux and/or user patches (if any)"
for p in *.patch; do
	echo "Applying patch '$p'..." && patch -Np1 -i $p
done

#echo "Setting version..." &&
#scripts/setlocalversion --save-scmversion ||

echo "Running make olddefconfig" &&
make $JOBS olddefconfig ||
exit

echo "Running make oldconfig && make prepare" &&
make $JOBS oldconfig && make $JOBS prepare ||
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

	# Extra optimimization flags:
	# -fivopts:
    #   Perform induction variable optimizations (strength reduction,
    #   induction variable merging and induction variable elimination) on trees.
  	# -fmodulo-sched:
    #   Perform swing modulo scheduling immediately before the first
    #   scheduling pass. This pass looks at innermost loops and reorders
    #   their instructions by overlapping different iterations.
	# Other optimization flags
	OPTS="-fivopts -fmodulo-sched -fno-tree-vectorize -mpopcnt"

	# Kernel build timer
	build_start=$(date "+%s")
	echo "Started build at $(date --date=@$build_start)"
	echo "Building Kernel Version $(make kernelrelease)"

	# Build Kernel
	make CC="$cc" KCFLAGS="$KCFLAGS $MATH $OPTS" $JOBS || exit
	make CC="$cc" $JOBS modules_prepare || exit

	# Stop Kernel build timer here, as it would be
	# inappropriate to count disk I/O time together
	# with CPU & RAM time for compilation.
	build_end=$(date "+%s")
	build_diff=$(expr $build_end - $build_start)
	echo "Finished Kernel build at $(date --date=@$build_end)."
	echo "Took $(date -d@$build_diff -u +%H:%M:%S)."

	# Modules + Kernel install timer
	install_start=$(date "+%s")
	echo "Started modules + Kernel install at $(date --date=@$install_start)"

	# Install modules + Kernel
	make CC="$cc" $JOBS modules_install || exit
	make CC="$cc" $JOBS install || exit

	# Modules + Kernel install timer stop
	install_end=$(date "+%s")
	install_diff=$(expr $install_end - $install_start)
	build_total=$(expr $build_diff + $install_diff)
	echo "Finished modules + Kernel install at $(date --date=@$install_end)."
	echo "Took $(date -d@$install_diff -u +%H:%M:%S)."
	echo "Total time (Kernel build + install): $(date -d@$build_total -u +%H:%M:%S)."

	# V4L2loopback
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
		build_total=$(expr $build_v4l2_diff + $build_diff + $install_diff)

		echo "Finished v4l2loopback build at $(date --date=@$build_v4l2_end)."
		echo "Took $(date -d@$build_v4l2_diff -u +%H:%M:%S)."
		echo "Total time (Kernel build + install + v4l2loopback): $(date -d@$build_total -u +%H:%M:%S)."
	fi
else
	echo "Skipping building Kernel. Exiting..."
fi
