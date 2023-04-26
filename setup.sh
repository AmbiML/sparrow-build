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

PLATFORM=${PLATFORM:-sparrow}

## Shamelessly borrowed from android's envsetup.sh.
function getrootdir
{
    local TOPFILE="build/Makefile"
    # if env variable `SPARROW_ROOTDIR` is set, the setting is sticky.
    if [[ -n "$SPARROW_ROOTDIR" && -f "$SPARROW_ROOTDIR/$TOPFILE" ]]; then
        # The following circumlocution ensures we remove symlinks
        # from SPARROW_ROOTDIR.
        (cd "${SPARROW_ROOTDIR}"; PWD= /bin/pwd)
    else
        if [[ -f "${TOPFILE}" ]]; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE="${PWD}"
            local R=
            while [ \( ! \( -f "${TOPFILE}" \) \) -a \( "${PWD}" != "/" \) ]; do
                \cd ..
                R=`PWD= /bin/pwd -P`
            done
            \cd "${HERE}"
            if [ -f "${R}/${TOPFILE}" ]; then
                echo "${R}"
            fi
        fi
    fi
}

export ROOTDIR="$(getrootdir)"
export OUT="${ROOTDIR}/out"
export CACHE="${ROOTDIR}/cache"

# NB: platform setup.sh (included below) sets up the rust toolchain
export PATH="${HOME}/.local/bin:${PATH}"
export PATH="${CACHE}/toolchain/bin:${PATH}"
export PATH="${ROOTDIR}/scripts:${PATH}"
export PATH="${CACHE}/renode:${PATH}"
export PATH="${OUT}/host/qemu/riscv32-softmmu:${PATH}"
export PATH="${OUT}/host/flatbuffers/bin:${PATH}"
export PATH="${OUT}/host/verilator/bin:${PATH}"
export PATH="${OUT}/host/verible/bin:${PATH}"

export CANTRIP_RUST_VERSION=${CANTRIP_RUST_VERSION:-"nightly-2023-01-26"}
export RENODE_PORT=1234

export PYTHONPATH="${PYTHONPATH}:${ROOTDIR}/cicd/"
export PYTHON_SPARROW_ENV="${CACHE}/${PLATFORM}-venv"

function renode
{
    "${CACHE}/renode/renode" "$@"
}

function iss
{
    (cd "${ROOTDIR}" && python3 "${ROOTDIR}/scripts/quick_sim.py" "$@")
}

function qemu_sim_springbok
{
    local file="${1}"; shift
    (cd "${ROOTDIR}" && qemu-system-riscv32 -M springbok -nographic -d springbok -device loader,file="${file}" "$@")
}

function sim_springbok
{
    local command="start;"
    if [[ "$2" == "debug" ]]; then
        command="machine StartGdbServer 3333;"
    fi
    local bin_file=$(realpath $1)
    (cd "${ROOTDIR}" && renode -e "\$bin=@${bin_file}; i @sim/config/springbok.resc; \
    ${command} sysbus.vec_controlblock WriteDoubleWord 0xc 0" \
        --disable-xwt --console)

}

function get-groups
{
    git --git-dir="${ROOTDIR}/.repo/manifests.git" config \
        --get manifest.groups
}

function m
{
    (cd "${ROOTDIR}" && make -f "${ROOTDIR}/build/Makefile" "$@")
    return $?
}

