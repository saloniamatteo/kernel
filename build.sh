#!/bin/bash
# This script allows users to simplify the Kernel
# configuration, compilation & installation process.
# https://github.com/saloniamatteo/kernel
# ======================================================

# Directory containing the provided assets
# Change this to reflect your preferences
# Default is /usr/src/usr-kernel
CUSTDIR="/usr/src/usr-kernel"

# Kernel versions
# NOTE: $KVER MUST be of the form x.y.z, otherwise things WILL break!
KVER="6.13.6"	# Primary Kernel version
PVER="-gentoo"	# Kernel "patch" version

# Set this variable if your Kernel is not located under /usr/src/
# Default is empty
#KERNELDIR=""

# How many threads to use to build Kernel
# T470p = -j6
# T440p = -j4
# PC = -j9
# You can set any value you like.
JOBS="-j6"

# Name of the Kernel config file under $CUSTDIR/$KERNVER
# Choose between "config", "config.t440p", "config.pc"
# You can provide your own config file by placing it under $CUSTDIR/$KERNVER.
CONFIGFILE="config"

# ======================================================
# Do not modify these unless you know what you're doing.
# Full Kernel version
KERNVER="${KVER}${PVER}"
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

# Set variables based on flag status
[[ $@ =~ "-b" || $@ =~ "--skip-build" ]] && F_SKIP_BUILD=1
[[ $@ =~ "-c" || $@ =~ "--skip-cfg" ]] && F_SKIP_CFG=1
[[ $@ =~ "-d" || $@ =~ "--distcc" ]] && F_DISTCC=1
[[ $@ =~ "-e" || $@ =~ "--ccache" ]] && F_CCACHE=1
[[ $@ =~ "-f" || $@ =~ "--fastmath" ]] && F_FASTMATH=1
[[ $@ =~ "-g" || $@ =~ "--graphite" ]] && F_GRAPHITE=1
[[ $@ =~ "-h" || $@ =~ "--help" ]] && F_PRINT_HELP=1
[[ $@ =~ "-l" || $@ =~ "--clearl-ps" ]] && F_CLEARLINUX_PATCHES=1
[[ $@ =~ "-m" || $@ =~ "--menuconfig" ]] && F_MENUCONFIG=1
[[ $@ =~ "-o" || $@ =~ "--cpu-opts" ]] && F_CPU_OPTS=1
[[ $@ =~ "-p" || $@ =~ "--patches" ]] && F_PATCHES=1
[[ $@ =~ "-r" || $@ =~ "--bore" ]] && F_BORE=1
[[ $@ =~ "-v" || $@ =~ "--v4l2" ]] && F_V4L2=1
[[ $@ =~ "-z" || $@ =~ "--vars" ]] && F_PRINT_VARS=1

# Flag presets
if [[ $@ =~ "--preset-configure" ]]; then
	F_CLEARLINUX_PATCHES=1
	F_MENUCONFIG=1
	F_CPU_OPTS=1
	F_PATCHES=1
	F_BORE=1
else if [[ $@ =~ "--preset-build" ]]; then
	F_FASTMATH=1
	F_GRAPHITE=1
	F_CLEARLINUX_PATCHES=1
	F_MENUCONFIG=0
	F_CPU_OPTS=1
	F_PATCHES=1
	F_BORE=1
fi
fi

# Print help
if [ $F_PRINT_HELP ]; then
	printf "Flags:
-b,--skip-build     Do not build the Kernel
-c,--skip-cfg       Do not copy the Kernel config from this directory
-d,--distcc         Use distcc to speed up compilation /!\\
-e,--ccache         Use ccache to speed up compilation /!\\
-f,--fastmath       Build Kernel with Unsafe Fast Math [*]
-g,--graphite       Build Kernel with Graphite [*]
-h,--help           Print this help and exit
-l,--clearl-ps      Enable Clear Linux patches [*]
-m,--menuconfig     Run 'make menuconfig' in Kernel directory and exit
-o,--cpu-opts       Build Kernel with CPU family optimisations [*]
-p,--patches        Apply provided patches (recommended) [*]
-r,--bore           Build Kernel with BORE scheduler [*]
-v,--v4l2           Build v4l2loopback Kernel module
-z,--vars           Print variables and exit

Presets (mutually exclusive):
--preset-configure	Selects the following flags:
			-f, -g, -l, -o, -p, -r

--preset-build		Selects the following flags:
			-l, -m, -o, -p, -r

Note:
  - All options marked with '[*]', when enabled, may improve
    Kernel performance, whether it may be CPU, I/O, network, etc.
  - It is highly recommended to enable Clear Linux patches,
    CPU family optimizations, provided patches, as well as the BORE scheduler.
	Unsafe fast math may have a negligible performance increase,
	just like Graphite, depending on your system. Use at your own risk!
  - If you're planning on using v4l2loopback with your own config,
    please read: https://github.com/umlaeute/v4l2loopback/discussions/604

Warning /!\\:
  - Distcc is recommended only if it is properly set up,
    and when you have powerful enough hosts.
  - CCache is recommended only if it is properly set up,
    and only when recompiling the same Kernel multiple times.

Gentoo users:
  It is highly recommended you use 'sys-kernel/installkernel' to automatically
  create the initramfs & update the bootloader config, by respecting your
  system preferences (e.g. initramfs->dracut, bootloader->GRUB).
  https://packages.gentoo.org/packages/sys-kernel/installkernel
"
	exit
fi

# Print variables
if [ $F_PRINT_VARS ]; then
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

# Make sure we're in the right directory
cd "$KERNELDIR"

# Revert and remove any patches first
echo "Reverting and removing pre-existing patches (if any)" &&
for p in *.patch; do
	echo "Reverting patch $p..."
	patch -Rfsp1 -i $p
