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

NEXUS_BOOT_ROM_SOURCE_DIR:=$(ROOTDIR)/sw/multihart_boot_rom
NEXUS_BOOT_ROM_BUILD_DIR:=$(OUT)/sparrow_boot_rom
NEXUS_BOOT_ROM_BUILD_NINJA_SCRIPT:=$(NEXUS_BOOT_ROM_BUILD_DIR)/build.ninja
NEXUS_BOOT_ROM_ELF:=multihart_boot_rom.elf

$(NEXUS_BOOT_ROM_BUILD_DIR):
	@mkdir -p "$(NEXUS_BOOT_ROM_BUILD_DIR)"

$(NEXUS_BOOT_ROM_BUILD_NINJA_SCRIPT): | $(NEXUS_BOOT_ROM_BUILD_DIR)
	cmake -B $(NEXUS_BOOT_ROM_BUILD_DIR) -G Ninja $(NEXUS_BOOT_ROM_SOURCE_DIR)

## Build the Nexus boot ROM image
#
# This builds a simple multi-core boot ROM that can bootstrap the Nexus system
# in simulation. Source is in sw/multihart_boot_rom, while output is placed in
# out/nexus_boot_rom
multihart_boot_rom: $(NEXUS_BOOT_ROM_BUILD_NINJA_SCRIPT)
	cmake --build $(NEXUS_BOOT_ROM_BUILD_DIR) --target $(NEXUS_BOOT_ROM_ELF)

## Clean the Nexus boot ROM build directory
multihart_boot_rom_clean:
	rm -rf $(NEXUS_BOOT_ROM_BUILD_DIR)


.PHONY:: multihart_boot_rom multihart_boot_rom_clean
