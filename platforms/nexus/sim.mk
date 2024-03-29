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

# NB: keep tarballs in CANTRIP_OUT_DIR to avoid sparrow/nexus collisions
EXT_FLASH_DEBUG=$(CANTRIP_OUT_DEBUG)/ext_flash.tar
EXT_FLASH_RELEASE=$(CANTRIP_OUT_RELEASE)/ext_flash.tar

TMP_DEBUG=$(CANTRIP_OUT_DEBUG)/tmp
TMP_RELEASE=$(CANTRIP_OUT_RELEASE)/tmp

sim_configs:
	$(RENODE_SIM_GENERATOR_SCRIPT)

clean_sim_configs:
	@rm -rf $(OUT)/renode_configs

$(TMP_DEBUG):
	mkdir $(TMP_DEBUG)
$(TMP_RELEASE):
	mkdir $(TMP_RELEASE)

# NB: $(CANTRIP_ROOTSERVER_*) is built together with $(CANTRIP_KERNEL_*)

$(EXT_FLASH_DEBUG): $(MATCHA_BUNDLE_DEBUG) $(CANTRIP_KERNEL_DEBUG) $(CANTRIP_ROOTSERVER_DEBUG) | $(TMP_DEBUG)
	cp -f $(MATCHA_BUNDLE_DEBUG) $(TMP_DEBUG)/matcha-tock-bundle
	${C_PREFIX}strip $(TMP_DEBUG)/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(TMP_DEBUG)/matcha-tock-bundle $(TMP_DEBUG)/matcha-tock-bundle.bin
	ln -sf $(CANTRIP_KERNEL_DEBUG) $(TMP_DEBUG)/kernel
	ln -sf $(CANTRIP_ROOTSERVER_DEBUG) $(TMP_DEBUG)/capdl-loader
	tar -C $(TMP_DEBUG) -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader
ext_flash_debug: $(EXT_FLASH_DEBUG)

$(EXT_FLASH_RELEASE): $(MATCHA_BUNDLE_RELEASE) $(CANTRIP_KERNEL_RELEASE) $(CANTRIP_ROOTSERVER_RELEASE) | $(TMP_RELEASE)
	cp -f $(MATCHA_BUNDLE_RELEASE) $(TMP_RELEASE)/matcha-tock-bundle
	${C_PREFIX}strip $(TMP_RELEASE)/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(TMP_RELEASE)/matcha-tock-bundle $(TMP_RELEASE)/matcha-tock-bundle.bin
	ln -sf $(CANTRIP_KERNEL_RELEASE) $(TMP_RELEASE)/kernel
	ln -sf $(CANTRIP_ROOTSERVER_RELEASE) $(TMP_RELEASE)/capdl-loader
	tar -C $(TMP_RELEASE) -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader

# NB: Package the builtins bundle so it can be written to a carve out in
#     in SMC memory; this is temporary until the SEC supports returning
#     the builtins from flash.
ext_flash_release: $(EXT_FLASH_RELEASE) $(EXT_BUILTINS_RELEASE) | $(TMP_RELEASE)
	ln -sf $(EXT_BUILTINS_RELEASE) $(TMP_RELEASE)/cantrip-builtins
	tar -C $(TMP_RELEASE) -rvhf $(EXT_FLASH_RELEASE) cantrip-builtins

# Dredge the platform configuration for the physical address where the
# cpio archive is expected.
# NB: #define must be at the start of the line so any commented out
#    copies are skipped
CPIO_LOAD_ADDRESS=$(shell awk '/^#define[ \t]+CPIO_BASE_ADDR/ { print $$3 }' \
    $(CANTRIP_SRC_DIR)/apps/system/platforms/nexus/platform.camkes)

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
simulate: renode multihart_boot_rom ext_flash_release kelvin_hello_world cantrip-builtins-release
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/nexus.repl; \
    \$$tar = @$(EXT_FLASH_RELEASE); \
    \$$cpio = @$(EXT_BUILTINS_RELEASE); \
    \$$cpio_load_address = ${CPIO_LOAD_ADDRESS}; \
    \$$kernel = @$(CANTRIP_KERNEL_RELEASE); \
    $(PORT_PRESTART_CMDS) i @sim/config/sparrow.resc; \
        $(RENODE_PRESTART_CMDS) start"

## Debug version of the `simulate` target
#
# This top-level target does the same job as `simulate`, but instead of
# unhalting the CPUs and starting the system, this alternate target only unhalts
# cpu0, and uses the debug build of TockOS from the `matcha_tock_debug` target.
#
# NB: requires editing of platform.camkes for alternate cpio_load_address
simulate-debug: renode multihart_boot_rom ext_flash_debug iree_model_builtins cantrip-builtins-debug
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/nexus-debug.repl; \
    \$$tar = @$(EXT_FLASH_DEBUG); \
    \$$cpio = @$(EXT_BUILTINS_DEBUG); \
    \$$cpio_load_address = ${CPIO_LOAD_ADDRESS}; \
    \$$kernel = @$(CANTRIP_KERNEL_DEBUG); \
    $(PORT_PRESTART_CMDS) i @sim/config/sparrow.resc; \
        $(RENODE_PRESTART_CMDS) cpu1 CreateSeL4 0xffffffee; start"

