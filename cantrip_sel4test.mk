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

# Location of sel4test sources and binary output files
SEL4TEST_SRC_DIR  := $(ROOTDIR)/cantrip/projects/sel4test
SEL4TEST_OUT_DIR := $(OUT)/sel4test/$(PLATFORM)
SEL4TEST_OUT_DEBUG := $(SEL4TEST_OUT_DIR)/debug
SEL4TEST_KERNEL_DEBUG := $(SEL4TEST_OUT_DEBUG)/kernel/kernel.elf
SEL4TEST_ROOTSERVER_DEBUG := $(SEL4TEST_OUT_DEBUG)/apps/sel4test-driver/sel4test-driver

# NB: enables MCS for all runs; might want to run both w/ & w/o MCS
# NB: enables PRINTING for all runs; user space doesn't seem to setup the
#   console properly so we need seL4_DebugPutChar to display test results.
SEL4TEST_CMAKE_ARGS := \
	-G Ninja \
	-DCROSS_COMPILER_PREFIX=$(C_PREFIX) \
	-DSIMULATION=TRUE \
	-DPLATFORM=${PLATFORM} \
	-DKernelPrinting=1 \
	-DMCS=ON \
	$(SEL4TEST_SRC_DIR)

# NB: no Rust code included, sel4test is pure C
SEL4TEST_SOURCES := $(shell find \
	$(SEL4TEST_SRC_DIR) \
	${SEL4TEST_SRC_DIR}/../sel4runtime \
	${SEL4TEST_SRC_DIR}/../seL4_libs \
	${SEL4TEST_SRC_DIR}/../musllibc \
	${SEL4TEST_SRC_DIR}/../util_libs \
	\( -name \*.c -or -name \*.h -or -name \*.cpp \) -type f)

sel4test-gen-headers: cantrip-gen-headers

$(SEL4TEST_OUT_DEBUG):
	mkdir -p $(SEL4TEST_OUT_DEBUG)

# Generates seltest debug build.ninja
${SEL4TEST_OUT_DEBUG}/build.ninja: ${SEL4TEST_SOURCES} sel4test-gen-headers \
		sel4test-build-debug-prepare | ${SEL4TEST_OUT_DEBUG}
	cmake -B $(SEL4TEST_OUT_DEBUG) \
		-DSEL4_CACHE_DIR=$(CACHE)/sel4test-debug \
		-DRELEASE=OFF \
		${CANTRIP_EXTRA_CMAKE_OPTS_DEBUG} \
        ${SEL4TEST_CMAKE_ARGS}

# Generates sel4test debug kernel
$(SEL4TEST_KERNEL_DEBUG): ${SEL4TEST_OUT_DEBUG}/build.ninja
	ninja -C $(SEL4TEST_OUT_DEBUG) kernel.elf

# Generates sel4test debug rootserver, requries kernel
$(SEL4TEST_ROOTSERVER_DEBUG): ${SEL4TEST_KERNEL_DEBUG} | rust_presence_check
	SEL4_DIR=$(SEL4_KERNEL_DIR) \
	SEL4_OUT_DIR=$(SEL4TEST_OUT_DEBUG)/kernel \
	    ninja -C $(SEL4TEST_OUT_DEBUG)

## Generates all sel4test debug build artifacts
sel4test-bundle-debug: $(SEL4TEST_ROOTSERVER_DEBUG)

## Generates both sel4test & sel4test+wrapper build artifacts
# NB: shorthand for testing (sim targets depend on explicit pathnames)
sel4test-bundles: sel4test-bundle-debug
sel4test-bundles: sel4test-wrapper-bundle-debug

## Cleans all sel4test artifacts
sel4test-clean:
	rm -rf $(OUT)/sel4test
	rm -rf $(OUT)/sel4test-wrapper


# sel4test with C wrappers around the sel4-sys (Rust) crate. This reuses
# sel4test build machinery whenever possible.

SEL4TEST_WRAPPER_LIBRARY_DIR := $(SEL4TEST_SRC_DIR)/integrations/sel4-sys-wrapper
SEL4TEST_WRAPPER_OUT_DIR := $(OUT)/sel4test-wrapper/$(PLATFORM)
SEL4TEST_WRAPPER_OUT_DEBUG := $(SEL4TEST_WRAPPER_OUT_DIR)/debug
SEL4TEST_WRAPPER_ROOTSERVER_DEBUG := $(SEL4TEST_WRAPPER_OUT_DEBUG)/apps/sel4test-driver/sel4test-driver

SEL4TEST_WRAPPER_CMAKE_ARGS := \
	-DLibSel4FunctionAttributes=public \
	-DLibSel4ExternalLibrary=$(SEL4TEST_WRAPPER_LIBRARY_DIR) \
	-DRustTarget=${RUST_TARGET} \
	-DRustCFlags="" \
	-DRustVersion=${CANTRIP_RUST_VERSION} \
    ${SEL4TEST_CMAKE_ARGS}

$(SEL4TEST_WRAPPER_OUT_DEBUG):
	mkdir -p $(SEL4TEST_WRAPPER_OUT_DEBUG)

# seltest-wrapper configuration & build.ninja generation
# NB: use a release build of the user-space code to workaround memory
#   exhuastion; the kernel is still built debug to get any platform-specific
#   configuration (e.g. on sparrow the debug memory config).
${SEL4TEST_WRAPPER_OUT_DEBUG}/build.ninja: ${SEL4TEST_SOURCES} \
		sel4test-gen-headers sel4test-build-wrapper-debug-prepare | ${SEL4TEST_WRAPPER_OUT_DEBUG}
	cmake -B $(SEL4TEST_WRAPPER_OUT_DEBUG) \
		-DSEL4_CACHE_DIR=$(CACHE)/sel4test-wrapper-debug \
		-DRELEASE=ON \
		${CANTRIP_EXTRA_CMAKE_OPTS_DEBUG} \
        ${SEL4TEST_WRAPPER_CMAKE_ARGS}

# sel4test-wrapper rootserver, requires kernel
$(SEL4TEST_WRAPPER_ROOTSERVER_DEBUG): ${SEL4TEST_WRAPPER_OUT_DEBUG}/build.ninja \
		${SEL4TEST_KERNEL_DEBUG} | rust_presence_check
	SEL4_DIR=$(SEL4_KERNEL_DIR) \
	SEL4_OUT_DIR=$(SEL4TEST_OUT_DEBUG)/kernel \
	    ninja -C $(SEL4TEST_WRAPPER_OUT_DEBUG)

## Generates sel4test build artifacts setup for debug
sel4test-wrapper-bundle-debug: $(SEL4TEST_WRAPPER_ROOTSERVER_DEBUG)

.PHONY:: sel4test-clean
.PHONY:: sel4test-bundle-debug
.PHONY:: sel4test-wrapper-bundle-debug
.PHONY:: sel4test-build-debug-headers
.PHONY:: sel4test-build-wrapper-debug-headers
.PHONY:: sel4test-gen-headers
