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

# Built-in applications. Platforms typically override these settings
# depending on their functionality (e.g. platforms with ML support
# set CANTRIP_MODEL_*).

CANTRIP_APPS_RELEASE   := $(CANTRIP_OUT_C_APP_RELEASE)/hello/hello.app
CANTRIP_APPS_DEBUG     := $(CANTRIP_OUT_C_APP_DEBUG)/hello/hello.app
CANTRIP_MODEL_RELEASE  :=
CANTRIP_MODEL_DEBUG    :=
CANTRIP_SCRIPTS        :=

# TODO(jtgans): should include from platforms/${PLATFORM}/platform.mk
include $(ROOTDIR)/build/platforms/$(PLATFORM)/cantrip_builtins.mk

CPIO ?= cpio
BUILTINS_CPIO_OPTS := -H newc -L --no-absolute-filenames --reproducible --owner=root:root

# HACK(jtgans): Fix the IREE targets to explicitly list the files it generates.
$(patsubst %.model,%,$(CANTRIP_MODEL_RELEASE)): iree_model_builtins
$(patsubst %.model,%,$(CANTRIP_MODEL_DEBUG)): iree_model_builtins

$(CANTRIP_OUT_RELEASE)/builtins: $(CANTRIP_APPS_RELEASE) $(CANTRIP_MODEL_RELEASE) ${CANTRIP_SCRIPTS}
	rm -rf $@
	mkdir -p $@
	cp $(CANTRIP_APPS_RELEASE) $(CANTRIP_MODEL_RELEASE) ${CANTRIP_SCRIPTS} $@

$(CANTRIP_OUT_DEBUG)/builtins: $(CANTRIP_APPS_DEBUG) $(CANTRIP_MODEL_DEBUG) ${CANTRIP_SCRIPTS}
	rm -rf $@
	mkdir -p $@
	cp $(CANTRIP_APPS_DEBUG) $(CANTRIP_MODEL_DEBUG) ${CANTRIP_SCRIPTS} $@

$(CANTRIP_OUT_RELEASE)/ext_builtins.cpio: $(CANTRIP_OUT_RELEASE)/builtins
	ls -1 $< | $(CPIO) -o -D $< $(BUILTINS_CPIO_OPTS) -O "$@"

$(CANTRIP_OUT_DEBUG)/ext_builtins.cpio: $(CANTRIP_OUT_DEBUG)/builtins
	ls -1 $< | $(CPIO) -o -D $< $(BUILTINS_CPIO_OPTS) -O "$@"

## Generates cpio archive of Cantrip builtins with debugging suport
cantrip-builtins-debug: $(CANTRIP_OUT_DEBUG)/ext_builtins.cpio
## Generates cpio archive of Cantrip builtins for release
cantrip-builtins-release: $(CANTRIP_OUT_RELEASE)/ext_builtins.cpio
## Generates both debug & release cpio archives of Cantrip builtins
cantrip-builtins: cantrip-builtins-debug cantrip-builtins-release

cantrip-builtins-clean-debug:
	rm -rf $(CANTRIP_OUT_DEBUG)/builtins
	rm -f $(CANTRIP_OUT_DEBUG)/ext_builtins.cpio

cantrip-builtins-clean-release:
	rm -rf $(CANTRIP_OUT_RELEASE)/builtins
	rm -f $(CANTRIP_OUT_RELEASE)/ext_builtins.cpio

cantrip-builtins-clean: cantrip-builtins-debug-clean cantrip-builtins-release-clean

.PHONY:: cantrip-builtins-debug
.PHONY:: cantrip-builtins-release
.PHONY:: cantrip-builtins
.PHONY:: cantrip-builtins-debug-clean
.PHONY:: cantrip-builtins-release-clean
.PHONY:: cantrip-builtins-clean