done
rm *.patch

# Copy Kernel config
if ! [ $F_SKIP_CFG ]; then
	echo "Copying config" &&
	cp "$USRDIR/$CONFIGFILE" "$KERNELDIR/config" &&
	cp config .config ||
	exit
else
	echo "Skipping copying config.."
fi

# Copy Clear Linux patches
if [ $F_CLEARLINUX_PATCHES ]; then
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
		cp "$CLEARDIR/$patch" "$KERNELDIR" || exit
	done
fi

# Copy CPU family opts patches
if [ $F_CPU_OPTS ]; then
	# Check if CPU family optimizations directory exists
	if [ ! -d "$CFODIR" ]; then
		echo "Could not find CPU family optimisations directory."
		exit
	fi

	echo "Copying CPU family optimisation patches"
	cp "$CFODIR/more-ISA-levels-and-uarches-for-kernel-6.1.79+.patch" "$KERNELDIR" || exit
fi

# Copy provided patches
if [ $F_PATCHES ]; then
	echo "Copying provided patches"
	cp $PATCHDIR/*.patch $KERNELDIR || exit
fi

# Copy BORE sched patch
if [ $F_BORE ]; then
	# Extract the major version
	# Example: KVER: 6.11.7, KVER_MAJ: 6.11
	KVER_MAJ="${KVER%.*}"

	echo "Copying BORE patch"
	cp $BOREDIR/patches/stable/linux-$KVER_MAJ-bore/*patch "$KERNELDIR" || exit
fi

echo "Applying Clear Linux and/or user patches (if any)"
for p in *.patch; do
	echo "Applying patch '$p'..." && patch -Np1 -i $p
done

#echo "Setting version..." &&
#scripts/setlocalversion --save-scmversion ||

# make olddefconfig
echo "Running make olddefconfig" && make $JOBS olddefconfig || exit

# make oldconfig & make prepare
echo "Running make oldconfig && make prepare" && make $JOBS oldconfig && make $JOBS prepare || exit

# Backup existing Kernel .config
echo "Copying existing Kernel config to config.last" && cp .config config.last || exit

# make clean
echo "Running make clean" && make $JOBS clean || exit

# make menuconfig
if [ $F_MENUCONFIG ]; then
	make $JOBS menuconfig
	exit
fi

# Skip Kernel build?
if ! [ $F_SKIP_BUILD ]; then
	# Don't use build timestap (slows down cache)
	export KBUILD_BUILD_TIMESTAMP=""

	# Check if we can use ccache
	if [ $F_CCACHE ]; then
		echo "Using ccache..."
		cc="ccache gcc"
	else
		cc="gcc"
	fi

	# Check if we can use distcc
	if [ $F_DISTCC ]; then
		echo "Using distcc..."
		cc="distcc $cc"
	fi

	# Specify which compiler we're using
	echo "Compiler command (CC): $cc"

	# Check if Unsafe Fast Math is enabled
	if [ $F_FASTMATH ]; then
		MATH="-fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math -fno-math-errno -ffinite-math-only -fno-rounding-math -fno-signaling-nans -fcx-limited-range -fexcess-precision=fast"
	else
		MATH=""
	fi

	# Check if Graphite is enabled
	if [ $F_GRAPHITE ]; then
		GRAPHITE="-fgraphite-identity -floop-nest-optimize"
	else
		GRAPHITE=""
	fi

	# Extra optimimization flags:
	# -fivopts:
    #   Perform induction variable optimizations (strength reduction,
    #   induction variable merging and induction variable elimination) on trees.
  	# -fmodulo-sched:
    #   Perform swing modulo scheduling immediately before the first
    #   scheduling pass. This pass looks at innermost loops and reorders
    #   their instructions by overlapping different iterations.
	# -floop-interchange:
	#   Perform loop interchange outside of graphite.
	#   This flag can improve cache performance on loop nest,
	#   and allow further loop optimizations, like vectorization,
	#   to take place.
	OPTS="-fivopts -fmodulo-sched -floop-interchange"

	# Kernel build timer
	build_start=$(date "+%s")
	echo "Started build at $(date --date=@$build_start)"
	echo "Building Kernel Version $(make kernelrelease)"

	# Build Kernel
	make CC="$cc" KCFLAGS="$KCFLAGS $MATH $GRAPHITE $OPTS" $JOBS || exit
	make CC="$cc" $JOBS modules_prepare || exit

	# Kernel build timer
	build_end=$(date "+%s")
	build_diff=$(expr $build_end - $build_start)
	echo "Finished Kernel build at $(date --date=@$build_end)."
	echo "Took $(date -d@$build_diff -u +%H:%M:%S)."

	# Modules + Kernel install timer
	install_start=$(date "+%s")
	echo "Started Modules + Kernel install at $(date --date=@$install_start)"

	# Install modules + Kernel
	# NOTE: it is highly recommended you use "installkernel".
	# https://packages.gentoo.org/packages/sys-kernel/installkernel
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
	if [ $F_V4L2 ]; then
		# Check if V4L2DIR exists
		if [ ! -d "$V4L2DIR" ]; then
			echo "Could not find v4l2loopback directory.";
			exit
		fi

		# V4L2loopback timer
		build_v4l2_start=$(date "+%s")
		echo "Started v4l2loopback build at $(date --date=@$build_v4l2_start)"

		# Compile V4L2loopback
		cd $V4L2DIR
		make $JOBS KERNELRELEASE=$KERNVER || exit
		make KERNELRELEASE=$KERNVER install || exit

		# Reload module dependencies
		depmod -a

		# V4L2loopback timer
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
