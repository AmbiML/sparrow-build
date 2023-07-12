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

## Target to build the elfconvert utility
#
# Used in the CPIO bundling process, this tool converts ELF-formatted binaries
# into something directly loadable by CantripOS.
#
# See also the source code in $(ROOTDIR)/cantrip/tools/seL4/misc/elfconvert for
# more information.
elfconvert:
	$(CARGO_CMD) build -q \
        --manifest-path "$(ROOTDIR)/cantrip/tools/seL4/misc/elfconvert/Cargo.toml" \
        --target-dir "$(OUT)/host"

ELFCONVERT := $(OUT)/host/debug/elfconvert

%.app: %.elf | elfconvert
	$(ELFCONVERT) -f app -i $< -o $@

%.model: % | elfconvert
	$(ELFCONVERT) -f springbok -i $< -o $@

%.kelvin: %.elf | elfconvert
	$(ELFCONVERT) -f kelvin -i $< -o $@

.PHONY:: elfconvert
