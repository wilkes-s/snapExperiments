
KERNEL_VERSION := linux-5.17
KERNEL_PATH :=$(PWD)/kernel/kernel-5.17
UBOOT_PATH :=$(PWD)/gadget/u-boot
ARCH=arm

clean-u-boot:
	rm -r -f $(UBOOT_PATH)	

u-boot-download: 
	if [ ! -f $(UBOOT_PATH)/Makefile ] ; then \
		cd gadget && git clone https://source.denx.de/u-boot/u-boot.git && \
		cp $(PWD)/devicetree/uboot* $(UBOOT_PATH)/ ; \
	fi
		
u-boot: u-boot-download
	cd $(UBOOT_PATH) && \
	CROSS_COMPILE=$(ARCH)-linux-gnueabihf- && \
	export CROSS_COMPILE && \
	make mx6ull_14x14_evk_defconfig && \
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
		cp $(PWD)/devicetree/*.dts $(KERNEL_PATH)/arch/$(ARCH)/boot/dts/ && \
		cd $(KERNEL_PATH)/ && patch -p1 < $(PWD)/devicetree/dts.patch ; \
	fi
		# cp $(PWD)/devicetree/$(DTS).patch $(KERNEL_PATH)/ && \

kernel: kernel-download	
	cp $(KERNEL_PATH)/arch/$(ARCH)/configs/imx_v6_v7_defconfig $(KERNEL_PATH)/.config
	cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=/usr/bin/$(ARCH)-linux-gnueabi- olddefconfig
	cd $(KERNEL_PATH) ;	make ARCH=$(ARCH) CROSS_COMPILE=/usr/bin/$(ARCH)-linux-gnueabi- -j8

	rm -rf $(KERNEL_PATH)/stage
	mkdir $(KERNEL_PATH)/stage
	mkdir $(KERNEL_PATH)/stage/dtb
	cp $(KERNEL_PATH)/arch/$(ARCH)/boot/dts/smarc_lcd.dtb $(KERNEL_PATH)/stage/dtb/
	cp $(KERNEL_PATH)/arch/$(ARCH)/boot/zImage $(KERNEL_PATH)/stage/


gadget-snap: u-boot
	cd gadget && snapcraft && \
	mv *.snap $(PWD)/a-sample-gadget.snap

kernel-snap: kernel
	cd kernel && snapcraft --debug && \
	mv *.snap $(PWD)/a-sample-kernel.snap

image: kernel-snap gadget-snap
	cat model.json | snap sign -k snapkey3 > model.model
	ubuntu-image snap model.model --snap ./a-sample-gadget.snap --snap ./a-sample-kernel.snap

clean: clean-kernel clean-u-boot
	
.PHONY: gadget kernel
	

