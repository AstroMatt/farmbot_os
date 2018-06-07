LUA_VERSION := 5.3.4
MAJOR_VER=5
LUA_NAME := lua-$(LUA_VERSION)
LUA_DL := $(LUA_NAME).tar.gz
LUA_DL_URL := "https://www.lua.org/ftp/$(LUA_DL)"
LUA_SRC_DIR := $(C_SRC_DIR)/$(LUA_NAME)/src
LUA_BUILD_DIR := $(BUILD_DIR)/$(LUA_NAME)

LUA_INCLUDE_DIR := $(LUA_BUILD_DIR)/include
LUA_LIBDIR := $(LUA_BUILD_DIR)/lib

LUA_CFLAGS := -I$(LUA_INCLUDE_DIR)
LUA_LDFLAGS := -L$(LUA_LIBDIR) -llua

LUA_LIB := $(LUA_LIBDIR)/liblua.a

NIF_CFLAGS := -O2
NIF_LDFLAGS := -fPIC -shared -pedantic

LDFLAGS ?= -pthread
CFLAGS ?= -Wall -std=gnu99

ifdef DEBUG
	CFLAGS += -g -DDEBUG
endif

ALL += $(LUA_BUILD_DIR) $(LUA_LIB)

$(LUA_SRC_DIR):
	wget $(LUA_DL_URL)
	tar xf $(LUA_DL)
	$(RM) $(LUA_DL)
	mv $(LUA_NAME) c_src/
	cd $(C_SRC_DIR)/$(LUA_NAME) && patch -p1 -i $(C_SRC_DIR)/lua/lua.patch

$(LUA_BUILD_DIR):
	mkdir -p $(LUA_BUILD_DIR)

$(LUA_LIB): | $(LUA_BUILD_DIR) $(LUA_SRC_DIR)
	cd c_src/$(LUA_NAME) && make MYCFLAGS="$(CFLAGS) -fPIC -DLUA_COMPAT_5_2 -DLUA_COMPAT_5_1" MYLDFLAGS="$(LDFLAGS)" linux
	cd c_src/$(LUA_NAME) && make -e TO_LIB="liblua.a liblua.so liblua.so.$(LUA_VERSION)" INSTALL_DATA='cp -d' INSTALL_TOP=$(LUA_BUILD_DIR) INSTALL_MAN= INSTALL_LMOD= INSTALL_CMOD= install

lua_clean:
	cd $(LUA_SRC_DIR) && make clean

lua_fullclean: lua_clean
	$(RM) -r c_src/$(LUA_NAME)
	$(RM) -r $(LUA_BUILD_DIR)
