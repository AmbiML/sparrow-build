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

IREE_SRC:=$(ROOTDIR)/toolchain/iree
TOOLCHAINRV32_PATH:=$(CACHE)/toolchain_iree_rv32imf
IREE_COMPILER_DIR:=${CACHE}/iree_compiler

IREE_RUNTIME_ROOT:=$(ROOTDIR)/sw/vec_iree
MODEL_SRC_DIR:=$(ROOTDIR)/ml/ml-models-public
IREE_RUNTIME_OUT=$(OUT)/springbok_iree
IREE_RUNTIME_NO_WMMU_OUT=$(OUT)/springbok_iree_no_wmmu

MODEL_INTERNAL_SRC_DIR:=$(ROOTDIR)/ml/ml-models
IREE_RUNTIME_INTERNAL_OUT=$(OUT)/springbok_iree_internal
IREE_RUNTIME_INTERNAL_NO_WMMU_OUT=$(OUT)/springbok_iree_internal_no_wmmu

RV32_EXE_LINKER_FLAGS=-Wl,--print-memory-usage

RV32_COMPILER_FLAGS=-g3 \
    -ggdb

# The following targets are always rebuilt when the iree target is made

iree_check:
	@if echo "$${PIN_TOOLCHAINS}" |grep -qw 'iree'; then \
        echo "****************************************************"; \
        echo "*                                                  *"; \
        echo "*  PIN_TOOLCHAINS includes iree! Skipping the      *"; \
        echo "*  download of the latest IREE compiler binaries.  *"; \
        echo "*  Please DO NOT file bugs for IREE mis-behavior!  *"; \
        echo "*                                                  *"; \
        echo "****************************************************"; \
	else \
		echo Updating $(IREE_SRC) submodules...; \
		git -C $(IREE_SRC) submodule sync && \
	  		git -C $(IREE_SRC) submodule update --init --jobs=8 --depth=10; \
	fi

$(IREE_COMPILER_DIR)/build.ninja: | iree_check
	cmake -G Ninja -B $(IREE_COMPILER_DIR) \
	    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
	    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	    -DCMAKE_INSTALL_PREFIX=$(IREE_COMPILER_DIR)/install \
	    -DIREE_HAL_DRIVERS_TO_BUILD="Dylib;VMVX" \
	    -DIREE_TARGET_BACKENDS_TO_BUILD="DYLIB-LLVM-AOT;VMVX" \
	    -DIREE_BUILD_TESTS=OFF \
	    $(IREE_SRC)

## Builds the IREE compiler from source and records the HEAD commit ID
iree_compiler_src: $(IREE_COMPILER_DIR)/build.ninja | iree_check
	cmake --build $(IREE_COMPILER_DIR) --target install
	git -C "$(IREE_SRC)" rev-parse HEAD > $(IREE_COMPILER_DIR)/tag

$(IREE_COMPILER_DIR):
	mkdir -p $(IREE_COMPILER_DIR)

## Downloads the latest release of the IREE compiler and tflite tools.
#
# The release tag and commit are recorded for consistency checks in
# the `iree_runtime` target. The outputs of this target are placed in
# out/host/iree_compiler.
#
iree_compiler: | $(IREE_COMPILER_DIR)
	$(ROOTDIR)/scripts/download_iree_compiler.py --iree_compiler_dir "$(IREE_COMPILER_DIR)"
iree_commit_check:
	$(ROOTDIR)/scripts/check-iree-commit.sh "$(IREE_SRC)" "$(IREE_COMPILER_DIR)"

IREE_RUNTIME_DEFAULT_CONFIG :=\
	-DCMAKE_TOOLCHAIN_FILE="$(IREE_RUNTIME_ROOT)/cmake/riscv_iree.cmake" \
	-DCMAKE_BUILD_TYPE=MinSizeRel \
	-DIREE_HOST_BIN_DIR="$(IREE_COMPILER_DIR)/install/bin" \
	-DRISCV_TOOLCHAIN_ROOT=$(TOOLCHAINRV32_PATH) \
	-DRISCV_COMPILER_FLAGS="$(RV32_COMPILER_FLAGS)" \
	-DCMAKE_EXE_LINKER_FLAGS="$(RV32_EXE_LINKER_FLAGS)"

IREE_RUNTIME_NO_WMMU_CONFIG :=\
	$(IREE_RUNTIME_DEFAULT_CONFIG) \
	-DBUILD_NO_WMMU=ON \
	-DSPRINGBOK_LINKER_SCRIPT=$(realpath $(ROOTDIR)/sw/vec/springbok/springbok_no_wmmu.ld)

$(IREE_RUNTIME_OUT)/build.ninja: | iree_compiler iree_check iree_commit_check
	cmake -G Ninja -B $(IREE_RUNTIME_OUT) \
	    $(IREE_RUNTIME_DEFAULT_CONFIG) \
	    $(MODEL_SRC_DIR)

