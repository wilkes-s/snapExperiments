
KERNEL_VERSION := linux-5.17
KERNEL_PATH :=$(PWD)/kernel/kernel-5.17
UBOOT_PATH :=$(PWD)/gadget/u-boot
DEFCONFIG := rpi_3_b_plus_defconfig
COMPILER := aarch64-linux-gnu-
ARCH := arm64
SDPATH := /media/wss1tra/4CFC-C3D7


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
	cd $(UBOOT_PATH) && make ARCH=arm CROSS_COMPILE=$(COMPILER) $(DEFCONFIG)
	cd $(UBOOT_PATH) && make ARCH=arm CROSS_COMPILE=$(COMPILER) -j8

	# rm -rf $(UBOOT_PATH)/boot-assets
	# mkdir $(UBOOT_PATH)/boot-assets
	# cp -r $(UBOOT_PATH)/tools $(UBOOT_PATH)/boot-assets/
	# cp $(UBOOT_PATH)/u-boot.bin $(UBOOT_PATH)/boot-assets/
	# cp $(UBOOT_PATH)/uboot.env.in $(UBOOT_PATH)/boot-assets/

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
# cp $(KERNEL_PATH)/arch/arm/configs/imx_v6_v7_defconfig $(KERNEL_PATH)/.config
# cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=$(COMPILER) olddefconfig
	
	cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=$(COMPILER) defconfig
	cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=$(COMPILER) -j8

	# rm -rf $(KERNEL_PATH)/stage
	# mkdir $(KERNEL_PATH)/stage
	# mkdir $(KERNEL_PATH)/stage/dtb
	# cp $(KERNEL_PATH)/arch/arm/boot/dts/imx6q-qemu-arm.dtb $(KERNEL_PATH)/arch/arm/boot/dts/smarc_lcd.dtb $(KERNEL_PATH)/stage/dtb/
	# cp $(KERNEL_PATH)/arch/arm/boot/zImage $(KERNEL_PATH)/stage/


# kernel-snap: linux-download
# 	cd kernel && snapcraft --debug && \
# 	mv *.snap $(PWD)/a-sample-kernel.snap

firmware: 
	if [ ! -f firmware-master/README.md ] ; then \
		wget https://github.com/raspberrypi/firmware/archive/master.zip && \
		unzip master.zip ; \
	fi

format:
	sudo sfdisk /dev/sdb < rpilayout # where sda is your SD card
	sudo mkfs.vfat /dev/sdb1

image:
	cp $(UBOOT_PATH)/u-boot.bin  $(SDPATH)/kernel8.img
	cp $(KERNEL_PATH)/arch/arm64/boot/Image $(SDPATH)/
	cp $(KERNEL_PATH)/arch/arm64/boot/dts/broadcom/bcm2837-rpi-3-b-plus.dtb $(SDPATH)/
	cp config.txt $(SDPATH)/
	cp firmware-master/boot/{fixup.dat,start.elf,bootcode.bin} $(SDPATH)/
	sudo dd if=buildroot-2020.02.8/output/images/rootfs.ext4 of=/dev/sdb2




install:
	sudo apt install git qemu-system-arm gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi build-essential bison flex libssl-dev tree bc -y
	export PATH=~/tools/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin:$PATH

clean: clean-kernel clean-u-boot
	rm *.img
	rm *.snap


buildroot:
	if [ ! -f buildroot-2020.02.8/Makefile ] ; then \
		wget https://buildroot.org/downloads/buildroot-2020.02.8.tar.gz && \
		tar -xf buildroot-2020.02.8.tar.gz ; \
	fi

	cd buildroot-2020.02.8 && make raspberrypi4_64_defconfig && make

RASPBERRY: u-boot kernel buildroot firmware image
	


	
.PHONY: gadget kernel
	

