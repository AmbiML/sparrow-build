# For debug builds override the hardware memory config (4MiB -> 64MiB);
# this assumes debug builds run in simulation only or the target hardware
# has a large memory config.
CANTRIP_EXTRA_CMAKE_OPTS_DEBUG := -DKernelCustomDTSOverlay="${ROOTDIR}/build/platforms/nexus/overlay-debug.dts"

# seL4 platform identity passed to cargo to bring in platform-specific deps
CONFIG_PLATFORM           := CONFIG_PLAT_SPARROW
