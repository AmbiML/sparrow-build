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

# Location of pre-loaded memory image for qemu
QEMU_MEM_DEBUG=$(CANTRIP_OUT_DEBUG)/cantrip.mem
QEMU_MEM_RELEASE=$(CANTRIP_OUT_RELEASE)/cantrip.mem

# Location of capdl-loader setup for qemu
QEMU_CAPDL_LOADER_DEBUG=$(CANTRIP_OUT_DEBUG)/capdl-loader-image
QEMU_CAPDL_LOADER_RELEASE=$(CANTRIP_OUT_RELEASE)/capdl-loader-image

# Dredge the platform configuration for the cpio archive splat into
# the $QEMU_MEM_* memory image.
# NB: #define must be at the start of the line so any commented out
#    copies are skipped
CPIO_SIZE=$(shell awk '\
				/^#define[ \t]+CPIO_SIZE_BYTES/ { print strtonum($$3) / (1024*1024) "M" } \
    ' $(CANTRIP_SRC_DIR)/apps/system/platforms/bcm2837/platform.camkes)
CPIO_SEEK=$(shell awk '\
				/^#define[ \t]+CPIO_BASE_ADDR/ { print strtonum($$3) / (1024*1024) } \
		' $(CANTRIP_SRC_DIR)/apps/system/platforms/bcm2837/platform.camkes)

# qemu fixes the memory size according to the machine type. If you use
# other than the default you also need to adjust CPIO_BASE_ADDR in the
# platform.camkes.
MEMORY_SIZE=1G      # raspi3b
QEMU_MACHINE=raspi3b
#MEMORY_SIZE=512M    # raspi3ap
#QEMU_MACHINE=raspi3ap

QEMU := qemu-system-aarch64
QEMU_CMD := ${QEMU} -machine ${QEMU_MACHINE} -nographic -serial null \
	-serial mon:stdio -m size=${MEMORY_SIZE}

## Checks for qemu presence
#
# This target is used as a dependency for other targets that use the qemu
# simulator. This target should not be called by the end user, but used as
# an order-only dependency by other targets.
# XXX fill me in
qemu_presence_check:
	@${QEMU} --version >/dev/null

sim_configs::
clean_sim_configs::

## Launches an end-to-end build of the Sparrow system and starts qemu
#
# This top-level target triggers building the entire system and then starts
# the qemu simulator with the build artifacts.
#
# This is the default target for the build system, and is generally what you
# need for day-to-day work on the software side of Sparrow.
simulate: qemu-capdl-loader-release qemu-mem-release | qemu_presence_check
	$(QEMU_CMD) -kernel ${QEMU_CAPDL_LOADER_RELEASE} --mem-path ${QEMU_MEM_RELEASE}

$(QEMU_CAPDL_LOADER_RELEASE): $(CANTRIP_KERNEL_RELEASE) \
		$(CANTRIP_ROOTSERVER_RELEASE) ${CANTRIP_OUT_RELEASE}/elfloader/elfloader
	${C_PREFIX}objcopy -O binary ${CANTRIP_OUT_RELEASE}/elfloader/elfloader $@
qemu-capdl-loader-release: ${QEMU_CAPDL_LOADER_RELEASE}

$(QEMU_MEM_RELEASE): cantrip-builtins-release \
		${CANTRIP_OUT_RELEASE}/kernel/gen_config/kernel/gen_config.h \
    $(ROOTDIR)/build/platforms/rpi3/sim.mk \
    ${CANTRIP_SRC_DIR}/apps/system/platforms/bcm2837/system.camkes
	dd if=/dev/zero of=$@ bs=${MEMORY_SIZE} count=1
	dd if=$(EXT_BUILTINS_RELEASE) of=$@ \
			ibs=${CPIO_SIZE} obs=1M seek=${CPIO_SEEK} conv=sync,nocreat,notrunc
qemu-mem-release: $(QEMU_MEM_RELEASE)

## Debug version of the `simulate` target
simulate-debug: qemu-capdl-loader-debug qemu-mem-debug | qemu_presence_check
	$(QEMU_CMD) -s -kernel ${QEMU_CAPDL_LOADER_DEBUG} --mem-path ${QEMU_MEM_DEBUG}

$(QEMU_CAPDL_LOADER_DEBUG): $(CANTRIP_KERNEL_DEBUG) \
		$(CANTRIP_ROOTSERVER_DEBUG) ${CANTRIP_OUT_DEBUG}/elfloader/elfloader
	${C_PREFIX}objcopy -O binary ${CANTRIP_OUT_DEBUG}/elfloader/elfloader $@
qemu-capdl-loader-debug: ${QEMU_CAPDL_LOADER_RELEASE}

$(QEMU_MEM_DEBUG): cantrip-builtins-debug \
    ${CANTRIP_OUT_DEBUG}/kernel/gen_config/kernel/gen_config.h \
    $(ROOTDIR)/build/platforms/rpi3/sim.mk \
    ${CANTRIP_SRC_DIR}/apps/system/platforms/bcm2837/system.camkes
	dd if=/dev/zero of=$@ bs=${MEMORY_SIZE} count=1
	dd if=$(EXT_BUILTINS_DEBUG) of=$@ \
			ibs=${CPIO_SIZE} obs=1M seek=${CPIO_SEEK} conv=sync,nocreat,notrunc
qemu-mem-debug: $(QEMU_MEM_DEBUG)

## Debug version of the `simulate` target
#
# This top-level target does the same job as `simulate-debug`, but instead of
# unhalting the CPU and starting the system, this alternate target
# allows for GDB to be used for early system debugging.
debug-simulation: qemu-capdl-loader-debug qemu-mem-debug | qemu_presence_check
	$(QEMU_CMD) -s -S -kernel ${QEMU_CAPDL_LOADER_DEBUG} --mem-path ${QEMU_MEM_DEBUG}

.PHONY:: sim_configs clean_sim_configs simulate simulate-debug debug-simulation
