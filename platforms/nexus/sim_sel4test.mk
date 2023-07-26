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

# sel4test simulation support; this is meant to be included from sim.mk

# NB: release builds do not have enough memory to run sel4test; they
#   will fail to build when elfloader looks for a location to load the image

$(SEL4TEST_OUT_DEBUG)/ext_flash.tar: $(MATCHA_BUNDLE_DEBUG) \
		$(SEL4TEST_KERNEL_DEBUG) $(SEL4TEST_ROOTSERVER_DEBUG) | $(OUT)/tmp
	cp -f $(MATCHA_BUNDLE_DEBUG) $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}strip $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(OUT)/tmp/matcha-tock-bundle ${OUT}/tmp/matcha-tock-bundle.bin
	ln -sf $(SEL4TEST_KERNEL_DEBUG) $(OUT)/tmp/kernel
	ln -sf $(SEL4TEST_ROOTSERVER_DEBUG) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader

## Launches the sel4test target with minimal modifications.
sel4test: renode multihart_boot_rom $(SEL4TEST_OUT_DEBUG)/ext_flash.tar
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/sparrow-debug.repl; \
    \$$tar = @$(SEL4TEST_OUT_DEBUG)/ext_flash.tar; \
    \$$kernel = @$(SEL4TEST_KERNEL_DEBUG); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) \
	  i @sim/config/nexus.resc; $(RENODE_PRESTART_CMDS) start"

# NB: for compatability
sel4test-debug: sel4test

$(SEL4TEST_WRAPPER_OUT_DEBUG)/ext_flash.tar: $(MATCHA_BUNDLE_DEBUG) \
		$(SEL4TEST_KERNEL_DEBUG) $(SEL4TEST_WRAPPER_ROOTSERVER_DEBUG) | $(OUT)/tmp
	cp -f $(MATCHA_BUNDLE_DEBUG) $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}strip $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(OUT)/tmp/matcha-tock-bundle ${OUT}/tmp/matcha-tock-bundle.bin
	ln -sf $(SEL4TEST_KERNEL_DEBUG) $(OUT)/tmp/kernel
	ln -sf $(SEL4TEST_WRAPPER_ROOTSERVER_DEBUG) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader

## Launches a version of the sel4test target that uses the sel4-sys Rust
## crate wrapped with C shims. The result is run under Renode.
sel4test+wrapper: renode multihart_boot_rom \
		$(SEL4TEST_WRAPPER_OUT_DEBUG)/ext_flash.tar
	$(RENODE_CMD) -e "\
    \$$repl_file = @sim/config/platforms/sparrow-debug.repl; \
    \$$tar = @$(SEL4TEST_WRAPPER_OUT_DEBUG)/ext_flash.tar; \
    \$$kernel = @$(SEL4TEST_KERNEL_DEBUG); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) \
	  i @sim/config/nexus.resc; $(RENODE_PRESTART_CMDS) start"

.PHONY:: sel4test
.PHONY:: sel4test-debug
.PHONY:: sel4test+wrapper
