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

$(SEL4TEST_OUT_RELEASE)/ext_flash.tar: $(MATCHA_BUNDLE_RELEASE) \
		$(SEL4TEST_KERNEL_RELEASE) $(SEL4TEST_ROOTSERVER_RELEASE) | $(OUT)/tmp
	cp -f $(MATCHA_BUNDLE_RELEASE) $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}strip $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(OUT)/tmp/matcha-tock-bundle ${OUT}/tmp/matcha-tock-bundle.bin
	ln -sf $(SEL4TEST_KERNEL_RELEASE) $(OUT)/tmp/kernel
	ln -sf $(SEL4TEST_ROOTSERVER_RELEASE) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader

$(SEL4TEST_OUT_DEBUG)/ext_flash.tar: $(MATCHA_BUNDLE_DEBUG) \
		$(SEL4TEST_KERNEL_DEBUG) $(SEL4TEST_ROOTSERVER_DEBUG) | $(OUT)/tmp
	cp -f $(MATCHA_BUNDLE_DEBUG) $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}strip $(OUT)/tmp/matcha-tock-bundle
	${C_PREFIX}objcopy -O binary -g $(OUT)/tmp/matcha-tock-bundle ${OUT}/tmp/matcha-tock-bundle.bin
	ln -sf $(SEL4TEST_KERNEL_DEBUG) $(OUT)/tmp/kernel
	ln -sf $(SEL4TEST_ROOTSERVER_DEBUG) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $@ matcha-tock-bundle.bin kernel capdl-loader

## Launches an end-to-end build of the sel4test system setup using the
## C-based libsel4 syscall api wrappers. The result is run under Renode.
sel4test: renode multihart_boot_rom $(SEL4TEST_OUT_RELEASE)/ext_flash.tar
	$(RENODE_CMD) -e "\
    \$$tar = @$(SEL4TEST_OUT_RELEASE)/ext_flash.tar; \
    \$$kernel = @$(SEL4TEST_KERNEL_RELEASE); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) start"

## Debug version of the `sel4test` target that stops very early to wait
## for a debugger to be attached.
sel4test-debug: renode multihart_boot_rom $(SEL4TEST_OUT_DEBUG)/ext_flash.tar
	$(RENODE_CMD) -e "\
    \$$tar = @$(SEL4TEST_OUT_DEBUG)/ext_flash.tar; \
    \$$kernel = @$(SEL4TEST_KERNEL_DEBUG); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) start"

$(SEL4TEST_WRAPPER_OUT_RELEASE)/ext_flash.tar: $(MATCHA_BUNDLE_RELEASE) \
		$(SEL4TEST_KERNEL_RELEASE) $(SEL4TEST_WRAPPER_ROOTSERVER_RELEASE) | $(OUT)/tmp
	ln -sf $(MATCHA_BUNDLE_RELEASE) $(OUT)/tmp/matcha-tock-bundle
	ln -sf $(SEL4TEST_KERNEL_RELEASE) $(OUT)/tmp/kernel
	ln -sf $(SEL4TEST_WRAPPER_ROOTSERVER_RELEASE) $(OUT)/tmp/capdl-loader
	tar -C $(OUT)/tmp -cvhf $@ matcha-tock-bundle kernel capdl-loader

## Launches a version of the sel4test target that uses the sel4-sys Rust
## crate wrapped with C shims. The result is run under Renode.
sel4test+wrapper: renode multihart_boot_rom \
		$(SEL4TEST_WRAPPER_OUT_RELEASE)/ext_flash.tar
	$(RENODE_CMD) -e "\
    \$$tar = @$(SEL4TEST_WRAPPER_OUT_RELEASE)/ext_flash.tar; \
    \$$kernel = @$(SEL4TEST_KERNEL_RELEASE); \
    \$$cpio = @/dev/null; \
    $(PORT_PRESTART_CMDS) \
	  i @sim/config/sparrow.resc; $(RENODE_PRESTART_CMDS) start"

.PHONY:: sel4test
.PHONY:: sel4test-debug
.PHONY:: sel4test+wrapper
