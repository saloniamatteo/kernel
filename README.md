# Salonia Matteo's Kernel
This is the Kernel configuration I use on Gentoo Linux
([sys-kernel/pf-sources](https://packages.gentoo.org/packages/sys-kernel/pf-sources)).

For more info, see the links below:
- Italiano: https://saloniamatteo.top/it/kernel.html
- English:  https://saloniamatteo.top/en/kernel.html

## Specificity
This Kernel was configured with the ThinkPad T440p in mind,
removing unnedeed features, such as NUMA, NVIDIA,
AMD support, and targeting an Intel i7-4700MQ.

I recommend you change the processor used, the maximum
GPUs (max. 2 set), the maximum CPU threads (max. 8 set),
the target CPU architecture (Haswell set), and so on.

**Note**: Kernel configuration is set to use Intel-native optimizations
automatically detected by GCC.

## Configuration
To configure your Kernel, run the following commands
as root:

```bash
# The /usr/src/ directory contains various Kernels
cd /usr/src/

# Clone the repository to usr-kernel, if you don't have it already
git clone https://github.com/saloniamatteo/kernel 
cd usr-kernel

# Select the latest version
# (example: 5.14_p1 for Kernel version 5.14 patch 1)
cd 5.14-p1
 
# Make sure we can execute the script
chmod +x build.sh

# NOTE: you should modify the build.sh script to
# match your configuration.
# vim build.sh

# Run the script, without building the Kernel
# This will copy a few files we need (like patches)
# and will apply them; it will also copy modprobed.db.
# If you want to copy the included config, # remove the "-c" option
./build.sh -b -c

# Now, go to the Kernel directory
cd /usr/src/linux

# Run tool to modify config
# this is usually one of menuconfig, xfconfig, qtconfig
# menuconfig will run in your terminal with colors
# Remember to save the configuration!
make menuconfig

# Once you're done, to build the Kernel, run the
# following commands as root:

# Go where your custom directory is
cd /usr/src/usr-kernel/5.14-p1

# Run the script to build the Kernel
# Add the -e option if you want to use ccache
# (-c option means skip copying config)
./build.sh -c
```