## Model artifact used in cantrip-builtins-*
#
# IREE executables used in cantrip-builtins-*
iree_model_builtins: $(IREE_RUNTIME_OUT)/build.ninja | iree_check iree_commit_check
	PYTHONPATH=$(IREE_COMPILER_DIR) cmake --build $(IREE_RUNTIME_OUT) --target \
		quant_models/mobilenet_v1_emitc_static

$(IREE_RUNTIME_INTERNAL_OUT)/build.ninja: | iree_check iree_commit_check
	cmake -G Ninja -B $(IREE_RUNTIME_INTERNAL_OUT) \
	    $(IREE_RUNTIME_DEFAULT_CONFIG) \
	    $(MODEL_INTERNAL_SRC_DIR)

$(IREE_RUNTIME_NO_WMMU_OUT)/build.ninja: | iree_check iree_commit_check
	cmake -G Ninja -B $(IREE_RUNTIME_NO_WMMU_OUT) \
	    $(IREE_RUNTIME_NO_WMMU_CONFIG) \
	    $(MODEL_SRC_DIR)

$(IREE_RUNTIME_INTERNAL_NO_WMMU_OUT)/build.ninja: | iree_check iree_commit_check
	cmake -G Ninja -B $(IREE_RUNTIME_INTERNAL_NO_WMMU_OUT) \
	    $(IREE_RUNTIME_NO_WMMU_CONFIG) \
	    $(MODEL_INTERNAL_SRC_DIR)

## Installs the IREE runtime applications.
#
# Unlike the `iree_compiler` target, this target actually builds the runtime
# from source in toolchain/iree. The results of the build are placed in
# out/springbok_iree.
#
# In general, you probably want the `iree` target instead, which combines
# `iree_compiler` and `iree_runtime`.
iree_runtime: $(IREE_RUNTIME_OUT)/build.ninja | iree_check iree_commit_check
	PYTHONPATH=$(IREE_COMPILER_DIR) cmake --build $(IREE_RUNTIME_OUT)

## Installs the IREE compiler and its runtime applications.
iree: iree_compiler iree_runtime

## Installs the IREE runtime internal applications.
#
# Unlike the `iree_runtime` target, this target builds the runtime application
# for internal models. The results of the build are placed in
# out/springbok_iree_internal.
#
# In general, you probably want the `iree_runtime` target instead.
iree_runtime_internal: $(IREE_RUNTIME_INTERNAL_OUT)/build.ninja | \
		iree_check iree_commit_check
	PYTHONPATH=$(IREE_COMPILER_DIR) cmake --build $(IREE_RUNTIME_INTERNAL_OUT)

## Installs the IREE compiler and internal runtime applications.
#
# In general, you probably want to run `iree` target to build the public
# applications.
iree_internal: iree_compiler iree_runtime_internal

## Installs the IREE runtime applications, built without WMMU support.
iree_runtime_no_wmmu: $(IREE_RUNTIME_NO_WMMU_OUT)/build.ninja | iree_check iree_commit_check
	PYTHONPATH=$(IREE_COMPILER_DIR) cmake --build $(IREE_RUNTIME_NO_WMMU_OUT)

## Installs the IREE compiler and its runtime applications without WMMU, for single core testing.
iree_no_wmmu: iree_compiler iree_runtime_no_wmmu

## Installs the IREE runtime internal applications, built without WMMU support.
iree_internal_runtime_no_wmmu: $(IREE_RUNTIME_INTERNAL_NO_WMMU_OUT)/build.ninja | iree_check iree_commit_check
	PYTHONPATH=$(IREE_COMPILER_DIR) cmake --build $(IREE_RUNTIME_INTERNAL_NO_WMMU_OUT)

## Installs the IREE compiler and its runtime applications without WMMU, for single core testing.
iree_internal_no_wmmu: iree_compiler iree_internal_runtime_no_wmmu

## Clean IREE compiler and runtime applications.
iree_clean:
	rm -rf $(IREE_COMPILER_DIR) $(IREE_RUNTIME_OUT) $(IREE_RUNTIME_NO_WMMU_OUT)

## Clean IREE compiler and runtime application of internal models
iree_internal_clean:
	rm -rf $(IREE_COMPILER_DIR) $(IREE_RUNTIME_INTERNAL_OUT) $(IREE_RUNTIME_INTERNAL_NO_WMMU_OUT)

.PHONY:: iree iree_check iree_compiler iree_runtime iree_clean
.PHONY:: iree_commit_check iree_compiler_src
.PHONY:: iree_runtime_internal iree_internal iree_internal_clean
.PHONY:: iree_runtime_no_wmmu iree_no_wmmu iree_internal_runtime_no_wmmu iree_internal_no_wmmu
.PHONY:: iree_model_builtins
