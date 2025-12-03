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
KVER="6.18.0"	# Primary Kernel version
PVER="-gentoo"	# Kernel "patch" version

# Set this variable if your Kernel is not located under /usr/src/
# Default is empty
#KERNELDIR=""

# How many threads to use to build Kernel
# T470p, T440p = -j4
# PC = -j9
# ---
# When using distcc, use the following formula to set up "-jX -lY":
# -jX: 2 * (local + remote cores) + 1
# -lY: Y is the number of local cores
#
# Example: T470p (4 cores) + PC (9 cores)
# -jX: 2 * (4 + 9) + 1 = -j27
# -lY: 4 = -l4
# ---
# You can set any value you like.
#JOBS="-j27 -l4"
JOBS="-j4"

# Name of the Kernel config file under $CUSTDIR/$KERNVER
# Choose between "config", "config.t440p", "config.pc"
# You can provide your own config file by placing it under $CUSTDIR/$KERNVER.
CONFIGFILE="config"

# ======================================================
# Do not modify these unless you know what you're doing.
# Full Kernel version
KERNVER="${KVER}${PVER}"
# Location of included patches
PATCHDIR="$CUSTDIR/tkg-patches"
# Location of BORE sched patch
BOREDIR="$CUSTDIR/bore-scheduler"
# Location of v4l2loopback directory
V4L2DIR="$CUSTDIR/v4l2loopback"
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

# Parse options
# -o: short options
# -l: long options
# -n: program name
# -------------------
# Note that we use "$@" to let each command-line parameter expand to a
# separate word. The quotes around "$@" are essential!
# We need this as the 'eval set --' would nuke the return value of getopt.
OPTS=$(getopt \
	-o 'bcdefghlmprvyz' \
	-l 'skip-build,skip-cfg,distcc,ccache,fastmath,graphite,help,menuconfig,patches,bore,v4l2,flags,vars,preset-configure,preset-build' \
	-- "$@"
)

usage() {
	printf "Usage: $0 [options]

Options:
-b,--skip-build     Do not build the Kernel
-c,--skip-cfg       Do not copy the Kernel config to Kernel directory
-d,--distcc         Use distcc to speed up compilation /!\\
-e,--ccache         Use ccache to speed up compilation /!\\
-f,--fastmath       Build Kernel with Unsafe Fast Math [*]
-g,--graphite       Build Kernel with Graphite [*]
-h,--help           Print this help and exit
-m,--menuconfig     Run 'make menuconfig' in Kernel directory and exit
-p,--patches        Apply patches (recommended) [*]
-r,--bore           Build Kernel with BORE scheduler [*]
-v,--v4l2           Build v4l2loopback Kernel module
-y,--flags          Print flags and exit
-z,--vars           Print variables and exit

Presets:
--preset-configure  Selects the following flags:
                    -m, -p, -r

--preset-build      Selects the following flags:
                    -f, -g, -p, -r

Note:
  - All options marked with '[*]', when enabled, may improve
    Kernel performance, whether it may be CPU, I/O, network, etc.
  - It is highly recommended to build with provided patches,
    as well as the BORE scheduler. Unsafe fast math may or
	may not bring a performance increase, just like Graphite,
	depending on your system. Use at your own risk!
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
}

if [ $? -ne 0 ]; then
	usage >&2
	exit 1
fi

# If no parameters have been provided, print usage & exit
if [[ "$OPTS" = " --" ]]; then
	usage >&2
	exit 1
fi

# Reset the positional parameters to the parsed options
eval set -- "$OPTS"
unset OPTS

F_SKIP_BUILD=0			# Do not build the kernel
F_SKIP_CFG=0			# Do not copy the Kernel config to Kernel directory
F_DISTCC=0				# Use distcc to speed up compilation
F_CCACHE=0				# Use ccache to speed up compilation
F_FASTMATH=0			# Build Kernel with Unsafe Fast Math
F_GRAPHITE=0			# Build Kernel with Graphite
F_PRINT_HELP=0			# Print help and exit
F_MENUCONFIG=0			# Run 'make menuconfig' in Kernel directory and exit
F_PATCHES=0				# Apply provided patches (recommended)
F_BORE=0				# Build Kernel with BORE scheduler
F_V4L2=0				# Build v4l2loopback Kernel module
F_PRINT_VARS=0			# Print flags and exit
F_PRINT_FLAGS=0			# Print variables and exit

