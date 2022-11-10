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

MATCHA_SRC_DIR             := $(ROOTDIR)/hw/matcha
OPENTITAN_HW_DIR           := $(OPENTITAN_SRC_DIR)/hw
MATCHA_OUT_DIR             := $(OUT)/matcha/hw
MATCHA_VERILATOR_TB        := $(MATCHA_OUT_DIR)/sim-verilator/Vchip_sim_tb
MATCHA_HW_TEST_OUT         := $(MATCHA_OUT_DIR)/sw/hw_tests
MATCHA_SW_DEVICE_DIR       := $(MATCHA_OUT_DIR)/sw/device
MATCHA_TESTLOG_DIR         := $(MATCHA_OUT_DIR)/test-log

$(MATCHA_OUT_DIR):
	mkdir -p $(MATCHA_OUT_DIR)

## Regenerate Matcha HW files frop IPs and top_matcha definition.
# This target uses Open Titan's autogen tools as well as the HW IPs to generate
# the system verilog files as well as the DV register definition cores and
# system verilog files. The source code is from both hw/opentitan-upstream and
# hw/matcha/, while the output is stored at out/matcha/hw.
#
# This is a dev-only target (not for CI), as it modifies the hw/matcha source
# tree with generated code.
matcha_hw_generate_all: | $(MATCHA_OUT_DIR)
	$(MAKE) -C "$(MATCHA_SRC_DIR)/hw" all

## Build Matcha verilator testbench.
# This target builds the verilator testbench binary from hw/matcha using
# hw/opentitan-upstream as the library. The output is stored in
# out/matcha/hw/.
# This target is compute-intensive. Make sure you have a powerful enough machine
# to build it.
matcha_hw_verilator_sim: $(MATCHA_VERILATOR_TB)

# TODO(ykwang): Copy only needed files into matcha output directory.
# TODO(ykwang): Revise the structure of matcha output directory.
$(MATCHA_VERILATOR_TB): $(MATCHA_OUT_DIR) verilator
	cd $(MATCHA_SRC_DIR) && \
		bazel build //hw:verilator
	cd $(MATCHA_SRC_DIR) && \
		cp -rf --no-preserve=mode bazel-bin/hw/build.verilator/* "$(MATCHA_OUT_DIR)" && \
		chmod +x "$(MATCHA_OUT_DIR)/sim-verilator/Vchip_sim_tb"

## Build Matcha FPGA Target for Nexus Board.
# This target builds the FPGA bit file from hw/matcha using
# hw/opentitan-upstream as the library. The output is stored in
# out/matcha/hw/.
# This target is compute-intensive. Make sure you have a powerful enough machine
# and Vivado suporting the latest UltraScale+ device to build it.
# Move the $(MATCH_SRC_DIR) to the last, so some of prim_xilinx IPs will override the
# default one from $(OPENTITAN_HW_DIR)/ip.
matcha_hw_fpga_nexus: | $(MATCHA_OUT_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel build //hw/bitstream/vivado:fpga_nexus
	cd $(MATCHA_SRC_DIR) && \
		find bazel-bin/hw/bitstream/vivado/build.fpga_nexus/ -regex '.*.\(bit\|mmi\)' \
			-exec cp -f '{}' "$(MATCHA_OUT_DIR)" \;

## Build Matcha FPGA Target for  V6 Board.
# This target builds the FPGA bit file from hw/matcha using
# hw/opentitan-upstream as the library. The output is stored in
# out/matcha/hw/.
# This target is compute-intensive. Make sure you have a powerful enough machine
# and Vivado suporting the latest UltraScale device to build it.
# Move the $(MATCH_SRC_DIR) to the last, so some of prim_xilinx IPs will override the
# default one from $(OPENTITAN_HW_DIR)/ip.
matcha_hw_fpga_v6: | $(MATCHA_OUT_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel build //hw/bitstream/vivado:fpga_v6
	cd $(MATCHA_SRC_DIR) && \
		find bazel-bin/hw/bitstream/vivado/build.fpga_v6/ -regex '.*.\(bit\|mmi\)' \
			-exec cp -f '{}' "$(MATCHA_OUT_DIR)" \;

$(MATCHA_HW_TEST_OUT):
	mkdir -p $(MATCHA_HW_TEST_OUT)
$(MATCHA_SW_DEVICE_DIR)/examples/hello_world: | $(MATCH_OUT_DIR)
	@mkdir -p "$(MATCHA_SW_DEVICE_DIR)/examples/hello_world"
$(MATCHA_SW_DEVICE_DIR)/tests: | $(MATCH_OUT_DIR)
	@mkdir -p "$(MATCHA_SW_DEVICE_DIR)/tests"
$(MATCHA_TESTLOG_DIR):
	mkdir -p $(MATCHA_TESTLOG_DIR)

## Build and run matcha verilator test suite
#
matcha_hw_verilator_tests: verilator | $(MATCHA_TESTLOG_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel test --test_output=streamed //sw/device/tests:verilator_test_suite
	cd $(MATCHA_SRC_DIR) && cp -rf "bazel-testlogs/sw" "$(MATCHA_TESTLOG_DIR)"

## Clean Matcha HW artifact
matcha_hw_clean:
	rm -rf $(MATCHA_OUT_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel clean --expunge

.PHONY:: matcha_hw_verilator_sim matcha_hw_clean matcha_hw_verilator_tests
.PHONY:: matcha_hw_fpga_nexus matcha_hw_fpga_v6
