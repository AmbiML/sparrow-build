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

export C_PREFIX="riscv32-unknown-elf-"
export IREE_PREFIX="riscv32-unknown-elf-"
export IREE_ARCH="rv32imf"
export RUST_PREFIX="riscv32-unknown-linux-gnu"

# NB: $(CANTRIP_SRC_DIR)/apps/system/rust.cmake forces riscv32imac for
#     the target when building Rust code
export CANTRIP_TARGET_ARCH="riscv32-unknown-elf"

# Sparrow's toolchains are setup specially, just setup the environment.
export RUSTDIR="${CACHE}/rust_toolchain"
export CARGO_HOME="${RUSTDIR}"
export RUSTUP_HOME="${RUSTDIR}"
export PATH="${RUSTDIR}/bin:${PATH}"

export OPENTITAN_GEN_DIR="${CANTRIP_OUT_DIR}/opentitan-gen/include/opentitan"
export OPENTITAN_SOURCE="${ROOTDIR}/hw/opentitan-upstream"

# Some build.rs files use the regtool crate which needs to know where to find
# regtool.py.
export REGTOOL="${OPENTITAN_SOURCE}/util/regtool.py"
# The following files are the input to regtool.py
export MBOX_HJSON="${ROOTDIR}/hw/matcha/hw/top_matcha/ip/tlul_mailbox/data/tlul_mailbox.hjson"
export ML_TOP_HJSON="${ROOTDIR}/hw/matcha/hw/top_matcha/ip/ml_top/data/ml_top.hjson"
export TIMER_HJSON="${OPENTITAN_GEN_DIR}/rv_timer.hjson"
export UART_HJSON="${OPENTITAN_SOURCE}/hw/ip/uart/data/uart.hjson"
export VC_TOP_HJSON="${ROOTDIR}/hw/matcha/hw/top_matcha/ip/vc_top/data/vc_top.hjson"
# Input for topgen_matcha.py to generate hw configuration
export TOP_MATCHA_HJSON="${ROOTDIR}/hw/matcha/hw/top_matcha/data/top_matcha.hjson"

function parting_messages() {
    if [[ ! -d "${RUSTDIR}" ]] ||
       [[ ! -d "${ROOTDIR}/cache/toolchain" ]] ||
       [[ ! -d "${ROOTDIR}/cache/toolchain_iree_rv32imf" ]] ||
       [[ ! -d "${ROOTDIR}/cache/renode" ]]; then
        echo
        echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
        echo You have missing tools. Please run \'m prereqs\' followed
        echo by \'m tools\' to install them.
        echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
        echo
        [[ -d "${RUSTDIR}" ]] || echo "${RUSTDIR} is missing!"
        [[ -d "${ROOTDIR}/cache/toolchain" ]] || echo "${ROOTDIR}/cache/toolchain is missing"
        [[ -d "${ROOTDIR}/cache/toolchain_iree_rv32imf" ]] || echo "${ROOTDIR}/cache/toolchain_iree_rv32imf is missing!"
        [[ -d "${ROOTDIR}/cache/renode" ]] || echo "${ROOTDIR}/cache/renode is missing!"
    fi
}

function sim_kelvin
{
    # check input file to use kelvin_sim or renode wrapper
    local bin_file=$(realpath $1)
    local magic_bytes=$(xxd -p -l 4 "${bin_file}")
    if [[ ${magic_bytes} == "7f454c46" ]]; then
        local flag=""
        if [[ "$2" == "debug" ]]; then
            flag="-i"
        fi
        ("${OUT}/kelvin/sim/kelvin_sim" "${bin_file}" ${flag})
    else
        local command="start;"
        if [[ "$2" == "debug" ]]; then
            command="machine StartGdbServer 3333;"
        fi
        (cd "${ROOTDIR}" && renode -e "\$bin=@${bin_file}; i @sim/config/kelvin.resc; \
        ${command} sysbus.vec_controlblock WriteDoubleWord 0xc 0" \
            --disable-xwt --console)
    fi
}