# Extract the major version
# Example: KVER: 6.11.7, KVER_MAJ: 6.11
KVER_MAJ="${KVER%.*}"

# Process options
while true; do
	case "$1" in
		'-b' | '--skip-build')
			F_SKIP_BUILD=1
			shift
			continue
			;;
		'-c' | '--skip-cfg')
			F_SKIP_CFG=1
			shift
			continue
			;;
		'-d' | '--distcc')
			F_DISTCC=1
			shift
			continue
			;;
		'-e' | '--ccache')
			F_CCACHE=1
			shift
			continue
			;;
		'-f' | '--fastmath')
			F_FASTMATH=1
			shift
			continue
			;;
		'-g' | '--graphite')
			F_GRAPHITE=1
			shift
			continue
			;;
		'-h' | '--help')
			F_PRINT_HELP=1
			shift
			continue
			;;
		'-m' | '--menuconfig')
			F_MENUCONFIG=1
			shift
			continue
			;;
		'-p' | '--patches')
			F_PATCHES=1
			shift
			continue
			;;
		'-r' | '--bore')
			F_BORE=1
			shift
			continue
			;;
		'-v' | '--v4l2')
			F_V4L2=1
			shift
			continue
			;;
		'-y' | '--flags')
			F_PRINT_FLAGS=1
			shift
			continue
			;;
		'-z' | '--vars')
			F_PRINT_VARS=1
			shift
			continue
			;;
		'--preset-configure')
			F_CLEARLINUX_PATCHES=1
			F_MENUCONFIG=1
			F_PATCHES=1
			F_BORE=1
			shift
			continue
			;;
		'--preset-build')
			F_SKIP_BUILD=0			# Necessary as "-b" is detected (override)
			F_FASTMATH=1
			F_GRAPHITE=1
			F_CLEARLINUX_PATCHES=1
			F_PATCHES=1
			F_BORE=1
			shift
			continue
			;;
		'--')
			shift
			break
			;;
		*)
			echo "Internal error!" >&2
			exit 1
			;;
	esac
done

# Print help
if [ $F_PRINT_HELP = 1 ]; then
	usage
	exit
fi

# Print flags
if [ $F_PRINT_FLAGS = 1 ]; then
	printf "Flags:
F_SKIP_BUILD=$F_SKIP_BUILD
F_SKIP_CFG=$F_SKIP_CFG
F_DISTCC=$F_DISTCC
F_CCACHE=$F_CCACHE
F_FASTMATH=$F_FASTMATH
F_GRAPHITE=$F_GRAPHITE
F_PRINT_HELP=$F_PRINT_HELP
F_MENUCONFIG=$F_MENUCONFIG
F_PATCHES=$F_PATCHES
F_BORE=$F_BORE
F_V4L2=$F_V4L2
F_PRINT_VARS=$F_PRINT_VARS
F_PRINT_FLAGS=$F_PRINT_FLAGS
"

	exit
fi

# Print variables
if [ $F_PRINT_VARS = 1 ]; then
	printf "Variables:
CONFIGFILE=$CONFIGFILE
JOBS=$JOBS
KVER=$KVER
PVER=$PVER
KVER_MAJ=$KVER_MAJ
KERNVER=$KERNVER
CUSTDIR=$CUSTDIR
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
if [ $F_SKIP_CFG = 0 ]; then
	echo "Copying config" &&
	cp "$USRDIR/$CONFIGFILE" "$KERNELDIR/config" &&
	cp config .config ||
	exit
else
	echo "Skipping copying config.."
fi

