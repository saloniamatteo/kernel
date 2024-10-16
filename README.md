# Salonia Matteo's Kernel
This is the Kernel configuration I use on Gentoo Linux
([sys-kernel/gentoo-sources](https://packages.gentoo.org/packages/sys-kernel/gentoo-sources)).

Documentation: https://salonia.it/kernel

## Note
You will find 2 config files in each Kernel directory, `config` and `config.pc`.

- `config` is geared towards a ThinkPad T440p.
- `config.pc` is geared towards my workstation.

See more details here: https://salonia.it/kernel#intro

## Compression
- Kernel compression: `lz4`
- Initramfs:          `lz4`
- Module compression: `none`
- ZSWAP compression:  `zstd`
