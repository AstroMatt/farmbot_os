ALL += $(PRIV)/celery_runtime

ifeq ($(LUAROCKS),)
$(error Luarocks not found or built)
endif

$(PRIV)/celery_runtime:
	cd $(C_SRC_DIR)/celery_runtime && $(LUAROCKS) make
