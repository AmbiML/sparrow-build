# Copyright 2020 Google LLC
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

SHELL := $(shell which /bin/bash)

ifeq ($(ROOTDIR),)
$(error $$ROOTDIR IS NOT DEFINED -- don\'t forget to source setup.sh)
endif

.DEFAULT_GOAL := simulate

include $(ROOTDIR)/build/preamble.mk

include $(ROOTDIR)/build/toolchain.mk
include $(ROOTDIR)/build/cantrip.mk
include $(ROOTDIR)/build/cantrip_tools.mk
include $(ROOTDIR)/build/cantrip_apps.mk
include $(ROOTDIR)/build/cantrip_builtins.mk
include $(ROOTDIR)/build/cantrip_sel4test.mk
include $(ROOTDIR)/build/cantrip_tests.mk
include $(ROOTDIR)/build/minisel.mk
include $(ROOTDIR)/build/flatbuffers.mk
include $(ROOTDIR)/build/spike.mk
include $(ROOTDIR)/build/verilator.mk

include $(ROOTDIR)/build/platforms/$(PLATFORM)/platform.mk

## Installs build prerequisites
#
# This installs a series of typical Linux tools needed to build the whole of the
# sparrow system.
prereqs: $(ROOTDIR)/scripts/install-prereqs.sh \
		 $(ROOTDIR)/scripts/python-requirements.txt \
		 ${CANTRIP_PLATFORM_PYTHON_DEPS} \
		 ${CANTRIP_PLATFORM_APT_DEPS}
	$(ROOTDIR)/scripts/install-prereqs.sh \
		-p "$(ROOTDIR)/scripts/python-requirements.txt \
			 ${CANTRIP_PLATFORM_PYTHON_DEPS}" \
		-a "${CANTRIP_PLATFORM_APT_DEPS}"

$(OUT):
	@mkdir -p $(OUT)

## Installs the RISCV compiler and emulator tooling
#
# This includes Rust, GCC, CLANG, verilator, qemu, and renode.
#
# Output is placed in cache/ and out/host.
tools:: install_rust install_gcc install_llvm install_kelvin renode qemu

## Cleans the entire system
#
# This amounts to an `rm -rf out/` and removes all build artifacts.
clean::
	rm -rf $(OUT)

.PHONY:: prereqs clean cantrip simulate tools