## Debug version of the `simulate` target
#
# This top-level target does the same job as `simulate-debug`, but instead of
# unhalting the CPUs and starting the system, this alternate target starts
# renode with no CPUs unhalted, allowing for GDB to be used for early system
# start.
#
# NB: requires editing of platform.camkes for alternate cpio_load_address
debug-simulation: renode multihart_boot_rom ext_flash_debug iree_model_builtins cantrip-builtins-debug
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/nexus-debug.repl; \
    \$$tar = @$(EXT_FLASH_DEBUG); \
    \$$cpio = @$(EXT_BUILTINS_DEBUG); \
    \$$cpio_load_address = ${CPIO_LOAD_ADDRESS}; \
    \$$kernel = @$(CANTRIP_KERNEL_DEBUG); \
    $(PORT_PRESTART_CMDS) i @sim/config/sparrow.resc; start"

EXT_FLASH_MINISEL_DEBUG=$(CANTRIP_OUT_DEBUG)/ext_flash_minisel.tar
EXT_FLASH_MINISEL_RELEASE=$(CANTRIP_OUT_RELEASE)/ext_flash_minisel.tar

# Launches Sparrow with Minisel as the rootserver for low-level testing purposes.
# NB: the minisel bundle renames "minisel.elf" to "capdl-loader"
# because we don't currently have any way to specify the rootserver app other
# than via filename
# TODO(sleffler): the rootserver is built as a byproduct of building the kernel
$(EXT_FLASH_MINISEL_DEBUG): $(MATCHA_BUNDLE_DEBUG) $(CANTRIP_KERNEL_DEBUG) $(CANTRIP_OUT_DEBUG)/minisel/minisel.elf | $(TMP_DEBUG)
	cp -f $(MATCHA_BUNDLE_DEBUG) $(TMP_DEBUG)/matcha-tock-bundle
	${C_PREFIX}strip $(TMP_DEBUG)/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(TMP_DEBUG)/matcha-tock-bundle $(TMP_DEBUG)/matcha-tock-bundle.bin
	ln -sf $(CANTRIP_KERNEL_DEBUG) $(TMP_DEBUG)/kernel
	ln -sf $(CANTRIP_OUT_DEBUG)/minisel/minisel.elf $(TMP_DEBUG)/capdl-loader
	tar -C $(TMP_DEBUG) -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader
ext_flash_minisel_debug: $(EXT_FLASH_MINISEL_DEBUG)

# TODO(sleffler): the rootserver is built as a byproduct of building the kernel
$(EXT_FLASH_MINISEL_RELEASE): $(MATCHA_BUNDLE_RELEASE) $(CANTRIP_KERNEL_RELEASE) $(CANTRIP_OUT_RELEASE)/minisel/minisel.elf | $(TMP_RELEASE)
	cp -f $(MATCHA_BUNDLE_RELEASE) $(TMP_RELEASE)/matcha-tock-bundle
	${C_PREFIX}strip $(TMP_RELEASE)/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(TMP_RELEASE)/matcha-tock-bundle $(TMP_RELEASE)/matcha-tock-bundle.bin
	ln -sf $(CANTRIP_KERNEL_RELEASE) $(TMP_RELEASE)/kernel
	ln -sf $(CANTRIP_OUT_RELEASE)/minisel/minisel.elf $(TMP_RELEASE)/capdl-loader
	tar -C $(TMP_RELEASE) -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader
ext_flash_minisel_release: $(EXT_FLASH_MINISEL_RELEASE)

simulate_minisel: renode multihart_boot_rom ext_flash_minisel_debug
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/nexus-debug.repl; \
    \$$tar = @$(EXT_FLASH_MINISEL_DEBUG); \
    \$$kernel = @$(CANTRIP_KERNEL_DEBUG); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) i @sim/config/sparrow.resc; \
        $(RENODE_PRESTART_CMDS) start"

simulate_minisel_release: renode multihart_boot_rom ext_flash_minisel_release
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/nexus.repl; \
    \$$tar = @$(EXT_FLASH_MINISEL_RELEASE); \
    \$$kernel = @$(CANTRIP_KERNEL_RELEASE); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) i @sim/config/sparrow.resc; \
        $(RENODE_PRESTART_CMDS) start"

.PHONY:: sim_configs clean_sim_configs simulate simulate-debug debug-simulation
