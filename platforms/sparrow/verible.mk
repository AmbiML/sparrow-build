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

VERIBLE_BUILD_DIR := $(OUT)/tmp/verible
VERIBLE_OUT_DIR   := $(OUT)/host/verible
VERIBLE_BIN       := $(VERIBLE_OUT_DIR)/bin/verible-verilog-format

$(VERIBLE_OUT_DIR):
	mkdir -p $(VERIBLE_OUT_DIR)

$(VERIBLE_BUILD_DIR):
	mkdir -p $(VERIBLE_BUILD_DIR)

$(VERIBLE_BIN): | $(VERIBLE_BUILD_DIR) $(VERIBLE_OUT_DIR)
	./scripts/install-verible.sh

## Removes verible directory and binaries from out/
verible_clean:
	rm -rf $(VERIBLE_BUILD_DIR) $(VERIBLE_OUT_DIR)

## Downloads and extracts pre-built verible binaries to out/host/verible/bin
verible: $(VERIBLE_BIN)

.PHONY:: verible verible_clean
