SWIFTC      := swiftc
GOC         := go

# Go static build
GOFLAGS     := build -buildmode=c-archive

SWIFTFLAGS  := \
	-I ./libgolang \
	-L ./libgolang \
	-lgolang

BIN         := bin/go_swift
GOLIB       := libgolang/libgolang.a
GOSRC       := libgolang/golang.go
SWIFTSRC    := main.swift

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
