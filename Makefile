
KERNEL_VERSION := linux-5.17
KERNEL_PATH :=$(PWD)/kernel/kernel-5.17
UBOOT_PATH :=$(PWD)/gadget/u-boot

all: u-boot kernel
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

	rm -rf $(UBOOT_PATH)/stage
	mkdir $(UBOOT_PATH)/stage
	cp -r $(UBOOT_PATH)/tools $(UBOOT_PATH)/stage/
	cp $(UBOOT_PATH)/u-boot.bin $(UBOOT_PATH)/stage/
	cp $(UBOOT_PATH)/uboot.env.in $(UBOOT_PATH)/stage/

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


gadget: u-boot
	cd gadget && snapcraft --debug && \
	mv *.snap $(PWD)/a-sample-gadget.snap

# kernel-snap: linux-download
# 	cd kernel && snapcraft --debug && \
# 	mv *.snap $(PWD)/a-sample-kernel.snap

image:
	cat model.json | snap sign -k snapkey > model.model
	ubuntu-image snap model.model

QEMU:
	qemu-system-arm \
	-machine virt \
	-bios gadget/u-boot/u-boot.bin \
	-drive if=none,format=raw,file=pi.img,id=mydisk -device ich9-ahci,id=ahci -device ide-hd,drive=mydisk,bus=ahci.0

clean: clean-kernel clean-u-boot
	
.PHONY: gadget kernel
	

