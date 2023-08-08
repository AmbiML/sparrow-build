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
MATCHA_OUT_DIR             := $(OUT)/matcha/hw
MATCHA_VERILATOR_TB        := $(MATCHA_OUT_DIR)/sim-verilator/Vchip_sim_tb
MATCHA_TESTLOG_DIR         := $(MATCHA_OUT_DIR)/test-log
MATCHA_FPGA_BINARY_DIR     := $(MATCHA_OUT_DIR)/fpga_tests
MATCHA_FPGA_KELVIN_BINARY_DIR := $(MATCHA_FPGA_BINARY_DIR)/kelvin

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
		cp -rf --no-preserve=mode bazel-bin/hw/build.verilator_real/* "$(MATCHA_OUT_DIR)" && \
		chmod +x "$(MATCHA_OUT_DIR)/sim-verilator/Vchip_sim_tb"

## Build Matcha FPGA Target for Nexus Board.
# This target builds the FPGA bit file from hw/matcha using
# hw/opentitan-upstream as the library. The output is stored in
# out/matcha/hw/.
# This target is compute-intensive. Make sure you have a powerful enough machine
# and Vivado suporting the latest UltraScale+ device to build it.
matcha_hw_fpga_nexus: | $(MATCHA_OUT_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel build //hw/bitstream/vivado:fpga_nexus
	cd $(MATCHA_SRC_DIR) && \
		find bazel-bin/hw/bitstream/vivado/build.fpga_nexus/ -regex '.*.\(bit\|mmi\)' \
			-exec cp -f '{}' "$(MATCHA_OUT_DIR)" \;

$(MATCHA_TESTLOG_DIR):
	mkdir -p $(MATCHA_TESTLOG_DIR)

## Build Matcha sw artifacts
#
# Checks the matcha sw code integrity for targets not covered by the verilator
# tests.
#
matcha_sw_all:
	cd $(MATCHA_SRC_DIR) && \
	  bazel build --define DISABLE_VERILATOR_BUILD=true --build_tag_filters="-kelvin_fpga" \
			//sw/device/...


$(MATCHA_FPGA_KELVIN_BINARY_DIR):
	mkdir -p "$(MATCHA_FPGA_KELVIN_BINARY_DIR)"


## Build Matcha Kelvin SW FPGA test artifacts
#
# Build kelvin artifacts and package it in a tarball and ready for use on the FPGA
# The output is at out/matcha/hw/fpga_tests/kelvin
#
matcha_kelvin_fpga_tarballs: kelvin_sw | $(MATCHA_FPGA_KELVIN_BINARY_DIR)
	cd $(MATCHA_SRC_DIR) && \
	  bazel build --define DISABLE_VERILATOR_BUILD=true \
			//sw/device/tests/kelvin/fpga_tests/...
# Copy the tarballs and sc binary to out/.
	cd $(MATCHA_SRC_DIR) && \
		find "bazel-out/" -type f -wholename "*fastbuild-*/sw/device/tests/kelvin/fpga_tests/*.bin" |\
			xargs -I {} cp -f {} "$(MATCHA_FPGA_KELVIN_BINARY_DIR)"
	cd $(MATCHA_SRC_DIR) && \
		find "bazel-bin/sw/device/tests/kelvin/fpga_tests" -name "*.tar" |\
			xargs -I {} cp -f {} "$(MATCHA_FPGA_KELVIN_BINARY_DIR)"


## Build opentitantool for matcha FPGA tests
opentitantool_pkg: | $(MATCHA_OUT_DIR)
	cd $(MATCHA_SRC_DIR) && \
	  bazel build //sw:opentitantool_pkg
	cd $(MATCHA_SRC_DIR) && \
		cp -f bazel-bin/sw/opentitantool_pkg.tar.gz $(MATCHA_OUT_DIR)

## Build and run matcha verilator test suite
#
matcha_hw_verilator_tests: verilator | $(MATCHA_TESTLOG_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel test --test_output=errors --test_timeout=180,600,1800,3600 \
			--local_test_jobs=HOST_CPUS*0.25 \
			--//hw:make_options=-j,16 \
			//sw/device/tests:verilator_test_suite
	cd $(MATCHA_SRC_DIR) && cp -rf "bazel-testlogs/sw" "$(MATCHA_TESTLOG_DIR)"

## Clean Matcha HW artifact
matcha_hw_clean:
	rm -rf $(MATCHA_OUT_DIR)
	cd $(MATCHA_SRC_DIR) && \
		bazel clean --expunge

.PHONY:: matcha_hw_verilator_sim matcha_hw_clean matcha_hw_verilator_tests
.PHONY:: matcha_sw_all opentitantool_pkg
.PHONY:: matcha_hw_fpga_nexus matcha_kelvin_fpga_tarballs
