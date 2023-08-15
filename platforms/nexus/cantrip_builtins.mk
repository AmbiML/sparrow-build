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
# Temporarily have only 5M for builtins; not enough for an IREE model
CANTRIP_MODEL_RELEASE := $(OUT)//kelvin/sw/bazel_out/hello_world.kelvin

CANTRIP_APPS_DEBUG    := $(CANTRIP_OUT_C_APP_DEBUG)/hello/hello.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/fibonacci/fibonacci.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/keyval/keyval.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/logtest/logtest.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/mltest/mltest.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/panic/panic.app \
                         $(CANTRIP_OUT_C_APP_DEBUG)/suicide/suicide.app \
                         $(CANTRIP_OUT_RUST_APP_DEBUG)/timer/timer.app
# NB: debug builds only run on Renode where we have 16M for builtins
CANTRIP_MODEL_DEBUG   := $(OUT)/kelvin_iree/sparrow_iree/samples/microbenchmarks/conv1x1_test_emitc_static

CANTRIP_SCRIPTS       := $(ROOTDIR)/build/platforms/$(PLATFORM)/builtins.repl

$(patsubst %.kelvin,%.elf,$(CANTRIP_MODEL_RELEASE)): kelvin_sw
$(CANTRIP_MODEL_DEBUG): iree_model_builtins
