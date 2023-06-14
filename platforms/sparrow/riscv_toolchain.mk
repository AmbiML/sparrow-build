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

TOOLCHAIN_SRC_DIR   := $(OUT)/tmp/toolchain/riscv-gnu-toolchain
TOOLCHAIN_BUILD_DIR := $(OUT)/tmp/toolchain/build_toolchain
TOOLCHAIN_OUT_DIR   := $(CACHE)/toolchain
TOOLCHAIN_BIN       := $(TOOLCHAIN_OUT_DIR)/bin/riscv32-unknown-elf-gdb

TOOLCHAINIREE_SRC_DIR   := $(OUT)/tmp/toolchain/riscv-gnu-toolchain_iree
TOOLCHAINIREE_BUILD_DIR  := $(OUT)/tmp/toolchain/build_toolchain_iree
TOOLCHAINIREE_OUT_DIR    := $(CACHE)/toolchain_iree_rv32imf
TOOLCHAINIREE_BIN        := $(TOOLCHAINIREE_OUT_DIR)/bin/riscv32-unknown-elf-gdb
TOOLCHAINLLVM_SRC_DIR    := $(OUT)/tmp/toolchain/llvm-project
TOOLCHAINLLVM_BUILD_DIR  := $(OUT)/tmp/toolchain/build_toolchain_llvm
TOOLCHAINLLVM_BIN        := $(TOOLCHAINIREE_OUT_DIR)/bin/clang

TOOLCHAIN_BUILD_DATE := $(shell date +%Y-%m-%d)


toolchain_src:
	if [[ -f "${TOOLCHAIN_BIN}" ]]; then \
		echo "Toolchain exists, run 'm toolchain_clean' if you really want to rebuild"; \
	else \
		$(ROOTDIR)/scripts/download-toolchain.sh $(TOOLCHAIN_SRC_DIR); \
	fi

$(TOOLCHAIN_BUILD_DIR):
	mkdir -p $(TOOLCHAIN_BUILD_DIR)

# Note the make is purposely launched with high job counts, so we can build it
# faster with a powerful machine (e.g. CI).
$(TOOLCHAIN_BIN): | toolchain_src $(TOOLCHAIN_BUILD_DIR)
	cd $(TOOLCHAIN_BUILD_DIR) && $(TOOLCHAIN_SRC_DIR)/configure \
		--srcdir=$(TOOLCHAIN_SRC_DIR) \
		--prefix=$(TOOLCHAIN_OUT_DIR) \
		--with-arch=rv32imac \
		--with-abi=ilp32
	$(MAKE) -C $(TOOLCHAIN_BUILD_DIR) newlib \
	  GDB_TARGET_FLAGS="--with-expat=yes --with-python=python3.10"
	$(MAKE) -C $(TOOLCHAIN_BUILD_DIR) clean

$(OUT)/toolchain_$(TOOLCHAIN_BUILD_DATE).tar.gz: $(TOOLCHAIN_BIN)
	tar -C $(CACHE) -czf \
		"$(OUT)/toolchain_$(TOOLCHAIN_BUILD_DATE).tar.gz" toolchain
	cd $(OUT) && sha256sum "toolchain_$(TOOLCHAIN_BUILD_DATE).tar.gz" > \
		"toolchain_$(TOOLCHAIN_BUILD_DATE).tar.gz.sha256sum"
	@echo "==========================================================="
	@echo "Toolchain tarball ready at $(OUT)/toolchain_$(TOOLCHAIN_BUILD_DATE).tar.gz"
	@echo "==========================================================="

## Builds the GCC toolchain for the security core and SMC.
#
# Note: this actually builds from source, rather than fetching a release
# tarball, and is most likely not the target you actually want.
#
# This target can take hours to build, and results in a tarball and sha256sum
# called `out/toolchain_<timestamp>.tar.gz` and
# `out/toolchain_<timestamp>.tar.gz.sha256sum`, ready for
# upload. In the process of generating this tarball, this target also builds the
# actual tools in `cache/toolchain`, so untarring this tarball is
# unneccessary.
toolchain: $(OUT)/toolchain_$(TOOLCHAIN_BUILD_DATE).tar.gz

toolchain_src_llvm:
	if [[ -f "${TOOLCHAINLLVM_BIN}" ]]; then \
		echo "Toolchain for LLVM exists, run 'm toolchain_llvm_clean' if you really want to rebuild"; \
	else \
		$(ROOTDIR)/scripts/download-toolchain.sh $(TOOLCHAINIREE_SRC_DIR) "LLVM"; \
	fi

# IREE toolchain
$(TOOLCHAINIREE_BUILD_DIR):
	mkdir -p $(TOOLCHAINIREE_BUILD_DIR)

