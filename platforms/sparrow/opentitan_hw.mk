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

$(OPENTITAN_BUILD_LOG_DIR):
	@echo "Creating log directory $(OPENTITAN_BUILD_LOG_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_LOG_DIR)"
	@mkdir -p "$(OPENTITAN_BUILD_LOG_SW_DIR)"

## Run OpenTitan earlgrey smoketests in verilator
# Build the verilated model, the test software and runs the tests
earlgrey_hw_verilator_smoketests: | $(VERILATOR_BIN) $(OPENTITAN_BUILD_LOG_DIR)
	cd $(OPENTITAN_SRC_DIR) && \
		bazel query "kind(test, //sw/device/tests:all)" \
			| grep "_smoketest" \
			| xargs bazel test --test_tag_filters=verilator,-broken \
				--define bitstream=skip \
				--test_timeout=180,600,1800,3600 \
				--test_output=errors \
				--local_test_jobs=HOST_CPUS*0.25 \
				--//hw:make_options=-j,8 \
				--build_tests_only=true
	cd $(OPENTITAN_SRC_DIR) && \
		cp -rf "bazel-testlogs/sw/device" "$(OPENTITAN_BUILD_LOG_SW_DIR)"

## Run All the OpenTitan earlgrey device tests in verilator
# Build the verilated model, the test software and runs the tests.
#
# Note: This will take hours to finish. Run it with caution.
earlgrey_hw_verilator_tests_all: | $(VERILATOR_BIN) $(OPENTITAN_BUILD_LOG_DIR)
	cd $(OPENTITAN_SRC_DIR) && \
		bazel test --test_tag_filters=verilator,-broken \
			--define bitstream=skip \
			--test_timeout=180,900,1800,3600 \
			--test_output=errors \
			--local_test_jobs=HOST_CPUS*0.25 \
			--//hw:make_options=-j,8 \
			--build_tests_only=true \
			//sw/device/tests:all
	cd $(OPENTITAN_SRC_DIR) && \
		cp -rf "bazel-testlogs/sw/device" "$(OPENTITAN_BUILD_LOG_SW_DIR)"

.PHONY:: earlgrey_hw_verilator_smoketests earlgrey_hw_verilator_tests_all
