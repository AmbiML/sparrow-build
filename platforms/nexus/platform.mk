include $(ROOTDIR)/build/platforms/nexus/boot_rom.mk
include $(ROOTDIR)/build/platforms/nexus/cantrip.mk
include $(ROOTDIR)/build/platforms/nexus/cantrip_builtins.mk
include $(ROOTDIR)/build/platforms/nexus/kelvin.mk
include $(ROOTDIR)/build/platforms/nexus/opentitan_sw.mk
include $(ROOTDIR)/build/platforms/nexus/opentitan_hw.mk
include $(ROOTDIR)/build/platforms/nexus/renode.mk
include $(ROOTDIR)/build/platforms/nexus/matcha_hw.mk
include $(ROOTDIR)/build/platforms/nexus/tock.mk
include $(ROOTDIR)/build/platforms/nexus/sim.mk
include $(ROOTDIR)/build/platforms/nexus/sim_sel4test.mk

# Driver include files auto-generated from opentitan definitions.

ifeq ($(OPENTITAN_SOURCE),)
$(error "OPENTITAN_SOURCE not set. Did build/platforms/nexus/setup.sh get sourced?")
endif

ifeq ($(OPENTITAN_GEN_DIR),)
$(error "OPENTITAN_GEN_DIR not set. Did build/platforms/nexus/setup.sh get sourced?")
endif

$(OPENTITAN_GEN_DIR):
	mkdir -p $(OPENTITAN_GEN_DIR)

TIMER_IP_DIR=$(OPENTITAN_SOURCE)/hw/ip/rv_timer
TIMER_NINJA=$(TIMER_IP_DIR)/util/reg_timer.py
TIMER_TEMPLATE=$(TIMER_IP_DIR)/data/rv_timer.hjson.tpl

TIMER_HEADER=$(OPENTITAN_GEN_DIR)/timer.h

# NB: TIMER_HJSON is set in platforms/nexus/setup.sh.
$(TIMER_HJSON): $(TIMER_NINJA) $(TIMER_TEMPLATE) | $(OPENTITAN_GEN_DIR)
	$(TIMER_NINJA) -s 2 -t 1 $(TIMER_TEMPLATE) > $(TIMER_HJSON)

$(TIMER_HEADER): $(REGTOOL) $(TIMER_HJSON)
	$(REGTOOL) -D -o $@ $(TIMER_HJSON)

# Matcha hw config #defines generated from RTL

TOP_MATCHA_DIR=${CANTRIP_OUT_DIR}/top_matcha
TOP_MATCHA_MEMORY_HEADER=$(TOP_MATCHA_DIR)/sw/autogen/top_matcha_memory.h
TOP_MATCHA_IRQ_HEADER=$(TOP_MATCHA_DIR)/sw/autogen/top_matcha_smc_irq.h
# NB: could depend on the templates instead
TOPGEN_MATCHA=${ROOTDIR}/hw/matcha/util/topgen_matcha.py

${TOP_MATCHA_DIR}:
	mkdir -p $(TOP_MATCHA_DIR)

# NB: no way to generate just the files we need
$(TOP_MATCHA_IRQ_HEADER): $(TOPGEN_MATCHA) ${TOP_MATCHA_DIR} $(TOP_MATCHA_HJSON)
	PYTHONPATH=${OPENTITAN_SOURCE}/util/ ${TOPGEN_MATCHA} -t ${TOP_MATCHA_HJSON} -o ${TOP_MATCHA_DIR}/ --top-only
$(TOP_MATCHA_MEMORY_HEADER): $(TOPGEN_MATCHA) ${TOP_MATCHA_DIR} $(TOP_MATCHA_HJSON)
	PYTHONPATH=${OPENTITAN_SOURCE}/util/ ${TOPGEN_MATCHA} -t ${TOP_MATCHA_HJSON} -o ${TOP_MATCHA_DIR}/ --top-only

# Targets to install the symlink to opentitan headers for each build

cantrip-build-debug-prepare:: | $(CANTRIP_OUT_DEBUG)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(CANTRIP_OUT_DEBUG)/

cantrip-build-release-prepare:: | $(CANTRIP_OUT_RELEASE)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(CANTRIP_OUT_RELEASE)/

sel4test-build-debug-prepare:: | $(SEL4TEST_OUT_DEBUG)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_OUT_DEBUG)/

sel4test-build-release-prepare:: | $(SEL4TEST_OUT_RELEASE)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_OUT_RELEASE)/

sel4test-build-wrapper-release-prepare:: | $(SEL4TEST_WRAPPER_OUT_RELEASE)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_WRAPPER_OUT_RELEASE)/

sel4test-build-wrapper-debug-prepare:: | $(SEL4TEST_WRAPPER_OUT_DEBUG)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_WRAPPER_OUT_DEBUG)/

cantrip-gen-headers:: $(TIMER_HEADER) $(TOP_MATCHA_IRQ_HEADER) $(TOP_MATCHA_MEMORY_HEADER)

cantrip-clean-headers::
	rm -f $(TIMER_HJSON)
	rm -f $(TIMER_HEADER)
	rm -f $(TOP_MATCHA_IRQ_HEADER) $(TOP_MATCHA_MEMORY_HEADER)
