NIF := priv/build_calendar.so
# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR)

NIF_LDFLAGS += -fPIC -shared
NIF_CFLAGS ?= -fPIC -O2 -Wall

ifeq ($(ERL_EI_INCLUDE_DIR),)
$(warning ERL_EI_INCLUDE_DIR not set. Invoke via mix)
else

ALL += build_calendar
CLEAN += clean_build_calendar
PHONY += build_calendar clean_build_calendar
endif

build_calendar: $(NIF)

clean_build_calendar:
	$(RM) $(NIF)


$(NIF): c_src/build_calendar/build_calendar.c
	$(CC) $(ERL_CFLAGS) $(NIF_CFLAGS) $(ERL_LDFLAGS) $(NIF_LDFLAGS) -o $@ $<
