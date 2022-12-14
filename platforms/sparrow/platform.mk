include $(ROOTDIR)/build/platforms/sparrow/cantrip.mk
include $(ROOTDIR)/build/platforms/sparrow/cantrip_builtins.mk
include $(ROOTDIR)/build/platforms/sparrow/opentitan_sw.mk
include $(ROOTDIR)/build/platforms/sparrow/opentitan_hw.mk
include $(ROOTDIR)/build/platforms/sparrow/matcha_hw.mk
include $(ROOTDIR)/build/platforms/sparrow/springbok.mk
include $(ROOTDIR)/build/platforms/sparrow/systemc.mk
include $(ROOTDIR)/build/platforms/sparrow/springbok_systemc.mk
include $(ROOTDIR)/build/platforms/sparrow/sim.mk
include $(ROOTDIR)/build/platforms/sparrow/sim_sel4test.mk

# Driver include files auto-generated from opentitan definitions.

OPENTITAN_SOURCE=$(ROOTDIR)/hw/opentitan-upstream
REGTOOL=$(OPENTITAN_SOURCE)/util/regtool.py

OPENTITAN_GEN_DIR=$(CANTRIP_OUT_DIR)/opentitan-gen/include/opentitan
$(OPENTITAN_GEN_DIR):
	mkdir -p $(OPENTITAN_GEN_DIR)

TIMER_IP_DIR=$(OPENTITAN_SOURCE)/hw/ip/rv_timer
TIMER_JINJA=$(TIMER_IP_DIR)/util/reg_timer.py
TIMER_TEMPLATE=$(TIMER_IP_DIR)/data/rv_timer.hjson.tpl

TIMER_HEADER=$(OPENTITAN_GEN_DIR)/timer.h
TIMER_HJSON=$(OPENTITAN_GEN_DIR)/rv_timer.hjson

UART_IP_DIR=$(OPENTITAN_SOURCE)/hw/ip/uart

UART_HEADER=$(OPENTITAN_GEN_DIR)/uart.h
UART_HJSON=$(UART_IP_DIR)/data/uart.hjson

$(TIMER_HJSON): $(TIMER_JINJA) $(TIMER_TEMPLATE) | $(OPENTITAN_GEN_DIR)
	$(TIMER_JINJA) -s 2 -t 1 $(TIMER_TEMPLATE) > $(TIMER_HJSON)

$(TIMER_HEADER): $(REGTOOL) $(TIMER_HJSON)
	$(REGTOOL) -D -o $@ $(TIMER_HJSON)

$(UART_HEADER): $(REGTOOL) $(UART_HJSON) | $(OPENTITAN_GEN)
	$(REGTOOL) -D -o $@ $(UART_HJSON)

# Targets to install the symlink to opentitan headers for each build

cantrip-build-debug-prepare:: | $(CANTRIP_OUT_DEBUG)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(CANTRIP_OUT_DEBUG)/

cantrip-build-release-prepare:: | $(CANTRIP_OUT_RELEASE)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(CANTRIP_OUT_RELEASE)/

sel4test-build-debug-prepare:: | $(SEL4TEST_OUT_DEBUG)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_OUT_DEBUG)/

sel4test-build-release-prepare:: | $(SEL4TEST_OUT_RELEASE)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_OUT_RELEASE)/

sel4test-build-wrapper-prepare:: | $(SEL4TEST_WRAPPER_OUT_RELEASE)
	ln -sf $(CANTRIP_OUT_DIR)/opentitan-gen $(SEL4TEST_WRAPPER_OUT_RELEASE)/

cantrip-gen-headers:: $(TIMER_HEADER) $(UART_HEADER)

cantrip-clean-headers::
	rm -f $(TIMER_HJSON)
	rm -f $(TIMER_HEADER)
	rm -f $(UART_HEADER)
