# seL4 maps platform rpi3 to bcm2837, but this can be either 32- or 64-bit
# and defaults to 32-bit; override by forcing aarch64
CANTRIP_EXTRA_CMAKE_OPTS     := -DAARCH64=1
CANTRIP_EXTRA_CMAKE_OPTS_DEBUG     := ${CANTRIP_EXTRA_CMAKE_OPTS}
CANTRIP_EXTRA_CMAKE_OPTS_RELEASE   := ${CANTRIP_EXTRA_CMAKE_OPTS}

# seL4 platform identity passed to cargo to bring in platform-specific deps
# NB: the kcargo shell function searchs for CONFIG_PLATFORM
CONFIG_PLATFORM                    := CONFIG_PLAT_BCM2837
CANTRIP_GLOBAL_FEATURES_RELEASE    := ${CONFIG_PLATFORM}
CANTRIP_GLOBAL_FEATURES_DEBUG      := ${CANTRIP_GLOBAL_FEATURES_RELEASE}
