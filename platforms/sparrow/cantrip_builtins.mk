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

CANTRIP_APPS_RELEASE  := $(CANTRIP_OUT_C_APP_RELEASE)/hello/hello.app \
                         $(CANTRIP_OUT_RUST_APP_RELEASE)/fibonacci/fibonacci.app \
                         $(CANTRIP_OUT_RUST_APP_RELEASE)/keyval/keyval.app \
                         $(CANTRIP_OUT_RUST_APP_RELEASE)/logtest/logtest.app \
                         $(CANTRIP_OUT_RUST_APP_RELEASE)/mltest/mltest.app \
                         $(CANTRIP_OUT_RUST_APP_RELEASE)/panic/panic.app \
                         $(CANTRIP_OUT_C_APP_RELEASE)/suicide/suicide.app \
                         $(CANTRIP_OUT_RUST_APP_RELEASE)/timer/timer.app
CANTRIP_MODEL_RELEASE := $(OUT)/springbok_iree/quant_models/mobilenet_v1_emitc_static.model

CANTRIP_APPS_DEBUG    := $(CANTRIP_OUT_C_APP_DEBUG)/hello/hello.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/fibonacci/fibonacci.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/keyval/keyval.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/logtest/logtest.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/mltest/mltest.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/panic/panic.app \
                         $(CANTRIP_OUT_C_APP_DEBUG)/suicide/suicide.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/timer/timer.app
CANTRIP_MODEL_DEBUG   := $(OUT)/springbok_iree/quant_models/mobilenet_v1_emitc_static.model

CANTRIP_SCRIPTS       := $(ROOTDIR)/build/platforms/$(PLATFORM)/builtins.repl

# HACK(jtgans): Fix the IREE targets to explicitly list the files it generates.
$(patsubst %.model,%,$(CANTRIP_MODEL_RELEASE)): iree_model_builtins
$(patsubst %.model,%,$(CANTRIP_MODEL_DEBUG)): iree_model_builtins

