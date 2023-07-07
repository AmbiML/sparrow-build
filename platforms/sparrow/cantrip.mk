# For debug builds override the hardware memory config (4MiB -> 64MiB);
# this assumes debug builds run in simulation only or the target hardware
# has a large memory config.
CANTRIP_EXTRA_CMAKE_OPTS_DEBUG := -DKernelCustomDTSOverlay="${ROOTDIR}/build/platforms/sparrow/overlay-debug.dts"

# NB: seL4 platform identity is passed to cargo to bring in platform-specific deps
# NB: the kcargo shell function searchs for CONFIG_PLATFORM
CONFIG_PLATFORM                    := CONFIG_PLAT_SPARROW
CANTRIP_GLOBAL_FEATURES_RELEASE    := ${CONFIG_PLATFORM}
CANTRIP_GLOBAL_FEATURES_DEBUG      := ${CANTRIP_GLOBAL_FEATURES_RELEASE}
