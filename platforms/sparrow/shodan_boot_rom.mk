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

SPARROW_BOOT_ROM_SOURCE_DIR:=$(ROOTDIR)/sw/multihart_boot_rom
SPARROW_BOOT_ROM_BUILD_DIR:=$(OUT)/sparrow_boot_rom
SPARROW_BOOT_ROM_BUILD_NINJA_SCRIPT:=$(SPARROW_BOOT_ROM_BUILD_DIR)/build.ninja
SPARROW_BOOT_ROM_ELF:=multihart_boot_rom.elf

$(SPARROW_BOOT_ROM_BUILD_DIR):
	@mkdir -p "$(SPARROW_BOOT_ROM_BUILD_DIR)"

$(SPARROW_BOOT_ROM_BUILD_NINJA_SCRIPT): | $(SPARROW_BOOT_ROM_BUILD_DIR)
	cmake -B $(SPARROW_BOOT_ROM_BUILD_DIR) -G Ninja $(SPARROW_BOOT_ROM_SOURCE_DIR)

## Build the Sparrow boot ROM image
#
# This builds a simple multi-core boot ROM that can bootstrap the Sparrow system
# in simulation. Source is in sw/multihart_boot_rom, while output is placed in
# out/sparrow_boot_rom
multihart_boot_rom: $(SPARROW_BOOT_ROM_BUILD_NINJA_SCRIPT)
	cmake --build $(SPARROW_BOOT_ROM_BUILD_DIR) --target $(SPARROW_BOOT_ROM_ELF)

## Clean the Sparrow boot ROM build directory
multihart_boot_rom_clean:
	rm -rf $(SPARROW_BOOT_ROM_BUILD_DIR)


.PHONY:: multihart_boot_rom multihart_boot_rom_clean
