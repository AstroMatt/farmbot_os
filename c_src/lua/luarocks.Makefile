https://github.com/luarocks/luarocks/archive/v2.4.4.tar.gz
LUAROCKS_VERSION := 2.4.4
LUAROCKS_NAME := luarocks-$(LUAROCKS_VERSION)
LUAROCKS_DL := v$(LUAROCKS_VERSION).tar.gz
LUAROCKS_DL_URL := "https://github.com/luarocks/luarocks/archive/$(LUAROCKS_DL)"

LUAROCKS_DIR := $(C_SRC_DIR)/$(LUAROCKS_NAME)
LUAROCKS_BUILD_DIR := $(BUILD_DIR)/$(LUAROCKS_NAME)

LUAROCKS := $(LUAROCKS_BUILD_DIR)/bin/luarocks

LDFLAGS ?= -pthread
CFLAGS ?= -Wall -std=gnu99

ALL += $(LUAROCKS_BUILD_DIR) $(LUAROCKS)

$(LUAROCKS_DIR):
	wget $(LUAROCKS_DL_URL)
	tar xf $(LUAROCKS_DL)
	$(RM) $(LUAROCKS_DL)
	mv $(LUAROCKS_NAME) $(C_SRC_DIR)

$(LUAROCKS_BUILD_DIR):
	mkdir -p $(LUAROCKS_BUILD_DIR)

$(LUAROCKS): | $(LUAROCKS_BUILD_DIR) $(LUAROCKS_SRC_DIR)
	cd $(LUAROCKS_DIR) && ./configure --prefix=$(LUAROCKS_BUILD_DIR) --with-lua=$(LUA_BUILD_DIR) --with-downloader=wget --force-config && make build && make install

luarocks_clean:
	cd $(LUAROCKS_SRC_DIR) && make clean && make uninstall

luarocks_fullclean: lua_clean
	$(RM) -r $(C_SRC_DIR)/$(LUAROCKS_NAME)
	$(RM) -r $(LUAROCKS_BUILD_DIR)
