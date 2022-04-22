
KERNEL_VERSION := linux-5.17
KERNEL_PATH :=$(PWD)/kernel/kernel-5.17
UBOOT_PATH :=$(PWD)/gadget/u-boot
ARCH=arm

clean-u-boot:
	rm -r -f $(UBOOT_PATH)
	rm -f a-sample-gadget.snap	

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
	cp $(UBOOT_PATH)/u-boot $(UBOOT_PATH)/stage/
	cp $(UBOOT_PATH)/uboot.env.in $(UBOOT_PATH)/stage/

clean-kernel:
	rm -r -f $(KERNEL_PATH)
	rm -f a-sample-kernel.snap

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
	multipass stop --all

kernel-snap: kernel
	cd kernel && snapcraft && \
	mv *.snap $(PWD)/a-sample-kernel.snap
	multipass stop --all

image: gadget-snap kernel-snap 
	if [ ! -f snapd_15540.snap ] ; then \
		UBUNTU_STORE_ARCH=armhf snap download snapd && rm snapd_15540.assert ; \
	fi
	if [ ! -f core20_1409.snap ] ; then \
		UBUNTU_STORE_ARCH=armhf snap download core20 && rm core20_1409.assert ; \
	fi
	cat model.json | snap sign -k snapkey4 > model.model 
	ubuntu-image snap model.model --snap ./a-sample-gadget.snap --snap ./a-sample-kernel.snap --snap ./core20_1409.snap --snap ./snapd_15540.snap

clean: clean-kernel clean-u-boot
	rm -f aSample.img
	rm -f seed.manifest
	rm -fr squashfs-root
	rm -f *.snap
	rm -f model.model

install:
	sudo apt update && sudo apt -y upgrade 
	sudo apt -y install build-essential gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi 
	sudo apt -y install bison flex libssl-dev tree bc lzop
	sudo apt -y install snapcraft
	sudo snap install multipass
	sudo snap install ubuntu-image --classic

	
.PHONY: gadget kernel
	

