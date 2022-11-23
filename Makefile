.SILENT:
define HEADER
__________  _________________   ____________________.____     
\______   \/   _____/\_____  \  \______   \______   \    |    
 |     ___/\_____  \  /  ____/   |    |  _/|    |  _/    |    
 |    |    /        \/       \   |    |   \|    |   \    |___ 
 |____|   /_______  /\_______ \  |______  /|______  /_______ \\
                  \/         \/         \/        \/        \/
		PlayStation2 Basic BootLoader - By El_isra
endef
export HEADER


# ---{BUILD CFG}--- #

PSX ?= 0 # PSX DESR support
HAS_EMBEDDED_IRX ?= 0 # whether to embed or not non vital IRX (wich will be loaded from memcard files)
PROHBIT_DVD_0100 ?= 0 # prohibit the DVD Players v1.00 and v1.01 from being booted.
XCDVD_READKEY ?= 0 # Enable the newer sceCdReadKey checks, which are only supported by a newer CDVDMAN module.

# Related to binary size reduction
KERNEL_NOPATCH ?= 1 
NEWLIB_NANO ?= 1
DUMMY_TIMEZONE ?= 1
DUMMY_LIBC_INIT ?= 1
# ---{ EXECUTABLES }--- #

BINDIR ?= bin/
BASENAME ?= PS2BBL
EE_BIN = $(BINDIR)$(BASENAME).ELF
EE_BIN_STRIPPED = $(BINDIR)stripped_$(BASENAME).ELF
EE_BIN_PACKED = $(BINDIR)COMPRESSED_$(BASENAME).ELF

# ---{ OBJECTS & STUFF }--- #

EE_OBJS_DIR = obj/
EE_SRC_DIR = src/
EE_ASM_DIR = asm/

IOP_OBJS = sio2man_irx.o mcman_irx.o mcserv_irx.o padman_irx.o
EE_OBJS = main.o \
          pad.o util.o elf.o timer.o ps2.o ps1.o dvdplayer.o \
          modelname.o libcdvd_add.o OSDHistory.o OSDInit.o OSDConfig.o \
          $(EMBEDDED_STUFF)

EMBEDDED_STUFF = icon_sys_A.o icon_sys_J.o icon_sys_C.o \
		loader_elf.o \
		$(IOP_OBJS)

EE_CFLAGS = -Os -DNEWLIB_PORT_AWARE -G0 -Wall -g
EE_CFLAGS += -fdata-sections -ffunction-sections
# EE_LDFLAGS += -nodefaultlibs -Wl,--start-group -lc_nano -lps2sdkc -lkernel-nopatch -Wl,--end-group
EE_LDFLAGS += -s
EE_LDFLAGS += -Wl,--gc-sections -Wno-sign-compare
EE_LIBS = -ldebug -lc -lmc -lpadx -lpatches -lkernel
EE_INCS += -Iinclude

# ---{ CONDITIONS }--- #

ifeq ($(PSX),1)
	EE_CFLAGS += -DPSX=1
	EE_OBJS += scmd_add.o ioprp.o
	EE_LIBS += -lxcdvd -liopreboot
else
	EE_LIBS += -lcdvd
endif

ifeq ($(DEBUG), 1)
   EE_CFLAGS += -DDEBUG
endif

ifeq ($(DUMMY_TIMEZONE), 1)
   EE_CFLAGS += -DDUMMY_TIMEZONE
endif

ifeq ($(HAS_EMBEDDED_IRX),1)
	IOP_OBJS += usbd.o bdm_irx.o bdmfs_fatfs_irx.o usbmass_bd_irx.o
	EE_CFLAGS += -DHAS_EMBEDDED_IRX
endif

ifdef COMMIT_HASH
    EE_CFLAGS += -DCOMMIT_HASH=\"$(COMMIT_HASH)\"
else
    EE_CFLAGS += -DCOMMIT_HASH=\"UNKNOWN\"
endif

ifeq ($(DUMMY_LIBC_INIT), 1)
   EE_CFLAGS += -DDUMMY_LIBC_INIT
endif

ifeq ($(XCDVD_READKEY),1)
	EE_CFLAGS += -DXCDVD_READKEY=1
endif

ifeq ($(PROHBIT_DVD_0100),1)
	EE_CFLAGS += -DPROHBIT_DVD_0100=1
endif

# ---{ RECIPES }--- #

all:
	$(MAKE) $(EE_BIN)

greeting:
	@echo built PS2BBL PSX=$(PSX), EMBEDDED_IRX=$(HAS_EMBEDDED_IRX)
	@echo PROHBIT_DVD_0100=$(PROHBIT_DVD_0100), XCDVD_READKEY=$(XCDVD_READKEY)
	@echo KERNEL_NOPATCH=$(KERNEL_NOPATCH), NEWLIB_NANO=$(NEWLIB_NANO)
	@echo binaries dispatched to $(BINDIR)

release: clean
	$(MAKE) $(EE_BIN_PACKED)
	$(MAKE) greeting
	@echo "$$HEADER"

clean:
	@echo cleaning...
	@echo - Objects
	@rm -rf $(EE_OBJS)
	@echo - Objects folders 
	@rm -rf $(EE_OBJS_DIR) $(EE_ASM_DIR) $(BINDIR)
	@echo -- ELF loader
	$(MAKE) -C modules/ELF_LOADER/ clean
	@echo  "\n\n\n"

cleaniop:
	@echo cleaning only embedded IOP binaries
	rm -rf $(IOP_OBJS)

$(EE_BIN_STRIPPED): $(EE_BIN)
	@echo " -- Stripping"
	$(EE_STRIP) -o $@ $<

$(EE_BIN_PACKED): $(EE_BIN_STRIPPED)
	@echo " -- Compressing"
	ps2-packer $< $@ > /dev/null

modules/ELF_LOADER/loader.elf: modules/ELF_LOADER/
	@echo -- ELF Loader
	$(MAKE) -C $<

# move OBJ to folder and search source on src/, borrowed from OPL makefile

EE_OBJS := $(EE_OBJS:%=$(EE_OBJS_DIR)%) # remap all EE_OBJ to obj subdir

$(EE_OBJS_DIR):
	@mkdir -p $@

$(EE_ASM_DIR):
	@mkdir -p $@

$(BINDIR):
	@mkdir -p $@

$(EE_OBJS_DIR)%.o: $(EE_SRC_DIR)%.c | $(EE_OBJS_DIR)
	@echo "  - $@"
	@$(EE_CC) $(EE_CFLAGS) $(EE_INCS) -c $< -o $@

$(EE_OBJS_DIR)%.o: $(EE_ASM_DIR)%.s | $(EE_OBJS_DIR)
	@echo "  - $@"
	@$(EE_AS) $(EE_ASFLAGS) $< -o $@
#

celan: clean #repetitive typo that i have when quicktyping

# Include makefiles
include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal
include embed.make
