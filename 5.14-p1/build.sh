#!/bin/sh
CONFIGFILE="config"
KVER="5.14"
PVER="_p1-pf"
KERNVER="${KVER}${PVER}"
USRDIR="/usr/src/usr-kernel/$KVER"
ARCHVER=40
JOBS="-j4"

# Try to set kernel directory to /usr/src/linux;
# If it does not exist, try /usr/src/linux-$KERNVER
if [ -d "/usr/src/linux" ]; then
	KERNELDIR="/usr/src/linux"
else if [ -d "/usr/src/linux-$KERNVER" ]; then
	KERNELDIR="/usr/src/linux-$KERNVER"
else
	echo "Could not find Kernel directory! "
	exit -1
fi
fi

# If argument is "-h" or "--help", print exit codes
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	printf "Exit codes:
-2		Successfully printed help
-1		Could not find Kernel directory
00		Successfully built Kernel
01		Failed to copy config
03		Failed to copy modprobed.db
07		Failed to copy user patches
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

Flags:
-b,--skip-build	Skip building the Kernel
-c,--skip-cfg	Skip copying Kernel configuration
-e,--ccache	Use ccache to speed up compilation
-h,--help	Print this help and exit

Variables:
CONFIGFILE=$CONFIGFILE
KERNELDIR=$KERNELDIR
KVER=$KVER
PVER=$PVER
KERNVER=$KERNVER
USRDIR=$USRDIR
ARCHVER=$ARCHVER
JOBS=$JOBS
"
	exit -2
fi

cd $KERNELDIR

if ! [[ $@ =~ "-c" || $@ =~ "--skip-cfg" ]]; then
	echo "Copying config" &&
	cp $USRDIR/$CONFIGFILE $KERNELDIR/config &&
	cp config .config ||
	exit 1
else
	echo "Skipping copying config.."
fi

echo "Copying modprobed.db" &&
cp $USRDIR/modprobed.db $KERNELDIR ||
exit 3

echo "Copying patches" &&
cp $USRDIR/*.patch $KERNELDIR || exit 7
for p in $(ls | grep "*.patch"); do
	[[ $p = 0*.patch ]] && echo "Applying patch $p..." && patch -Np1 -i $p
done

echo "Setting config values" &&
scripts/config --disable CONFIG_DEBUG_INFO &&
scripts/config --disable CONFIG_CGROUP_BPF &&
scripts/config --disable CONFIG_BPF_LSM &&
scripts/config --disable CONFIG_BPF_PRELOAD &&
scripts/config --disable CONFIG_BPF_LIRC_MODE2 &&
scripts/config --disable CONFIG_BPF_KPROBE_OVERRIDE &&
scripts/config --enable CONFIG_PSI_DEFAULT_DISABLED &&
scripts/config --disable CONFIG_LATENCYTOP &&
scripts/config --disable CONFIG_SCHED_DEBUG &&
scripts/config --disable CONFIG_KVM_WERROR &&
echo "Setting version..." &&
scripts/setlocalversion --save-scmversion ||
exit 8

echo "Running make olddefconfig" &&
make olddefconfig ||
exit 9

echo "Running yes $ARCHVER | make oldconfig && make prepare" &&
yes $ARCHVER | make oldconfig && make prepare ||
exit 10

echo "Running make localmodconfig" &&
make LSMOD="$KERNELDIR/modprobed.db" localmodconfig ||
exit 11

echo "Copying config to config.last" &&
cp .config config.last ||
exit 12

echo "Running make clean" &&
make clean ||
exit 13

if ! [[ $@ =~ "-b" || $@ =~ "--skip-build" ]]; then
	# Check if we can use ccache
	if [[ $@ =~ "-e" || $@ =~ "--ccache" ]]; then
		cc="ccache gcc"
	else
		cc="gcc"
	fi
	
	# Don't use build timestap (slows down cache)
	export KBUILD_BUILD_TIMESTAMP=""

	build_start=$(date "+%s")

	echo "Started build at $(date --date=@$build_start)"
	echo "Building Kernel Version $(make kernelrelease)" &&
	make CC="$cc" $JOBS ||
	exit 14

	make CC="$cc" $JOBS modules_prepare ||
	exit 15

	make CC="$cc" $JOBS modules_install ||
	exit 16

	make CC="$cc" $JOBS install ||
	exit 17

	build_end=$(date "+%s")
	build_diff=$(expr $build_end - $build_start)

	echo "Finished Kernel build at $(date --date=@$build_end)."
	echo "Took $(date -d@$build_diff -u +%H:%M:%S)."
else
	echo "Skipping building Kernel. Exiting..."
fi
