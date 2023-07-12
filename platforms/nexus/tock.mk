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

# Matcha platform + kernel binaries
MATCHA_PLATFORM_SRC_DIR := $(ROOTDIR)/sw/matcha/platform/
MATCHA_PLATFORM_DEBUG   := $(OUT)/matcha/riscv32imc-unknown-none-elf/debug/matcha_platform
MATCHA_PLATFORM_RELEASE := $(OUT)/matcha/riscv32imc-unknown-none-elf/release/matcha_platform

# Matcha app binaries
MATCHA_APP_SRC_DIR := $(ROOTDIR)/sw/matcha/app/
MATCHA_APP_DEBUG   := $(OUT)/matcha/riscv32imc-unknown-none-elf/debug/matcha_app
MATCHA_APP_RELEASE := $(OUT)/matcha/riscv32imc-unknown-none-elf/release/matcha_app

# Bundled platform+kernel+app binaries
MATCHA_BUNDLE_DEBUG   := $(OUT)/matcha-bundle-debug.elf
MATCHA_BUNDLE_RELEASE := $(OUT)/matcha-bundle-release.elf

########################################

$(RUSTDIR)/bin/elf2tab: | rust_presence_check
	cargo install elf2tab --version 0.6.0

$(MATCHA_APP_DEBUG): | rust_presence_check
	export CARGO_NET_GIT_FETCH_WITH_CLI=true; \
		cd $(MATCHA_PLATFORM_SRC_DIR); cargo -Z unstable-options --config 'build.rustflags = ["-C", "link-arg=-Tlayout_debug.ld"]' build
	cd $(MATCHA_APP_SRC_DIR); PLATFORM=opentitan cargo -Z unstable-options --config 'build.rustflags = ["-C", "link-arg=-Tlayout_matcha_debug.ld",]' build

$(MATCHA_APP_RELEASE): | rust_presence_check
	export CARGO_NET_GIT_FETCH_WITH_CLI=true; \
		cd $(MATCHA_PLATFORM_SRC_DIR); cargo -Z unstable-options --config 'build.rustflags = ["-C", "link-arg=-Tlayout.ld"]' build --release
	cd $(MATCHA_APP_SRC_DIR); PLATFORM=opentitan cargo -Z unstable-options --config 'build.rustflags = ["-C", "link-arg=-Tlayout_matcha.ld",]' build --release

$(MATCHA_BUNDLE_DEBUG): $(MATCHA_APP_DEBUG) $(RUSTDIR)/bin/elf2tab | rust_presence_check
	elf2tab -n matcha -o $(MATCHA_APP_DEBUG).tab $(MATCHA_APP_DEBUG) --stack 4096 --app-heap 1024 --kernel-heap 1024 --protected-region-size=64
	cp $(MATCHA_PLATFORM_DEBUG) $(MATCHA_BUNDLE_DEBUG)
	riscv32-unknown-elf-objcopy --update-section .apps=$(MATCHA_APP_DEBUG).tbf $(MATCHA_BUNDLE_DEBUG)

$(MATCHA_BUNDLE_RELEASE): $(MATCHA_APP_RELEASE) $(RUSTDIR)/bin/elf2tab | rust_presence_check
	elf2tab -n matcha -o $(MATCHA_APP_RELEASE).tab $(MATCHA_APP_RELEASE) --stack 4096 --app-heap 1024 --kernel-heap 1024 --protected-region-size=64
	cp $(MATCHA_PLATFORM_RELEASE) $(MATCHA_BUNDLE_RELEASE)
	riscv32-unknown-elf-objcopy --update-section .apps=$(MATCHA_APP_RELEASE).tbf $(MATCHA_BUNDLE_RELEASE)

########################################

## Builds TockOS for the security core in debug mode
matcha_tock_debug: $(MATCHA_BUNDLE_DEBUG)

## Builds TockOS for the security core in release mode
matcha_tock_release: $(MATCHA_BUNDLE_RELEASE)

## Removes the TockOS and libtockrs build artifacts from out/
matcha_tock_clean:
	cd $(MATCHA_PLATFORM_SRC_DIR); PLATFORM=opentitan cargo clean --target-dir=$(OUT)/matcha
	cd $(MATCHA_APP_SRC_DIR); PLATFORM=opentitan cargo clean --target-dir=$(OUT)/matcha
	rm -rf $(OUT)/matcha
	rm -f $(MATCHA_BUNDLE_DEBUG) $(MATCHA_BUNDLE_RELEASE)

.PHONY:: matcha_tock_debug matcha_tock_release matcha_tock_clean

# Mark these real files as phony since building them requires calling out to a
# separate build system (cargo)
.PHONY:: $(MATCHA_APP_DEBUG) $(MATCHA_APP_RELEASE)