# Copy Clear Linux patches
if [ $F_PATCHES = 1 ]; then
	# Enable the following patches if you want a more responsive Kernel,
	# ideal for gaming:
	# - 0003-glitched-base.patch
	# - 0003-glitched-eevdf-additions.patch
	# - 0009-prjc.patch
	#
	# Enable "0012-linux-hardened.patch" to build a hardened Kernel.
	# "0013-*" patches shouldn't be needed.
	#
	# Enable "0014-OpenRGB.patch" to add support for the Nuvoton NCT6775 controller
	TKG_PATCHES=(
		"0001-add-sysctl-to-disallow-unprivileged-CLONE_NEWUSER-by.patch"
		# This patch is chosen by the -r/--bore flag.
		#"0001-bore.patch"
		"0002-clear-patches.patch"
		#"0003-glitched-base.patch"
		"0003-glitched-cfs.patch"
		#"0003-glitched-eevdf-additions.patch"
		"0006-add-acs-overrides_iommu.patch"
		#"0009-prjc.patch"
		#"0012-linux-hardened.patch"
		"0012-misc-additions.patch"
		#"0013-fedora-rpm.patch"
		#"0013-fedora-strip-modules.patch"
		#"0013-gentoo-kconfig.patch"
		#"0013-gentoo-print-loaded-firmware.patch"
		#"0013-optimize_harder_O3.patch"
		#"0013-suse-additions.patch"
		#"0014-OpenRGB.patch"
	)

	echo "Copying patches"
	for patch in ${TKG_PATCHES[@]}; do
		echo "Copying $patch"
		cp "$PATCHDIR/linux-tkg-patches/$KVER_MAJ/$patch" "$KERNELDIR" || exit
	done
fi

# Copy BORE sched patch
if [ $F_BORE = 1 ]; then
	echo "Copying BORE patch"
	cp "$PATCHDIR/linux-tkg-patches/$KVER_MAJ/0001-bore.patch" "$KERNELDIR" || exit
fi

echo "Applying patches"
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
if [ $F_MENUCONFIG = 1 ]; then
	make $JOBS menuconfig
	exit
fi

# Skip Kernel build?
if [ $F_SKIP_BUILD = 0 ]; then
	# Don't use build timestap (slows down cache)
	export KBUILD_BUILD_TIMESTAMP=""

	# Check if we can use ccache
	if [ $F_CCACHE = 1 ]; then
		echo "Using ccache..."
		cc="ccache gcc"
	else
		cc="gcc"
	fi

	# Check if we can use distcc
	if [ $F_DISTCC = 1 ]; then
		echo "Using distcc..."
		cc="distcc $cc"
	fi

	# Specify which compiler we're using
	echo "Compiler command (CC): $cc"

	# Check if Unsafe Fast Math is enabled
	if [ $F_FASTMATH = 1 ]; then
		MATH="-fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math -fno-math-errno -ffinite-math-only -fno-rounding-math -fno-signaling-nans -fcx-limited-range -fexcess-precision=fast"
	else
		MATH=""
	fi

	# Check if Graphite is enabled
	if [ $F_GRAPHITE = 1 ]; then
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

	# Get this system's -march & -mtune values
	# This replaces the patches from
	# https://github.com/graysky2/kernel_compiler_patch,
	# removing the need to manually patch the kernel everytime.
	# Avoid using -march=native & -mtune=native, as it WILL
	# lead to incorrect optimizations when using distcc.
	CPU_TARGET=$(gcc -march=native -mtune=native -Q --help=target)
	CPU_MARCH=$(grep -m1 "\-march=" <<<$CPU_TARGET | awk '{print $2}')
	CPU_MTUNE=$(grep -m1 "\-mtune=" <<<$CPU_TARGET | awk '{print $2}')
	CPU_OPTS="-march=${CPU_MARCH} -mtune=${CPU_MTUNE}"

	# Kernel C & C++ build flags
	# CPU_OPTS: -march & -mtune
	# MATH: unsafe fast math
	# GRAPHITE: graphite
	# OPTS: extra optimization flags
	OUR_KCFLAGS=" $CPU_OPTS $MATH $GRAPHITE $OPTS"

	# Kernel build timer
	build_start=$(date "+%s")
	echo "Started build at $(date --date=@$build_start)"
	echo "Building Kernel Version $(make kernelrelease)"
	echo "CPU targets: $CPU_OPTS"

	# Build Kernel
	make CC="$cc" KCFLAGS="$KCFLAGS $OUR_KCFLAGS" KCPPFLAGS="$KCPPFLAGS $OUR_KCFLAGS" $JOBS || exit
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
	if [ $F_V4L2 = 1 ]; then
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
