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

QEMU_SRC_DIR          := $(ROOTDIR)/toolchain/riscv-qemu
QEMU_OUT_DIR          := $(OUT)/host/qemu
QEMU_BINARY           := $(QEMU_OUT_DIR)/riscv32-softmmu/qemu-system-riscv32

## Installs the rust toolchains for cantrip and matcha_tock.
#
# This fetches the tarball from google cloud storage, verifies the checksums and
# untars it to cache/. In addition, it ensures that elf2tab is installed into
# the cache/ toolchain dir.
install_rust: $(CACHE)/rust_toolchain/bin/rustc

## Checks for the rust compilers presence
#
# This target is primarily used as a dependency for other targets that use the
# Rust toolchain and trampoline into brain-damaged build systems that either
# fetch their own version of Rust or otherwise produce bad output when the
# environment is not setup correctly.
#
# This target should not be called by the end user, but used as an order-only
# dependency by other targets.
rust_presence_check:
	@if [[ ! -f $(CARGO_HOME)/bin/rustc ]]; then \
		echo '!!! Rust is not installed. Please run `m tools`!'; \
		exit 1; \
	fi

# Point to the binary to make sure it is installed.
$(CACHE)/rust_toolchain/bin/rustc:
	$(ROOTDIR)/scripts/fetch-rust-toolchain.sh -d

## Collates all of the rust toolchains.
#
# This target makes use of the install-rust-toolchain.sh script to prepare the
# cache/toolchain_rust tree with binaries fetched from upstream Rust builds.
#
# As a general day-to-day developer, you should not need to run this target.
# This actually pulls down new binaries from upstream Rust servers, and should
# ultimately NOT BE USED LONG TERM.
#
# Again, DO NOT USE THIS TARGET UNLESS YOU HAVE A REALLY GOOD REASON -- it is a
# security violation!
#
# If you find you need to use this, please contact jtgans@ or hcindyl@ FIRST.
collate_rust_toolchains: collate_cantrip_rust_toolchain collate_matcha_rust_toolchain

## Collates the Rust toolchain components for cantrip's needs.
#
# See also `collate_rust_toolchains`.
collate_cantrip_rust_toolchain:
	$(ROOTDIR)/scripts/install-rust-toolchain.sh -v "$(CANTRIP_RUST_VERSION)" riscv32imac-unknown-none-elf

## Collates the Rust toolchain components for matcha's app+platform.
#
# See also `collate_rust_toolchains`.
collate_matcha_rust_toolchain:
	$(ROOTDIR)/scripts/install-rust-toolchain.sh -p $(MATCHA_PLATFORM_SRC_DIR)/rust-toolchain riscv32imc-unknown-none-elf
	$(ROOTDIR)/scripts/install-rust-toolchain.sh -p $(MATCHA_APP_SRC_DIR)/rust-toolchain riscv32imc-unknown-none-elf

QEMU_DEPS=$(wildcard $(QEMU_SRC_DIR)/**/*.[ch])

$(QEMU_OUT_DIR): | $(QEMU_SRC_DIR)
	mkdir -p $(QEMU_OUT_DIR);

# Disable configure check to be compatible with lib6 2.36.
$(QEMU_BINARY): $(QEMU_DEPS) | $(QEMU_OUT_DIR)
	cd $(QEMU_OUT_DIR) && $(QEMU_SRC_DIR)/configure \
		--target-list=riscv32-softmmu,riscv32-linux-user --disable-werror
	$(MAKE) -C $(QEMU_OUT_DIR)

## Builds and installs the QEMU RISCV32 simulator.
#
# Sources are in toolchain/riscv-qemu, while outputs are stored in
# out/host/qemu.
qemu: $(QEMU_BINARY)

$(OUT)/tmp: | $(OUT)
	mkdir -p $(OUT)/tmp

$(CACHE):
	mkdir -p $(CACHE)

# Point to the gcc binary to make sure it is installed.
$(CACHE)/toolchain/bin/riscv32-unknown-elf-gcc: | $(CACHE)
	./scripts/install-toolchain.sh gcc

# Point to the clang++ target to make sure the binary is installed.
$(CACHE)/toolchain_iree_rv32imf/bin/clang++: | $(CACHE)
	./scripts/install-toolchain.sh llvm

$(CACHE)/toolchain_kelvin/bin/riscv32-unknown-elf-gcc: | $(CACHE)
	./scripts/install-toolchain.sh kelvin

## Installs the GCC compiler for rv32imac
#
# Requires network access. This fetches the toolchain from the GCP archive and
# extracts it locally to the cache/.
install_gcc: $(CACHE)/toolchain/bin/riscv32-unknown-elf-gcc

## Installs the LLVM compiler for rv32imf
#
# Requires network access. This fetches the toolchain from the GCP archive and
# extracts it locally to the cache/.
install_llvm: $(CACHE)/toolchain_iree_rv32imf/bin/clang++

install_kelvin: $(CACHE)/toolchain_kelvin/bin/riscv32-unknown-elf-gcc

## Cleans up the toolchain from the cache directory
#
# Generally not needed to be run unless something has changed or broken in the
# caching mechanisms built into the build system.
toolchain_clean:
	rm -rf $(OUT)/tmp $(CACHE)/toolchain

## Removes only the QEMU build artifacts from out/
qemu_clean:
	rm -rf $(QEMU_OUT_DIR)

.PHONY:: qemu toolchain_clean qemu_clean install_llvm install_gcc install_rust rust_presence_check
.PHONY:: collate_rust_toolchains collate_cantrip_rust_toolchain collate_matcha_rust_toolchain
