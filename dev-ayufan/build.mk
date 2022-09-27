UBOOT_TMP_DIR ?= $(CURDIR)/tmp/u-boot-$(BOARD_TARGET)-build
UBOOT_OUTPUT_DIR ?= $(CURDIR)/tmp/u-boot-$(BOARD_TARGET)
UBOOT_MAKE ?= make KBUILD_OUTPUT=$(UBOOT_OUTPUT_DIR) BL31=$(realpath $(BL31)) \
	CROSS_COMPILE="ccache aarch64-linux-gnu-"

UBOOT_LOADERS ?= $(addprefix $(UBOOT_OUTPUT_DIR)/, $(addsuffix .img, $(LOADERS)))
UBOOT_TPL ?= $(UBOOT_OUTPUT_DIR)/tpl/u-boot-tpl.bin
UBOOT_SPL ?= $(UBOOT_OUTPUT_DIR)/spl/u-boot-spl.bin

tmp/u-boot-$(BOARD_TARGET)/.config: configs/$(UBOOT_DEFCONFIG)
	$(UBOOT_MAKE) $(UBOOT_DEFCONFIG)

$(UBOOT_OUTPUT_DIR):
	mkdir -p $@

$(UBOOT_OUTPUT_DIR)/u-boot.itb: .scmversion $(UBOOT_OUTPUT_DIR) tmp/u-boot-$(BOARD_TARGET)/.config $(BL31)
	$(UBOOT_MAKE) -j $$(nproc)
	$(UBOOT_MAKE) -j $$(nproc) u-boot.itb

$(UBOOT_TPL) $(UBOOT_SPL): $(UBOOT_OUTPUT_DIR)/u-boot.itb

$(UBOOT_OUTPUT_DIR)/rksd_loader.img: $(UBOOT_OUTPUT_DIR)/u-boot.itb $(UBOOT_TPL) $(UBOOT_SPL)
	$(UBOOT_OUTPUT_DIR)/tools/mkimage -n $(BOARD_CHIP) -T rksd -d $(word 1,$(UBOOT_TPL) $(UBOOT_SPL)) $@.tmp
ifneq (,$(UBOOT_TPL))
	cat $(UBOOT_SPL) >> $@.tmp
endif
	CUR_SIZE=$$(stat -c%s $@.tmp); MAX_SIZE=$$(((512-64)*512)); \
		[ $$CUR_SIZE -le $$MAX_SIZE ] || ( echo "Too big $$CUR_SIZE < $$MAX_SIZE" && exit 1 )
	dd if=$(UBOOT_OUTPUT_DIR)/u-boot.itb of=$@.tmp seek=$$((512-64)) conv=notrunc
	mv $@.tmp $@

$(UBOOT_OUTPUT_DIR)/rkspi_loader.img: $(UBOOT_OUTPUT_DIR)/u-boot.itb $(UBOOT_TPL) $(UBOOT_SPL)
	$(UBOOT_OUTPUT_DIR)/tools/mkimage -n $(BOARD_CHIP) -T rksd -d $(word 1,$(UBOOT_TPL) $(UBOOT_SPL)) $@.tmp
ifneq (,$(UBOOT_TPL))
	cat $(UBOOT_SPL) >> $@.tmp
endif
	@CUR_SIZE=$$(stat -c%s $@.tmp); MAX_SIZE=$$(((512-64)*512)); \
		[ $$CUR_SIZE -le $$MAX_SIZE ] || ( echo "Too big $$CUR_SIZE < $$MAX_SIZE" && exit 1 )
	# pad every 2k with 2k of zeros
	for i in $$(seq 1 $$((512/4))); do dd count=4 status=none; dd if=/dev/zero count=4 status=none; done < $@.tmp > $@.tmp2
	mv $@.tmp2 $@.tmp
	# We write at 1024 offset
	dd if=$(UBOOT_OUTPUT_DIR)/u-boot.itb of=$@.tmp seek=$$((512*2)) conv=notrunc
	mv $@.tmp $@

.PHONY: u-boot-menuconfig		# edit u-boot config and save as defconfig
u-boot-menuconfig:
	$(UBOOT_MAKE) ARCH=arm64 $(UBOOT_DEFCONFIG)
	$(UBOOT_MAKE) ARCH=arm64 menuconfig
	$(UBOOT_MAKE) ARCH=arm64 savedefconfig
	mv $(UBOOT_OUTPUT_DIR)/defconfig configs/$(UBOOT_DEFCONFIG)

.PHONY: u-boot-build		# compile u-boot
u-boot-build: $(UBOOT_LOADERS)

.PHONY: u-boot-clear
u-boot-clear:
	rm -rf $(UBOOT_OUTPUT_DIR)
	rm -rf $(UBOOT_TMP_DIR)

all: u-boot-build
