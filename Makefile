
KERNEL_VERSION := linux-5.17
KERNEL_PATH :=$(PWD)/kernel/kernel-5.17
UBOOT_PATH :=$(PWD)/gadget/u-boot

all: install image
rebuild: clean all

clean-u-boot:
	rm -r -f $(UBOOT_PATH)	

u-boot-download: 
	if [ ! -f $(UBOOT_PATH)/Makefile ] ; then \
		cd gadget && git clone https://source.denx.de/u-boot/u-boot.git && \
		cp $(PWD)/devicetree/uboot* $(UBOOT_PATH)/ ; \
	fi
		
u-boot: u-boot-download
	cd $(UBOOT_PATH) && \
	CROSS_COMPILE=arm-linux-gnueabihf- && \
	export CROSS_COMPILE && \
	make qemu_arm_defconfig && \
    make -j8

	rm -rf $(UBOOT_PATH)/boot-assets
	mkdir $(UBOOT_PATH)/boot-assets
	cp -r $(UBOOT_PATH)/tools $(UBOOT_PATH)/boot-assets/
	cp $(UBOOT_PATH)/u-boot.bin $(UBOOT_PATH)/boot-assets/
	cp $(UBOOT_PATH)/uboot.env.in $(UBOOT_PATH)/boot-assets/

gadget: u-boot
	cd gadget && snapcraft && \
	mv *.snap $(PWD)/a-sample-gadget.snap

	rm -r squashfs-root
	unsquashfs a-sample-gadget.snap
	tree squashfs-root

clean-kernel:
	rm -r -f $(KERNEL_PATH)

kernel-download:
	if [ ! -f $(KERNEL_PATH)/Makefile ] ; then \
		wget https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KERNEL_VERSION).tar.xz && \
		tar xvf $(KERNEL_VERSION).tar.xz && \
		rm $(KERNEL_VERSION).tar.xz && \
		mv $(KERNEL_VERSION) $(KERNEL_PATH) && \
		cp $(PWD)/devicetree/*.dts $(KERNEL_PATH)/arch/arm/boot/dts/ && \
		cd $(KERNEL_PATH)/ && patch -p1 < $(PWD)/devicetree/dts.patch ; \
	fi
		# cp $(PWD)/devicetree/$(DTS).patch $(KERNEL_PATH)/ && \

kernel: kernel-download	
	cp $(KERNEL_PATH)/arch/arm/configs/imx_v6_v7_defconfig $(KERNEL_PATH)/.config
	cd $(KERNEL_PATH) ;	make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- olddefconfig
	cd $(KERNEL_PATH) ;	make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- -j8

	rm -rf $(KERNEL_PATH)/stage
	mkdir $(KERNEL_PATH)/stage
	mkdir $(KERNEL_PATH)/stage/dtb
	cp $(KERNEL_PATH)/arch/arm/boot/dts/imx6q-qemu-arm.dtb $(KERNEL_PATH)/arch/arm/boot/dts/smarc_lcd.dtb $(KERNEL_PATH)/stage/dtb/
	cp $(KERNEL_PATH)/arch/arm/boot/zImage $(KERNEL_PATH)/stage/


# kernel-snap: linux-download
# 	cd kernel && snapcraft --debug && \
# 	mv *.snap $(PWD)/a-sample-kernel.snap

image:
	cat model.json | snap sign -k snapkey2 > model.model
	ubuntu-image snap model.model --snap ./a-sample-gadget.snap

flash:
	umount

QEMU:
	qemu-system-arm \
	-machine raspi2 \
	-device sdhci-pci -device sd-card,drive=mydrive -drive id=mydrive,if=none,format=raw,file=pi.img
	# -drive if=none,format=raw,file=pi.img,id=mydisk -device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0
	# -bios gadget/u-boot/u-boot.bin \

install:
	sudo apt install git qemu-system-arm gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi build-essential bison flex libssl-dev tree bc -y

clean: clean-kernel clean-u-boot
	rm *.img
	rm *.snap
	
.PHONY: gadget kernel
	