function _hmm
{
    local targetname="$1"; shift
    targetname="${targetname}" gawk -f "${ROOTDIR}/build/helpmemake.awk" \
              "${ROOTDIR}/build/Makefile" \
              "${ROOTDIR}/build/platforms/${PLATFORM}"/*.mk \
              "${ROOTDIR}"/build/*.mk
}

function hmm
{
    local usage="Usage: hmm [-h] [-l] <targetname>"
    local long=""
    local args=$(getopt hl $*)
    set -- $args

    for i; do
        case "$1" in
            -l)
                long=1
                shift 1
                ;;

            --)
                shift
                break
                ;;

            -h|*)
                echo $usage >/dev/stderr
                return 1
                ;;
        esac
    done

    local targetname="${1}"; shift

    if [[ "${targetname}" ]]; then
        _hmm "${targetname}"
        return 0
    fi

    if [[ -z "${long}" ]]; then
        _hmm | fmt --width=80
    else
        _hmm
    fi
}

function safe-abandon
{
    local branch="${1}"; shift

    if [[ -z "${branch}" ]]; then
        echo "Usage: safe-abandon <branchname>"
        echo
        echo "Abandons a repo branch in the current project only."
        echo "This is much safer than using the actual 'repo abandon'"
        echo "command, since it won't globally revert branches across"
        echo "the entire project space."
        echo
        return 1
    fi

    repo abandon "${branch}" .
}

function list-platforms
{
    for i in $(echo "${ROOTDIR}/build/platforms"/*); do
        basename $i |sed 's/\.sh$//'
    done
}

function set-platform
{
    local platform="${1}"; shift

    if [[ -z "${platform}" ]]; then
        (
            echo "Usage: set-platform <platform>"
            echo
            echo "Sets the target platform for the build. Platforms available are:"
            echo
            list-platforms
            echo
        ) | fmt
        return 1
    fi

    export PLATFORM="${platform}"
    source "${ROOTDIR}/build/platforms/${platform}/setup.sh"
}

function kcargo
{
    local CANTRIP_OUT_DIR="${OUT}/cantrip/${CANTRIP_TARGET_ARCH}"

    # NB: sel4-config needs a path to the kernel build which could be
    #     in debug or release (for our needs either works)
    local SEL4_OUT_DIR="${CANTRIP_OUT_DIR}/debug/kernel/"
    if [[ ! -d "${SEL4_OUT_DIR}/gen_config" ]]; then
        SEL4_OUT_DIR="${CANTRIP_OUT_DIR}/release/kernel/"
        if [[ ! -d "${SEL4_OUT_DIR}/gen_config" ]]; then
            echo "No kernel build found at \${SEL4_OUT_DIR}; build a kernel first"
            set +x
            return 1
        fi
    fi

    local SEL4_PLATFORM=$(awk '/CONFIG_PLATFORM/{print $3}' "$ROOTDIR/build/platforms/$PLATFORM/cantrip.mk")
    local RUST_TARGET=$(awk '/RUST_TARGET/{print $3}' "$ROOTDIR/build/platforms/$PLATFORM/cantrip_apps.mk")

    local CARGO_CMD="cargo +${CANTRIP_RUST_VERSION}"
    local CARGO_TARGET="--target ${RUST_TARGET} --features ${SEL4_PLATFORM}"
    local CARGO_OPTS='-Z unstable-options -Z avoid-dev-deps'
    # TODO(sleffler): maybe set --target-dir to avoid polluting the src tree

    # NB: we don't want to export anything to the user's shell (in particular
    # RUSTFLAGS), hence the subshell parenthesis.
    (
        export RUSTFLAGS='-Z tls-model=local-exec'
        export SEL4_OUT_DIR="$SEL4_OUT_DIR"

        cmd=${1:-build}
        case "$1" in
          fmt)
            ${CARGO_CMD} $*;;
          ""|-*)
            ${CARGO_CMD} build ${CARGO_OPTS} ${CARGO_TARGET};;
          clippy)
            # NB: track preupload-clippy.sh
            ${CARGO_CMD} clippy ${CARGO_OPTS} ${CARGO_TARGET} \
              --target-dir ${CANTRIP_OUT_DIR}/clippy -- \
              -D warnings \
              -A clippy::uninlined_format_args
            ;;
          *)
            ${CARGO_CMD} $* ${CARGO_OPTS} ${CARGO_TARGET};;
        esac
    )
}

if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    unset JUMP_TARGETS
    declare -Ax JUMP_TARGETS
    JUMP_TARGETS[.]="."
    JUMP_TARGETS[top]="${ROOTDIR}"
    JUMP_TARGETS[rootdir]="${ROOTDIR}"
    JUMP_TARGETS[out]="${OUT}"
    JUMP_TARGETS[build]="${ROOTDIR}/build"
    JUMP_TARGETS[doc]="${ROOTDIR}/doc"

    JUMP_TARGETS[cantrip]="${ROOTDIR}/cantrip/projects/cantrip"
    JUMP_TARGETS[system]="${ROOTDIR}/cantrip/projects/cantrip/apps/system"
    JUMP_TARGETS[c-apps]="${ROOTDIR}/cantrip/projects/cantrip/apps/c"
    JUMP_TARGETS[rust-apps]="${ROOTDIR}/cantrip/projects/cantrip/apps/rust"

    JUMP_TARGETS[tock]="${ROOTDIR}/sw/tock"

    function j
    {
        local target="$1"; shift
        local splitpath=(${target//\// })
        local subpath=""

        if [[ -z "${target}" ]]; then
            cd "${ROOTDIR}"
            return 0
        fi

        if [[ -z "${JUMP_TARGETS[$target]}" ]]; then
            target="${splitpath[0]}"
            subpath="${splitpath[@]:1}"
        fi

        if [[ -z "${JUMP_TARGETS[$target]}" ]]; then
            echo "Jump targets are:"
            echo "${!JUMP_TARGETS[@]}"
            return 1
        fi

        cd "${JUMP_TARGETS[$target]}"

        if [[ ! -z "${subpath}" ]]; then
            cd "${subpath}"
        fi
    }

    if builtin complete >/dev/null 2>/dev/null; then
        function _j_targets
        {
            echo "${!JUMP_TARGETS[@]}"
        }

        function _j
        {
            local cur="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=()
            if [[ "${COMP_CWORD}" -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$(_j_targets)" $cur) )
            fi
        }

        complete -F _j j

        function _complete_build_targets
        {
            local cur="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=()
            if [[ "${COMP_CWORD}" -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$(hmm -l)" $cur) )
            fi
        }

        complete -F _complete_build_targets m
        complete -F _complete_build_targets hmm

        function _complete_platform_targets
        {
            local cur="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=()
            if [[ "${COMP_CWORD}" -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$(list-platforms)" $cur) )
            fi
        }

        complete -F _complete_platform_targets set-platform
    fi
fi

set-platform ${PLATFORM}

# Explicitly set the variables to run the venv python interpreter.
export PATH="${PYTHON_SPARROW_ENV}/bin:${PATH}"
export VIRTUAL_ENV="${PYTHON_SPARROW_ENV}"

echo "========================================"
echo ROOTDIR="${ROOTDIR}"
echo OUT="${OUT}"
echo PLATFORM="${PLATFORM}"
echo PYTHON_SPARROW_ENV="${PYTHON_SPARROW_ENV}"
echo "========================================"
echo
echo Type \'m \[target\]\' to build.
echo
echo "Targets available are:"
echo
hmm
echo
echo "To get more information on a target, use 'hmm [target]'"
echo

declare -F parting_messages >/dev/null && parting_messages
