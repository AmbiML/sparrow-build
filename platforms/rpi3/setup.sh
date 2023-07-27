#!/bin/bash
#
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

export TARGET_PLATFORM="rpi3"
export C_PREFIX="aarch64-none-linux-gnu-"
export RUST_PREFIX="aarch64-unknown-none"
export CANTRIP_TARGET_ARCH="aarch64-unknown-elf"

# For non-Sparrow targets we use CARGO_HOME or RUSTUP_HOME (if set) to find
# the Rust toolchain. Otherwise we fallback to the search path and look for
# cargo. The rest of the build system uses CARGO_HOME and RUSTUP_HOME so we
# force set them below. See
#    https://rust-lang.github.io/rustup/environment-variables.html
# and/or
#    https://doc.rust-lang.org/cargo/reference/environment-variables.html
RUSTDIR=
for path in "${CARGO_HOME}" "${RUSTUP_HOME}"; do
    if [[ -x "${path}/bin/cargo" ]]; then
        export RUSTDIR="${path}"
        break
    fi
done
if [[ -z "${RUSTDIR}" ]]; then
    # Fall back to the search path to find cargo (where cbindgen is also
    # expected to be found).
    cargo_binary="$(which cargo)"
    if [[ -x "${cargo_binary}" ]]; then
        export RUSTDIR="$(dirname $(dirname ${cargo_binary}))";
    fi
fi
if [[ -z "${RUSTDIR}" ]]; then
    echo '!!! Cannot locate Rust. Please install and/or fix your search path!'
else
    export CARGO_HOME="${RUSTDIR}"
    export RUSTUP_HOME="${RUSTDIR}"
    export PATH="${RUSTDIR}/bin:${PATH}"
fi
