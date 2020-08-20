$(ROOTDIR)/cache/toolchain: $(ROOTDIR)/toolchain
	pushd $(ROOTDIR)/toolchain; ./configure \
		--prefix=$(ROOTDIR)/cache/toolchain \
		--with-arch=rv32gc \
		--with-abi=ilp32
	pushd $(ROOTDIR)/toolchain; make -j$(nproc) newlib

toolchain: $(ROOTDIR)/cache/toolchain

.PHONY:: toolchain
