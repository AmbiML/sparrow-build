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

sim_configs::
clean_sim_configs::

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

## Launches an end-to-end build of the Sparrow system and starts qemu
#
# This top-level target triggers building the entire system and then starting
# the qemu simulator with the build artifacts.
#
# This is the default target for the build system, and is generally what you
# need for day-to-day work on the software side of Sparrow.
simulate: ${CANTRIP_OUT_RELEASE}/capdl-loader-image ${CANTRIP_OUT_RELEASE}/cantrip.mem | qemu_presence_check
	$(QEMU_CMD) \
	-kernel ${CANTRIP_OUT_RELEASE}/capdl-loader-image \
	--mem-path ${CANTRIP_OUT_RELEASE}/cantrip.mem

$(CANTRIP_OUT_RELEASE)/capdl-loader-image: $(CANTRIP_KERNEL_RELEASE) \
		$(CANTRIP_ROOTSERVER_RELEASE) ${CANTRIP_OUT_RELEASE}/elfloader/elfloader
	${C_PREFIX}objcopy -O binary ${CANTRIP_OUT_RELEASE}/elfloader/elfloader $@

# XXX no dep on system.camkes
$(CANTRIP_OUT_RELEASE)/cantrip.mem:  $(CANTRIP_OUT_RELEASE)/ext_builtins.cpio \
		${CANTRIP_OUT_RELEASE}/kernel/gen_config/kernel/gen_config.h \
    $(ROOTDIR)/build/platforms/rpi3/sim.mk \
    ${CANTRIP_SRC_DIR}/apps/system/platforms/bcm2837/system.camkes
	dd if=/dev/zero of=$@ bs=${MEMORY_SIZE} count=1
	SEL4_PLATFORM=$$(awk '\
		/\<CONFIG_PLAT\>/ { print $$3 } \
	' ${CANTRIP_OUT_RELEASE}/kernel/gen_config/kernel/gen_config.h) && \
	DD_ARGS=$$(awk ' \
        /^#define[ ]+CPIO_SIZE_BYTES/ { print "ibs=" strtonum($$3) / (1024*1024) "M" } \
        /^#define[ ]+CPIO_BASE_ADDR/ { print "obs=1M seek=" strtonum($$3) / (1024*1024) } \
	' $(CANTRIP_SRC_DIR)/apps/system/platforms/$${SEL4_PLATFORM}/platform.camkes) && \
	dd if=$(CANTRIP_OUT_RELEASE)/ext_builtins.cpio of=$@ $${DD_ARGS} conv=sync,nocreat,notrunc

## Debug version of the `simulate` target
simulate-debug: ${CANTRIP_OUT_DEBUG}/cantrip.mem ${CANTRIP_OUT_DEBUG}/capdl-loader-image | qemu_presence_check
	$(QEMU_CMD) -s \
	-kernel ${CANTRIP_OUT_DEBUG}/capdl-loader-image \
	--mem-path ${CANTRIP_OUT_DEBUG}/cantrip.mem

$(CANTRIP_OUT_DEBUG)/capdl-loader-image: $(CANTRIP_KERNEL_DEBUG) $(CANTRIP_ROOTSERVER_DEBUG) ${CANTRIP_OUT_DEBUG}/elfloader/elfloader
	${C_PREFIX}objcopy -O binary ${CANTRIP_OUT_DEBUG}/elfloader/elfloader $@

# XXX no dep on system.camkes
$(CANTRIP_OUT_DEBUG)/cantrip.mem:  $(CANTRIP_OUT_DEBUG)/ext_builtins.cpio ${CANTRIP_OUT_DEBUG}/kernel/gen_config/kernel/gen_config.h
	dd if=/dev/zero of=$@ bs=${MEMORY_SIZE} count=1
	SEL4_PLATFORM=$$(awk '\
		/\<CONFIG_PLAT\>/ { print $$3 } \
	' ${CANTRIP_OUT_DEBUG}/kernel/gen_config/kernel/gen_config.h) && \
	DD_ARGS=$$(awk ' \
        /cpio.cpio_size = / { print "ibs=" strtonum($$3) / (1024*1024) "M" } \
        /cpio.cpio_paddr = / { print "obs=1M seek=" strtonum($$3) / (1024*1024) } \
	' $(CANTRIP_SRC_DIR)/apps/system/platforms/$${SEL4_PLATFORM}/system.camkes) && \
	dd if=$(CANTRIP_OUT_DEBUG)/ext_builtins.cpio of=$@ $${DD_ARGS} conv=sync,nocreat,notrunc

## Debug version of the `simulate` target
#
# This top-level target does the same job as `simulate-debug`, but instead of
# unhalting the CPUs and starting the system, this alternate target starts
# renode with no CPUs unhalted, allowing for GDB to be used for early system
# start.
debug-simulation: ${CANTRIP_OUT_DEBUG}/cantrip.mem ${CANTRIP_OUT_DEBUG}/capdl-loader-image | qemu_presence_check
	$(QEMU_CMD) -s -S \
	-kernel ${CANTRIP_OUT_DEBUG}/capdl-loader-image \
	--mem-path ${CANTRIP_OUT_DEBUG}/cantrip.mem

.PHONY:: sim_configs clean_sim_configs simulate simulate-debug debug-simulation
