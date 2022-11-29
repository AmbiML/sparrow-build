# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

sim_configs:
	$(RENODE_SIM_GENERATOR_SCRIPT)

clean_sim_configs:
	@rm -rf $(OUT)/renode_configs

# NB: $(CANTRIP_ROOTSERVER_*) is built together with $(CANTRIP_KERNEL_*)

$(OUT)/ext_flash_debug.tar: $(MATCHA_BUNDLE_DEBUG) $(CANTRIP_KERNEL_DEBUG) $(CANTRIP_ROOTSERVER_DEBUG) | $(OUT)/tmp
	ln -sf $(MATCHA_BUNDLE_DEBUG) $(OUT)/tmp/matcha-tock-bundle
	ln -sf $(CANTRIP_KERNEL_DEBUG) $(OUT)/tmp/kernel
	ln -sf $(CANTRIP_ROOTSERVER_DEBUG) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $(OUT)/ext_flash_debug.tar matcha-tock-bundle kernel capdl-loader

$(OUT)/ext_flash_release.tar: $(MATCHA_BUNDLE_RELEASE) $(CANTRIP_KERNEL_RELEASE) $(CANTRIP_ROOTSERVER_RELEASE) | $(OUT)/tmp
	ln -sf $(MATCHA_BUNDLE_RELEASE) $(OUT)/tmp/matcha-tock-bundle
	ln -sf $(CANTRIP_KERNEL_RELEASE) $(OUT)/tmp/kernel
	ln -sf $(CANTRIP_ROOTSERVER_RELEASE) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $(OUT)/ext_flash_release.tar matcha-tock-bundle kernel capdl-loader

# Renode commands to issue before the initial start of a simulation.
# This pauses all cores and then sets cpu0 (SC) & cpu1 (SMC) running.
RENODE_PRESTART_CMDS=pause; cpu0 IsHalted false;
PORT_PRESTART_CMDS:=$(shell $(ROOTDIR)/scripts/generate-renode-port-cmd.sh $(RENODE_PORT))

## Launches an end-to-end build of the Sparrow system and starts Renode
#
# This top-level target triggers the `matcha_tock_release`, `cantrip`, `renode`,
# `multihart_boot_rom`, and `iree` targets to build the entire system and then
# finally starts the Renode simulator.
#
# This is the default target for the build system, and is generally what you
# need for day-to-day work on the software side of Sparrow.
simulate: renode multihart_boot_rom $(OUT)/ext_flash_release.tar iree_model_builtins $(OUT)/ext_builtins_release.cpio
	$(RENODE_CMD) -e "\
    \$$tar = @$(ROOTDIR)/out/ext_flash_release.tar; \
    \$$cpio = @$(ROOTDIR)/out/ext_builtins_release.cpio; \
    $(PORT_PRESTART_CMDS) i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) start"

## Debug version of the `simulate` target
#
# This top-level target does the same job as `simulate`, but instead of
# unhalting the CPUs and starting the system, this alternate target only unhalts
# cpu0, and uses the debug build of TockOS from the `matcha_tock_debug` target.
simulate-debug: renode multihart_boot_rom $(OUT)/ext_flash_debug.tar iree_model_builtins $(OUT)/ext_builtins_debug.cpio
	$(RENODE_CMD) -e "\
    \$$tar = @$(ROOTDIR)/out/ext_flash_debug.tar; \
    \$$cpio = @$(ROOTDIR)/out/ext_builtins_debug.cpio; \
    \$$kernel = @$(CANTRIP_KERNEL_DEBUG); $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) cpu1 CreateSeL4 0xffffffee; start"

## Debug version of the `simulate` target
#
# This top-level target does the same job as `simulate-debug`, but instead of
# unhalting the CPUs and starting the system, this alternate target starts
# renode with no CPUs unhalted, allowing for GDB to be used for early system
# start.
debug-simulation: renode multihart_boot_rom $(OUT)/ext_flash_debug.tar iree_model_builtins $(OUT)/ext_builtins_debug.cpio
	$(RENODE_CMD) -e "\
    \$$tar = @$(ROOTDIR)/out/ext_flash_debug.tar; \
    \$$cpio = @$(ROOTDIR)/out/ext_builtins_debug.cpio; \
    \$$kernel = @$(CANTRIP_KERNEL_DEBUG); $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; start"

# Launches Sparrow with Minisel as the rootserver for low-level testing purposes.
# FIXME(@aappleby) - The Minisel bundle renames "minisel.elf" to "capdl-loader"
# because we don't currently have any way to specify the rootserver app other
# than via filename
$(OUT)/ext_flash_minisel_debug.tar: $(MATCHA_BUNDLE_DEBUG) $(CANTRIP_KERNEL_DEBUG) $(CANTRIP_OUT_DEBUG)/minisel/minisel.elf | $(OUT)/tmp
	ln -sf $(MATCHA_BUNDLE_DEBUG) $(OUT)/tmp/matcha-tock-bundle
	ln -sf $(CANTRIP_KERNEL_DEBUG) $(OUT)/tmp/kernel
	ln -sf $(CANTRIP_OUT_DEBUG)/minisel/minisel.elf $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $(OUT)/ext_flash_minisel_debug.tar matcha-tock-bundle kernel capdl-loader

$(OUT)/ext_flash_minisel_release.tar: $(MATCHA_BUNDLE_RELEASE) $(CANTRIP_KERNEL_RELEASE) $(CANTRIP_OUT_RELEASE)/minisel/minisel.elf | $(OUT)/tmp
	ln -sf $(MATCHA_BUNDLE_RELEASE) $(OUT)/tmp/matcha-tock-bundle
	ln -sf $(CANTRIP_KERNEL_RELEASE) $(OUT)/tmp/kernel
	ln -sf $(CANTRIP_OUT_RELEASE)/minisel/minisel.elf $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $(OUT)/ext_flash_minisel_release.tar matcha-tock-bundle kernel capdl-loader

simulate_minisel: renode multihart_boot_rom $(OUT)/ext_flash_minisel_debug.tar
	$(RENODE_CMD) -e "\$$tar = @$(ROOTDIR)/out/ext_flash_minisel_debug.tar; \$$kernel = @$(CANTRIP_KERNEL_DEBUG); $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) start"

simulate_minisel_release: renode multihart_boot_rom $(OUT)/ext_flash_minisel_release.tar
	$(RENODE_CMD) -e "\$$tar = @$(ROOTDIR)/out/ext_flash_minisel_release.tar; $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) start"

test_sc: renode multihart_boot_rom $(ROOTDIR)/sim/config/sparrow.resc
	$(RENODE_CMD) -e "\$$tar = @$(ROOTDIR)/out/test_sc.tar; i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS); start"

test_mc: renode multihart_boot_rom $(ROOTDIR)/sim/config/sparrow.resc
	$(RENODE_CMD) -e "\$$tar = @$(ROOTDIR)/out/test_mc.tar; i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS); start"

test_vc: renode multihart_boot_rom $(ROOTDIR)/sim/config/sparrow.resc
	$(RENODE_CMD) -e "\$$tar = @$(ROOTDIR)/out/test_vc.tar; i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS); start"

.PHONY:: sim_configs clean_sim_configs simulate simulate-debug debug-simulation
.PHONY:: test_sc test_mc test_vc

include $(ROOTDIR)/build/sim_sel4test.mk
