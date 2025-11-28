SHELL := /bin/bash

# NOTE:
# You can read through this if you want to, but I'd recommend just writing
# the Go code in the `libgolang` directory and the Swift code in the `Sources`
# directory. They will be compiled automatically when you run this Makefile.
#
# If you need more libraries, follow the same process we used for `libgolang`.
# The steps should be very similar whether the library language is Go or C.
#
# If you need a library or package written in Swift, you may have to research
# that on your own since most Swift projects use SwiftPM, but we don't — we
# just raw-dawg the `swiftc`.

SWIFTC      := swiftc

# Go toolchain compiled against musl with a specific patch applied
# NOTE: The latest version of go's compiler source code has a bug.
#		When compiled using musl-gcc to be used with musl tools like we are doing
#		here, it segfaults during runtime when the `-buildmode` is `c-archive`.
# Make sure that the path is correct, we `cd` into `libgolang` when we use this compiler.
GOC         := ../bin/musl-go

CC          := musl-gcc

# Make sure that $SWIFT_STATIC_SDK is set correctly in your env.
# In most cases you swift static sdk path should look like:
# ~/.swiftpm/swift-sdks/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle/swift-6.0.3-RELEASE_static-linux-0.0.1/swift-linux-musl/musl-1.2.5.sdk/x86_64
# Note that the version may differ depending on what version you have installed.
SDK_ROOT := $(SWIFT_STATIC_SDK)

# Swift static build
SWIFTFLAGS  := \
	-target x86_64-swift-linux-musl \
	-sdk "$(SDK_ROOT)" \
	-resource-dir "$(SDK_ROOT)/usr/lib/swift_static" \
	-O \
	-whole-module-optimization \
	-parse-as-library \
	-static-executable \
	-static-stdlib \
	-I ./libgolang \
	-L ./libgolang \
	-I ./libcshit \
	-L ./libcshit \
	-lgolang \
	-lcshit \
	-Xlinker --strip-all \
	-Xlinker --gc-sections \
	-Xlinker --icf=all

# Go static archive
GOFLAGS     := build -buildmode=c-archive

CFLAGS := -I./libgolang -include libgolang.h -O3 -c

# NOTE:
# Suppressing this warning because it is emitted internally by swiftc/clang,
# not by our code, and has no effect on the build.
SUPPRESSED_WARN := "clang: warning: argument unused during compilation: '-pie' \[-Wunused-command-line-argument\]"

BIN         := bin/swift-ffi

GOLIB       := libgolang/libgolang.a
GOHEADER  := libgolang/libgolang.h
GOSRC       := $(shell find libgolang -name '*.go')
GOENTRY     := libgolang/

CLIB        := libcshit/libcshit.a
CSRC        := libcshit/cshit.c
COBJ        := libcshit/cshit.o

SWIFTSRC := $(shell find Source -name '*.swift')

# path_strip_prefix(TEXT)  -> drop first component up to first '/'
path_strip_prefix = $(shell printf '%s\n' "$(1)" | cut -d/ -f2-)

# path_strip_suffix(TEXT)  -> drop last component after last '/'
path_strip_suffix = $(shell printf '%s\n' "$(1)" | rev | cut -d/ -f2- | rev)

# path_strip(MODE, TEXT)
# MODE = prefix | suffix
path_strip = $(if $(filter prefix,$(1)), \
                 $(call path_strip_prefix,$(2)), \
                 $(call path_strip_suffix,$(2)) \
              )

.PHONY: all clean

all: $(BIN)

$(GOLIB) $(GOHEADER): $(GOSRC)
	@cd $(call path_strip,suffix,$(GOLIB)) && $(GOC) $(GOFLAGS) -o $(call path_strip,prefix,$(GOLIB)) $(GOENTRY)
	@echo Successfully built \`$(GOLIB)\`.

$(CLIB): $(CSRC) $(GOHEADER)
	@$(CC) $(CFLAGS) -o $(COBJ) $(CSRC) && ar rcs $(CLIB) $(COBJ)
	@rm $(COBJ)
	@echo Successfully built \`$(CLIB)\`.

$(BIN): $(SWIFTSRC) $(GOLIB) $(CLIB) $(GOHEADER)
	@mkdir -p bin
	@$(SWIFTC) $(SWIFTFLAGS) -o $(BIN) $(SWIFTSRC) \
		2> >(grep -v $(SUPPRESSED_WARN) >&2)
	@rm $(GOLIB) && rm $(CLIB)
	@echo Successfully built \`$(BIN)\`.

clean:
	rm -f $(BIN) $(GOLIB) libgolang/libgolang.h $(CLIB) $(COBJ)
