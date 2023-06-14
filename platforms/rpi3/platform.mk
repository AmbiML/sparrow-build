# Platform-specific requirements handled by "m prereqs"
CANTRIP_PLATFORM_PYTHON_DEPS=
CANTRIP_PLATFORM_APT_DEPS=

include $(ROOTDIR)/build/platforms/rpi3/cantrip.mk
include $(ROOTDIR)/build/platforms/rpi3/cantrip_builtins.mk
include $(ROOTDIR)/build/platforms/rpi3/sim.mk
include $(ROOTDIR)/build/platforms/rpi3/sim_sel4test.mk

cantrip-build-release-prepare:: | $(CANTRIP_OUT_RELEASE)
cantrip-build-debug-prepare:: | $(CANTRIP_OUT_DEBUG)
sel4test-build-debug-prepare:: | $(SEL4TEST_OUT_DEBUG)
sel4test-build-release-prepare:: | $(SEL4TEST_OUT_RELEASE)
sel4test-build-wrapper-debug-prepare:: | $(SEL4TEST_WRAPPER_OUT_DEBUG)
sel4test-build-wrapper-release-prepare:: | $(SEL4TEST_WRAPPER_OUT_RELEASE)
cantrip-gen-headers::
cantrip-clean-headers::
