
KERNEL_VERSION := linux-5.17
KERNEL_PATH :=$(PWD)/kernel/kernel-5.17
UBOOT_PATH :=$(PWD)/gadget/u-boot
STAGE := ../stage
ARCH=arm

all: clean kernel-snap gadget-snap image

partition: gadget-snap image

image:
	cat model.json | snap sign -k snapkey4 > model.model 
	ubuntu-image snap model.model --snap ./a-sample-gadget.snap --snap ./a-sample-kernel.snap --snap ./core20_1409.snap --snap ./snapd_15540.snap

prepare: kernel-download u-boot-download
	- mkdir -p $(KERNEL_PATH)/$(STAGE)/dtb
	- mkdir -p $(UBOOT_PATH)/$(STAGE)/dtb
	rsync devicetree/msc-sm2s-imx6ull-Y2-93N02E1I-800x480-lvds.dtb $(KERNEL_PATH)/$(STAGE)/dtb/
	rsync devicetree/msc-sm2s-imx6ull-Y2-93N02E1I-800x480-lvds.dtb $(UBOOT_PATH)/$(STAGE)/dtb/
	rsync $(PWD)/devicetree/initrd.img $(UBOOT_PATH)/$(STAGE)/

	if [ ! -f snapd_15540.snap ] ; then \
		UBUNTU_STORE_ARCH=armhf snap download snapd && rm snapd_15540.assert ; \
	fi
	if [ ! -f core20_1409.snap ] ; then \
		UBUNTU_STORE_ARCH=armhf snap download core20 && rm core20_1409.assert ; \
	fi




u-boot-download: 
	if [ ! -f $(UBOOT_PATH)/Makefile ] ; then \
		cd gadget && git clone https://source.denx.de/u-boot/u-boot.git && \
		cp $(PWD)/devicetree/uboot* $(UBOOT_PATH)/ ; \
	fi
		
u-boot: u-boot-download prepare
	cd $(UBOOT_PATH) && make CROSS_COMPILE=$(ARCH)-linux-gnueabihf- mx6ull_14x14_evk_defconfig 
	cd $(UBOOT_PATH) && make CROSS_COMPILE=$(ARCH)-linux-gnueabihf- -j8

	rsync -r --size-only $(UBOOT_PATH)/tools $(UBOOT_PATH)/$(STAGE)/
	rsync --size-only $(UBOOT_PATH)/u-boot $(UBOOT_PATH)/$(STAGE)/
	rsync --size-only $(UBOOT_PATH)/u-boot.bin $(UBOOT_PATH)/$(STAGE)/
	rsync --size-only $(UBOOT_PATH)/uboot.env.in $(UBOOT_PATH)/$(STAGE)/




kernel-download:
	if [ ! -f $(KERNEL_PATH)/Makefile ] ; then \
		wget https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KERNEL_VERSION).tar.xz && \
		tar xvf $(KERNEL_VERSION).tar.xz && \
		rm $(KERNEL_VERSION).tar.xz && \
		mv $(KERNEL_VERSION) $(KERNEL_PATH) && \
		cp $(PWD)/devicetree/*.dts $(KERNEL_PATH)/arch/$(ARCH)/boot/dts/ && \
		cd $(KERNEL_PATH)/ && patch -p1 < $(PWD)/devicetree/dts.patch ; \
	fi

kernel: kernel-download	prepare
	cp -u $(KERNEL_PATH)/arch/$(ARCH)/configs/imx_v6_v7_defconfig $(KERNEL_PATH)/.config
	cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=/usr/bin/$(ARCH)-linux-gnueabi- olddefconfig
	cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=/usr/bin/$(ARCH)-linux-gnueabi- -j8

	rsync --size-only $(KERNEL_PATH)/arch/$(ARCH)/boot/dts/smarc_lcd.dtb $(KERNEL_PATH)/$(STAGE)/dtb/
	rsync --size-only $(KERNEL_PATH)/arch/$(ARCH)/boot/zImage $(KERNEL_PATH)/$(STAGE)/

	rsync --size-only $(KERNEL_PATH)/$(STAGE)/zImage $(UBOOT_PATH)/$(STAGE)/




gadget-snap: u-boot kernel
	cd gadget && snapcraft && \
	mv *.snap $(PWD)/a-sample-gadget.snap
	multipass stop --all

kernel-snap: kernel
	cd kernel && snapcraft && \
	mv *.snap $(PWD)/a-sample-kernel.snap
	multipass stop --all





install:
	sudo apt update && sudo apt -y upgrade 
	sudo apt -y install build-essential gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi 
	sudo apt -y install bison flex libssl-dev tree bc lzop
	sudo apt -y install snapcraft
	sudo snap install multipass
	sudo snap install ubuntu-image --classic

clean: clean-kernel clean-u-boot
	-rm aSample.img
	-rm seed.manifest
	-rm model.model

clean-kernel:	
	-rm a-sample-kernel.snap
	-rm -rf $(KERNEL_PATH)/$(STAGE)/

clean-u-boot:
	-rm a-sample-gadget.snap
	-rm -rf $(UBOOT_PATH)/$(STAGE)

clean-all: clean
	-rm -rf $(KERNEL_PATH)
	-rm -rf $(UBOOT_PATH)
	-rm *.snap


.PHONY: gadget kernel
	

