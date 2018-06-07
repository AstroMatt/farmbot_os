rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2)$(filter $(subst *,%,$2),$d))

LUA_SRC := $(call rwildcard, lib, *.lua)
LUA_SRC += $(call rwildcard, src, *.lua)

INSTALLED := $(patsubst src/%,$(INST_BINDIR)/%,$(LUA_SRC))
INSTALLED += $(patsubst lib/%,$(INST_BINDIR)/%,$(LUA_SRC))

DIRS := $(sort $(dir $(wildcard $(INSTALLED)/)))

all:
	@echo --- build
	@echo CFLAGS: $(CFLAGS)
	@echo LIBFLAG: $(LIBFLAG)
	@echo LUA_LIBDIR: $(LUA_LIBDIR)
	@echo LUA_BINDIR: $(LUA_BINDIR)
	@echo LUA_INCDIR: $(LUA_INCDIR)

install: $(DIRS) $(INSTALLED)
	@echo --- install
	@echo INST_PREFIX: $(INST_PREFIX)
	@echo INST_BINDIR: $(INST_BINDIR)
	@echo INST_LIBDIR: $(INST_LIBDIR)
	@echo INST_LUADIR: $(INST_LUADIR)
	@echo INST_CONFDIR: $(INST_CONFDIR)

$(INST_BINDIR)/%.lua: src/%.lua
	cp --parents $< $@

$(DIRS):
	mkdir -p $(DIRS)
