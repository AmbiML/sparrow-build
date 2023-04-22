TBM_SRC_DIR := $(ROOTDIR)/sim/tbm

## Build TBM simulator
tbm: flatbuffers
	$(MAKE) -C $(TBM_SRC_DIR) all
.PHONY:: tbm

## Removes TBM build artifacts from out/
tbm_clean:
	$(MAKE) -C $(TBM_SRC_DIR) clean
.PHONY:: tbm_clean

## Remove all TBM build and test artifacts from out/
tbm_clean_all: tbm_clean
.PHONY:: tbm_clean_all

## Run TBM on the riscv-tests
# The results are saved in out/tbm/traces/riscv-tests/{benchmarks,isa}/*.tbm_log
tbm_riscv_tests: tbm spike springbok_riscv_tests
	$(MAKE) -C $(TBM_SRC_DIR) -f riscv_tests.mk riscv_tests
.PHONY:: tbm_riscv_tests

## Clean TBM test results
tbm_clean_riscv_tests:
	$(MAKE) -C $(TBM_SRC_DIR) -f riscv_tests.mk clean_riscv_tests
.PHONY:: tbm_clean_riscv_tests
tbm_clean_all: tbm_clean_riscv_tests

## Run TBM on the riscv-tests
# The results are saved in out/tbm/traces/rvv/*.tbm_log
tbm_rvv_tests: tbm spike springbok_for_tbm
	$(MAKE) -C $(TBM_SRC_DIR) -f rvv_tests.mk rvv_tests
.PHONY:: tbm_rvv_tests

## Clean TBM test results
tbm_clean_rvv_tests:
	$(MAKE) -C $(TBM_SRC_DIR) -f rvv_tests.mk clean_rvv_tests
.PHONY:: tbm_clean_rvv_tests
tbm_clean_all: tbm_clean_rvv_tests

## Run TBM on various examples from sparrow
# The results are saved in out/tbm/traces/integration
tbm_integration_tests: tbm spike iree_no_wmmu springbok
	$(MAKE) -C $(TBM_SRC_DIR) -f integration-tests.mk integration_tests
.PHONY:: tbm_integration_tests

## Clean TBM test results
tbm_clean_integration_tests:
	$(MAKE) -C $(TBM_SRC_DIR) -f integration-tests.mk clean_integration_tests
.PHONY:: tbm_clean_integration_tests
tbm_clean_all: tbm_clean_integration_tests
