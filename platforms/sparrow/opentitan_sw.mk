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

OPENTITAN_SRC_DIR             := $(ROOTDIR)/hw/opentitan-upstream
OPENTITAN_BUILD_DIR           := $(OUT)/opentitan/sw
OPENTITAN_BUILD_OUT_DIR       := $(OPENTITAN_BUILD_DIR)/build-out
OPENTITAN_BUILD_SW_DIR        := $(OPENTITAN_BUILD_DIR)/build-out/sw
OPENTITAN_BUILD_SW_DEVICE_DIR := $(OPENTITAN_BUILD_DIR)/build-out/sw/device
OPENTITAN_BUILD_SW_DEVICE_TESTS_DIR := $(OPENTITAN_BUILD_DIR)/build-out/sw/device/tests
OPENTITAN_BUILD_LOG_DIR       := $(OPENTITAN_BUILD_DIR)/build-log
OPENTITAN_BUILD_LOG_SW_DIR    := $(OPENTITAN_BUILD_DIR)/build-log/sw

$(OPENTITAN_BUILD_OUT_DIR):
	@echo "Creating output directory $(OPENTITAN_BUILD_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_SW_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_SW_DEVICE_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_SW_DEVICE_TESTS_DIR)"

## Builds the hardware testing binaries from OpenTitan in hw/opentitan-upstream
# The output is stored at out/opentitan/sw/build-out/sw/device
opentitan_sw_all: | $(OPENTITAN_BUILD_OUT_DIR) \
                  opentitan_sw_verilator_sim
	cd $(OPENTITAN_SRC_DIR) && \
		bazel query "kind(test, //sw/device/tests/...)" | \
			grep "_fpga" | \
			xargs bazel build --action_env=BITSTREAM=d20fe23d160fea56980790b8d43a73c80e25855c \
				--define DISABLE_VERILATOR_BUILD=true && \
		find "bazel-out/" -type f -wholename "*fastbuild-*/sw/device/tests*/*.bin" | \
			sed 's/\.bin//g' | \
			xargs -I {} cp -f {} "$(OPENTITAN_BUILD_SW_DEVICE_TESTS_DIR)/"
	cd $(OPENTITAN_SRC_DIR) && \
	  bazel build //hw/ip/otbn:all && \
		cp -f bazel-bin/hw/ip/otbn/otbn_simple_smoke_test.elf "$(OPENTITAN_BUILD_SW_DEVICE_TESTS_DIR)/"

$(OPENTITAN_BUILD_SW_DEVICE_DIR)/examples/hello_world: | $(OPENTITAN_BUILD_OUT_DIR)
	@mkdir -p "$(OPENTITAN_BUILD_SW_DEVICE_DIR)/examples/hello_world"

## Build the sw helloworld ELF from hw/opentitan-upstream
# The output is stored at out/opentitan/sw/build-out/sw/device/examples/hello_world
opentitan_sw_helloworld: | $(OPENTITAN_BUILD_SW_DEVICE_DIR)/examples/hello_world
	cd $(OPENTITAN_SRC_DIR) && \
		bazel build //sw/device/examples/hello_world:hello_world
	cd $(OPENTITAN_SRC_DIR) && \
		find "bazel-out/" -name "hello_world*.elf" \
		-exec cp -f '{}' "$(OPENTITAN_BUILD_SW_DEVICE_DIR)/examples/hello_world" \;

$(OPENTITAN_BUILD_SW_DEVICE_DIR)/boot_rom: | $(OPENTITAN_BUILD_OUT_DIR)
	@mkdir -p "$(OPENTITAN_BUILD_SW_DEVICE_DIR)/boot_rom"

## Build the boot rom artifacts for Open Titan from hw/opentitan-upstream
# The artifacts are stored at out/opentitan/sw/build-out/sw/device/boot_rom
# TODO(ykwang): revise boot_rom to test_rom.
opentitan_sw_bootrom: | $(OPENTITAN_BUILD_SW_DEVICE_DIR)/boot_rom
	cd $(OPENTITAN_SRC_DIR) && \
		bazel build //sw/device/lib/testing/test_rom:test_rom
	cd $(OPENTITAN_SRC_DIR) && \
		find "bazel-out/" -wholename "*fastbuild-*/*test_rom_fpga_cw310.scr.39.vmem" \
		-exec cp -f '{}' "$(OPENTITAN_BUILD_SW_DEVICE_DIR)/boot_rom/" \;

$(OPENTITAN_BUILD_SW_DEVICE_DIR)/otp_img: | $(OPENTITAN_BUILD_OUT_DIR)
	@mkdir -p "$(OPENTITAN_BUILD_SW_DEVICE_DIR)/otp_img"

## Build the opt image for Open Titan from hw/opentitan-upstream
# The artifacts are stored at out/opentitan/sw/build-out/sw/device/otp_img/otp_img_sim_verilator.vmem
opentitan_opt_img: | $(OPENTITAN_BUILD_SW_DEVICE_DIR)/otp_img
	cd $(OPENTITAN_SRC_DIR) && \
		bazel build //hw/ip/otp_ctrl/data:img_dev
	cd $(OPENTITAN_SRC_DIR) && \
		find "bazel-bin/" -name "img_dev*.vmem" \
		-exec cp -f '{}' "$(OPENTITAN_BUILD_SW_DEVICE_DIR)/otp_img/otp_img_sim_verilator.vmem" \;

## Build the Verilator sim SW for Open Titan from hw/opentitan-upstream
# The artifacts include boot_rom, hello_world ELF, and otp image. The artifacts
# are stored at out/opentitan/sw/build-bin
opentitan_sw_verilator_sim: | $(OPENTITAN_BUILD_OUT_DIR) \
                              opentitan_sw_helloworld \
                              opentitan_sw_bootrom \
                              opentitan_opt_img

$(OPENTITAN_BUILD_LOG_DIR):
	@echo "Creating log directory $(OPENTITAN_BUILD_LOG_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_LOG_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_LOG_SW_DIR)"

## Build and run host based opentitan unittests
# The artifacts are stored at out/opentitan/sw/build-out/sw/device
opentitan_sw_test: | $(OPENTITAN_BUILD_OUT_DIR) \
                   $(OPENTITAN_BUILD_LOG_DIR)
	cd $(OPENTITAN_SRC_DIR) && \
		export CC=gcc-11; export CXX=g++-11; \
		bazel query "kind(test, //sw/device/...)" | \
			grep "_unittest" | \
			xargs bazel test --build_tests_only=false \
				--define DISABLE_VERILATOR_BUILD=true \
				--test_tag_filters=-broken,-cw310,-verilator,-dv
	cd $(OPENTITAN_SRC_DIR) && \
		cp -rf "bazel-bin/sw/device" "$(OPENTITAN_BUILD_SW_DIR)"
	cd $(OPENTITAN_SRC_DIR) && \
		cp -rf "bazel-testlogs/sw/device" "$(OPENTITAN_BUILD_LOG_SW_DIR)"


## Removes only the OpenTitan build artifacts from out/opentitan/sw
opentitan_sw_clean:
	rm -rf $(OPENTITAN_BUILD_DIR)

.PHONY:: opentitan_sw_all opentitan_sw_clean opentitan_sw_verilator_sim opentitan_sw_test
.PHONY:: opentitan_sw_helloworld opentitan_sw_bootrom opentitan_opt_img
