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

## Build.sh command-line flags

| Short flag | Long flag      | Explaination                                             |
|------------|----------------|----------------------------------------------------------|
| `-b`       | `--skip-build` | Skip building the Kernel                                 |
| `-c`       | `--skip-cfg`   | Skip copying Kernel configuration                        |
| `-d`       | `--modprobed`  | Skip copying modprobed.db to Kernel directory            |
| `-e`       | `--ccache`     | Use `ccache` to speed up compilation (requires `ccache`) |
| `-f`       | `--fastmath`   | Build Kernel with unsafe Fast Math [\*]                  |
| `-F`       | `--fastmath`   | Build Kernel with safe Fast Math [\*]                    |
| `-g`       | `--graphite`   | Build Kernel with Graphite [\*]                          |
| `-h`       | `--help`       | Print help dialog and exit                               |
| `-l`       | `--clearl-ps`  | Enable and apply Clear Linux patches [\*]               |
| `-m`       | `--menuconfig` | Run `make menuconfig` in Kernel directory and exit       |
| `-p`       | `--patches`    | Apply user patches (recommended)                         |

Note: all options marked with `[*]`, when enabled,
may or may not improve the performance of the Kernel at runtime,
at the cost of slightly longer compilation time,
and/or slightly higher Kernel size.

Note 2: Clear Linux patches are HIGHLY recommended for Intel CPUs.
Results may vary.

Note 3: To use `-c`/`--ccache`, you first need to install `ccache`.
On Gentoo, the package is `dev-util/ccache`.

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
# (example: 5.14_p1-pf for Kernel version 5.14 patch 1)
cd 5.14_p1-pf
 
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
cd /usr/src/usr-kernel/5.14_p1-pf

# Run the script to build the Kernel
# Add the -e option if you want to use ccache
# (-c option means skip copying config)
./build.sh -c
```
