ALL += $(PRIV)/celery_runtime

$(PRIV)/celery_runtime:
	cd $(C_SRC_DIR)/celery_runtime && $(LUAROCKS) make
