# Salonia Matteo's Kernel
This is the Kernel configuration I use on Gentoo Linux
([sys-kernel/gentoo-sources](https://packages.gentoo.org/packages/sys-kernel/gentoo-sources)).

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

**Note**: There are two config files: the first one, `config`, contains the
Kernel config for my T440p, while the other one, `config.pc`,
contains the Kernel config for my PC, which has an i5-11400 (Rocket Lake).

## Build.sh command-line flags

| Short flag | Long flag      | Explaination                                             |
|------------|----------------|----------------------------------------------------------|
| `-b`       | `--skip-build` | Skip building the Kernel                                 |
| `-c`       | `--skip-cfg`   | Skip copying Kernel configuration                        |
| `-e`       | `--ccache`     | Use `ccache` to speed up compilation (requires `ccache`) |
| `-f`       | `--fastmath`   | Build Kernel with Fast Math [\*]                         |
| `-h`       | `--help`       | Print help dialog and exit                               |
| `-l`       | `--clearl-ps`  | Enable and apply Clear Linux patches [\*]                |
| `-m`       | `--menuconfig` | Run `make menuconfig` in Kernel directory and exit       |
| `-o`       | `--cpu-opts`   | Build Kernel with CPU family optimisations [*]           |
| `-p`       | `--patches`    | Apply user patches (recommended)                         |
| `-v`       | `--v4l2`       | Build v4l2loopback Kernel module                         |

Note: all options marked with `[*]`, when enabled,
should improve the performance of the Kernel at runtime,
at the cost of negligibly longer compilation time,
and/or slightly higher Kernel size.

Note 2: Clear Linux patches are HIGHLY recommended for Intel CPUs.
Results may vary.

Note 3: To use `-e`/`--ccache`, you first need to install `ccache`.
On Gentoo, the package is `dev-util/ccache`.

## Configuration
To configure your Kernel, run the following commands as root:

```bash
# The /usr/src/ directory contains various Kernels
cd /usr/src/

# Clone the repository to usr-kernel, if you don't have it already
# Make sure you have enough permissions.
git clone --recurse-submodules https://github.com/saloniamatteo/kernel usr-kernel
cd usr-kernel

# Select the latest version
# (example: 6.3.4-gentoo for Kernel version 6.3.4)
cd 6.3.4-gentoo
 
# Make sure we can execute the script
chmod +x build.sh

# NOTE: you should modify the build.sh script to
# match your configuration.
# vim build.sh

# Normally, you would run the following to configure
# the kernel, before building it.
# -------------------------------------------
# Flags explained:
# -b: Skip building the Kernel
# -f: Build Kernel with fast math
# -l: Apply Clear Linux patches
# -m: Configure Kernel (make menuconfig)
# -o: Apply CPU family optimisations
# -p: Apply user patches
# -------------------------------------------
# You likely need to add "doas" or "sudo"
# before "./build.sh" to run it
./build.sh -b -f -l -m -o -p

# Make sure you copy the new Kernel config to the directory!
# Note: /usr/src/linux is where the Kernel is stored,
# and config.new is the name of the new config,
# saved in the current directory.
# Make sure to rename if needed!
cp /usr/src/linux/.config config.new

# Build the Kernel.
# -------------------------------------------
# Flags explained:
# -f: Build Kernel with fast math
# -l: Apply Clear Linux patches
# -o: Apply CPU family optimisations
# -p: Apply user patches
# -------------------------------------------
# You likely need to add "doas" or "sudo"
# before "./build.sh" to run it
./build.sh -f -l -o -p
```
