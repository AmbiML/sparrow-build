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

VERILATOR_SRC_DIR   := $(ROOTDIR)/sim/verilator
VERILATOR_BUILD_DIR := $(OUT)/tmp/verilator
VERILATOR_OUT_DIR   := $(OUT)/host/verilator
VERILATOR_BIN       := $(VERILATOR_OUT_DIR)/bin/verilator_bin
VERILATOR_BUILTIN   := $(shell which verilator)

$(VERILATOR_BUILD_DIR):
	mkdir -p $(VERILATOR_BUILD_DIR)

ifeq ($(VERILATOR_BUILTIN), /usr/src/verilator/bin/verilator)
$(VERILATOR_BIN):
	@echo "Verilator exists at $(VERILATOR_BUILTIN)"
else
$(VERILATOR_BIN): | $(VERILATOR_SRC_DIR) $(VERILATOR_BUILD_DIR)
	cd $(VERILATOR_BUILD_DIR) && \
		autoconf -o $(VERILATOR_BUILD_DIR)/configure $(VERILATOR_SRC_DIR)/configure.ac
	cd $(VERILATOR_BUILD_DIR) && sh configure \
		CC=gcc-11 CXX=g++-11 \
		--srcdir=$(VERILATOR_SRC_DIR) \
		--prefix=$(VERILATOR_OUT_DIR)
	$(MAKE) -C $(VERILATOR_BUILD_DIR)
	$(MAKE) -C $(VERILATOR_BUILD_DIR) install
endif

## Removes only the Verilator build artifacts from out/
verilator_clean:
	rm -rf $(VERILATOR_BUILD_DIR) $(VERILATOR_OUT_DIR)

## Builds the Verilator verilog simulation tool.
#
# Using sources in sim/verilator, builds the Verilator tooling and places its
# output in out/host/verilator.
#
# To rebuild this target, remove $(VERILATOR_BIN) and re-run.
verilator: $(VERILATOR_BIN)

.PHONY:: verilator verilator_clean
