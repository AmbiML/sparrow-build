# Build Kelvin ISS and artifacts.

KELVIN_SW_SRC_DIR := $(ROOTDIR)/sw/kelvin
KELVIN_SW_OUT_DIR := $(OUT)/kelvin/sw
KELVIN_SW_BAZEL_OUT_DIR := $(KELVIN_SW_OUT_DIR)/bazel_out
KELVIN_SW_TESTLOG_DIR := $(KELVIN_SW_OUT_DIR)/bazel_testlog

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

PHONY:: kelvin_sw kelvin_sw_clean kelvin_sw_test
PHONY:: kelvin_sim kelvin_sim_clean