# Note the make is purposely launched with high job counts, so we can build it
# faster with a powerful machine (e.g. CI).
$(TOOLCHAINIREE_BIN): | toolchain_src_llvm $(TOOLCHAINIREE_BUILD_DIR)
	cd $(TOOLCHAINIREE_BUILD_DIR) && $(TOOLCHAINIREE_SRC_DIR)/configure \
		--srcdir=$(TOOLCHAINIREE_SRC_DIR) \
		--prefix=$(TOOLCHAINIREE_OUT_DIR) \
		--with-arch=rv32i2p0mf2p0 \
		--with-abi=ilp32 \
		--with-cmodel=medany
	$(MAKE) -C $(TOOLCHAINIREE_BUILD_DIR) newlib \
	  GDB_TARGET_FLAGS="--with-expat=yes --with-python=python3.10"
	$(MAKE) -C $(TOOLCHAINIREE_BUILD_DIR) clean

# Build with 32-bit baremetal config.
$(TOOLCHAINLLVM_BIN): $(TOOLCHAINIREE_BIN)
	cmake -B $(TOOLCHAINLLVM_BUILD_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(TOOLCHAINIREE_OUT_DIR) \
		-DCMAKE_C_COMPILER=clang  -DCMAKE_CXX_COMPILER=clang++ \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD="RISCV" \
		-DLLVM_ENABLE_PROJECTS="clang;lld"  \
		-DLLVM_DEFAULT_TARGET_TRIPLE="riscv32-unknown-elf" \
		-DLLVM_INSTALL_TOOLCHAIN_ONLY=On \
		-DDEFAULT_SYSROOT=../riscv32-unknown-elf \
		-G Ninja \
		$(TOOLCHAINLLVM_SRC_DIR)/llvm
	cmake --build $(TOOLCHAINLLVM_BUILD_DIR) --target install
	cmake --build $(TOOLCHAINLLVM_BUILD_DIR) --target clean
# Prepare a newlib-nano directory for the default link of -lc, -lgloss, etc.
	mkdir -p "$(TOOLCHAINIREE_OUT_DIR)/riscv32-unknown-elf/lib/newlib-nano"
	cd "$(TOOLCHAINIREE_OUT_DIR)/riscv32-unknown-elf/lib/newlib-nano" && ln -sf ../libc_nano.a libc.a
	cd "$(TOOLCHAINIREE_OUT_DIR)/riscv32-unknown-elf/lib/newlib-nano" && ln -sf ../libg_nano.a libg.a
	cd "$(TOOLCHAINIREE_OUT_DIR)/riscv32-unknown-elf/lib/newlib-nano" && ln -sf ../libm_nano.a libm.a
	cd "$(TOOLCHAINIREE_OUT_DIR)/riscv32-unknown-elf/lib/newlib-nano" && ln -sf ../libgloss_nano.a libgloss.a

$(OUT)/toolchain_iree_rv32_$(TOOLCHAIN_BUILD_DATE).tar.gz: $(TOOLCHAINLLVM_BIN)
	tar -C $(CACHE) -czf \
		"$(OUT)/toolchain_iree_rv32_$(TOOLCHAIN_BUILD_DATE).tar.gz" toolchain_iree_rv32imf
	cd $(OUT) && sha256sum "toolchain_iree_rv32_$(TOOLCHAIN_BUILD_DATE).tar.gz" > \
		"toolchain_iree_rv32_$(TOOLCHAIN_BUILD_DATE).tar.gz.sha256sum"
	@echo "==========================================================="
	@echo "Toolchain tarball ready at $(OUT)/toolchain_iree_rv32_$(TOOLCHAIN_BUILD_DATE).tar.gz"
	@echo "==========================================================="

## Builds the LLVM toolchain for the vector core.
#
# Note: this actually builds from source, rather than fetching a release
# tarball, and is most likely not the target you actually want.
#
# This target can take hours to build, and results in a tarball and sha256sum
# called `out/toolchain_iree_rv32_<timestamp>.tar.gz` and
# `out/toolchain_iree_rv32_<timestamp>.tar.gz.sha256sum`, ready for upload.
# In the process of generating this tarball, this target also builds the actual
# tools in `cache/toolchain_iree_rv32imf`, so untarring this tarball is
# unneccessary.
toolchain_llvm: $(OUT)/toolchain_iree_rv32_$(TOOLCHAIN_BUILD_DATE).tar.gz

## Removes the IREE RV32IMF toolchain from cache/, forcing a re-fetch if needed.
toolchain_llvm_clean:
	rm -rf $(TOOLCHAINIREE_OUT_DIR) $(OUT)/tmp/toolchain

.PHONY:: toolchain toolchain_llvm toolchain_src toolchain_src_llvm toolchain_llvm_clean
