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

# Cantrip Rust unit tests.

CARGO_TEST        := ${CARGO_CMD} test

# NB: cargo_test_debugconsole_zmodem is broken
#	TODO(b/232928288): temporarily disable cargo_test_cantrip_proc_manager &
#	cargo_test_cantrip_os_common_logger &
#   cargo_test_cantrip_proc_interface; they need to be rewritten (or tossed)
CARGO_TEST_CANTRIP=\
  cargo_test_cantrip_os_common_slot_allocator \
  cargo_test_mailbox_driver \
  cargo_test_opentitan_timer \
  cargo_test_uart_driver \
  cargo_test_cantrip_vec_core

## Runs all cargo unit tests for the Cantrip operating system
cargo_test_cantrip: $(CARGO_TEST_CANTRIP) | cantrip-gen-headers

## Runs cargo unit tests for the ProcessManager implementation
cargo_test_cantrip_proc_manager: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/ProcessManager/cantrip-proc-manager && $(CARGO_TEST)

## Runs cargo unit tests for the ProcessManager interface
cargo_test_cantrip_proc_interface: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/ProcessManager/cantrip-proc-interface && $(CARGO_TEST)

## Runs cargo unit tests for the CantripLogger service
cargo_test_cantrip_os_common_logger: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/cantrip-os-common/src/logger && \
		$(CARGO_TEST) -- --test-threads=1

## Runs cargo unit tests for the CantripSlotAllocator crate
cargo_test_cantrip_os_common_slot_allocator: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/cantrip-os-common/src/slot-allocator && \
		$(CARGO_TEST) -- --test-threads=1

## Runs cargo unit tests for the DebugConsole zmomdem support
cargo_test_debugconsole_zmodem: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/DebugConsole/zmodem && $(CARGO_TEST)

## Runs cargo unit tests for the MailboxDriver
cargo_test_mailbox_driver: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/MailboxDriver/tests && $(CARGO_TEST)

## Runs cargo unit tests for the opentitan-timer support
cargo_test_opentitan_timer: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/TimerService/tests && $(CARGO_TEST)

## Runs cargo unit tests for the UARTDriver
cargo_test_uart_driver: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/UARTDriver/tests && $(CARGO_TEST)

## Runs cargo unit tests for the Vector Core support
cargo_test_cantrip_vec_core: | cantrip-gen-headers
	cd $(CANTRIP_COMPONENTS)/MlCoordinator/tests && $(CARGO_TEST)

.PHONY:: cargo_test_cantrip $(CARGO_TEST_CANTRIP)
