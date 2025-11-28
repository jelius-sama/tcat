SWIFTC      := swiftc

# Go toolchain compiled against musl with a specific patch applied
# NOTE: The latest version of go's compiler source code has a bug.
#		When compiled using musl-gcc to be used with musl tools like we are doing
#		here, it segfaults during runtime when the `-buildmode` is `c-archive`.
# Make sure that the path is correct, we `cd` into `libgolang` when we use this compiler.
GOC         := ../bin/musl-go

# Make sure that $SWIFT_STATIC_SDK is set correctly in your env.
# In most cases you swift static sdk path should look like:
# ~/.swiftpm/swift-sdks/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle/swift-6.0.3-RELEASE_static-linux-0.0.1/swift-linux-musl/musl-1.2.5.sdk/x86_64
# Note that the version may differ depending on what version you have installed.
SDK_ROOT := $(SWIFT_STATIC_SDK)

# Go static build (musl)
GOFLAGS     := build -buildmode=c-archive

# Swift static build (musl) 
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
	-lgolang \
	-Xlinker --strip-all \
	-Xlinker --gc-sections \
	-Xlinker --icf=all

BIN         := bin/swift-ffi
GOLIB       := libgolang/libgolang.a
GOSRC       := libgolang/golang.go
SWIFTSRC := $(shell find Source -name '*.swift')

.PHONY: all clean

all: $(BIN)

$(GOLIB): $(GOSRC)
	@cd libgolang && $(GOC) $(GOFLAGS) -o libgolang.a golang.go
	@echo Successfully built \`$(GOLIB)\`.

$(BIN): $(SWIFTSRC) $(GOLIB)
	@mkdir -p bin
	@$(SWIFTC) $(SWIFTFLAGS) -o $(BIN) $(SWIFTSRC)
	@echo Successfully built \`$(BIN)\`.

clean:
	rm -f $(BIN) $(GOLIB) libgolang/libgolang.h
