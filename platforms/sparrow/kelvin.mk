# Build Kelvin ISS and artifacts.

KELVIN_SW_SRC_DIR := $(ROOTDIR)/sw/kelvin
KELVIN_SW_OUT_DIR := $(OUT)/kelvin/sw
KELVIN_SW_BAZEL_OUT_DIR := $(KELVIN_SW_OUT_DIR)/bazel_out
KELVIN_SW_TESTLOG_DIR := $(KELVIN_SW_OUT_DIR)/bazel_testlog

KELVIN_HW_SRC_DIR := $(ROOTDIR)/hw/kelvin
KELVIN_HW_OUT_DIR := $(OUT)/kelvin/hw
KELVIN_HW_BAZEL_OUT_DIR := $(KELVIN_HW_OUT_DIR)/bazel_out
KELVIN_HW_TESTLOG_DIR := $(KELVIN_HW_OUT_DIR)/bazel_testlog

KELVIN_SIM_SRC_DIR := $(ROOTDIR)/sim/kelvin
KELVIN_SIM_OUT_DIR := $(OUT)/kelvin/sim


$(KELVIN_SW_BAZEL_OUT_DIR):
	mkdir -p "$(KELVIN_SW_BAZEL_OUT_DIR)"

$(KELVIN_SW_TESTLOG_DIR):
	mkdir -p "$(KELVIN_SW_TESTLOG_DIR)"

## Build Kelvin SW artifacts
#
# Some of the artifacts are built with bazel, and need to be copied to out/
kelvin_sw: | $(KELVIN_SW_BAZEL_OUT_DIR)
	cd "$(KELVIN_SW_SRC_DIR)" && \
		bazel build //...
	cd "$(KELVIN_SW_SRC_DIR)/bazel-out" && \
		find . -type f \( \
			-wholename "*ST-*/*.elf" -o \
			-wholename "*ST-*/*.bin" \) \
			-exec cp -f {} "$(KELVIN_SW_BAZEL_OUT_DIR)/" \;

## Test Kelvin SW artifacts
#
# Test Kelvin SW artifacts with kelvin ISS simulation
kelvin_sw_test: kelvin_sim | $(KELVIN_SW_TESTLOG_DIR)
	cd "$(KELVIN_SW_SRC_DIR)"; \
		bazel test --test_output=errors //... ; \
		cp -rf bazel-testlogs/tests "$(KELVIN_SW_TESTLOG_DIR)"

## Clean Kelvin SW artifacts
kelvin_sw_clean:
	rm -rf "$(KELVIN_SW_OUT_DIR)"
	cd "$(KELVIN_SW_SRC_DIR)" && bazel clean --expunge


$(KELVIN_HW_BAZEL_OUT_DIR):
	mkdir -p "$(KELVIN_HW_BAZEL_OUT_DIR)"

$(KELVIN_HW_TESTLOG_DIR):
	mkdir -p "$(KELVIN_HW_TESTLOG_DIR)"

## Verilog Source for Kelvin
#
# This generates the kelvin.v file that can be used to update hw/matcha
kelvin_hw_verilog: | $(KELVIN_HW_BAZEL_OUT_DIR)
	cd "$(KELVIN_HW_SRC_DIR)" && \
		bazel clean --expunge && \
			bazel build //hdl/chisel:matcha_kelvin_verilog && \
		cp -rf bazel-bin/hdl/chisel/kelvin.v "$(KELVIN_HW_BAZEL_OUT_DIR)"

## Verilated Kelvin HW simulator
kelvin_hw_sim: | $(KELVIN_HW_BAZEL_OUT_DIR)
	cd "$(KELVIN_HW_SRC_DIR)" && \
		bazel build //tests/verilator_sim:core_sim && \
		cp -rf bazel-bin/tests/verilator_sim/core_sim "$(KELVIN_HW_BAZEL_OUT_DIR)"

## Tests for Kelvin HW
kelvin_hw_test: | $(KELVIN_HW_TESTLOG_DIR)
	cd "$(KELVIN_HW_SRC_DIR)"; \
		bazel test --test_output=errors //... ; \
		cp -rf bazel-testlogs/tests "$(KELVIN_HW_TESTLOG_DIR)"

## Clean Kelvin HW artifacts
kelvin_hw_clean:
	rm -rf "$(KELVIN_HW_OUT_DIR)"
	cd "$(KELVIN_HW_SRC_DIR)" && bazel clean --expunge


$(KELVIN_SIM_OUT_DIR):
	mkdir -p "$(KELVIN_SIM_OUT_DIR)"

## Build Kelvin ISS
#
# Build mpact-sim-based Kelvin ISS with bazel, and copy it to out/
# Use /tmp as the bazel tmpfs to unblock CI
kelvin_sim: | $(KELVIN_SIM_OUT_DIR)
	cd "$(KELVIN_SIM_SRC_DIR)" && \
		bazel build --sandbox_tmpfs_path=/tmp //sim:kelvin_sim
	cd "$(KELVIN_SIM_SRC_DIR)/bazel-bin" && \
		cp -f sim/kelvin_sim "$(KELVIN_SIM_OUT_DIR)"

## Clean Kelvin ISS
#
# Clean the Kelvin ISS
kelvin_sim_clean:
	cd "$(KELVIN_SIM_SRC_DIR)" && \
		bazel clean --expunge
	rm -rf $(KELVIN_SIM_OUT_DIR)

PHONY:: kelvin_hw_clean kelvin_hw_sim kelvin_hw_test kelvin_hw_verilog
PHONY:: kelvin_sw kelvin_sw_clean kelvin_sw_test
PHONY:: kelvin_sim kelvin_sim_clean
