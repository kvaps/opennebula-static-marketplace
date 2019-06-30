LIBGUESTFS_BACKEND = direct
LIBGUESTFS_MEMSIZE = 2048
IMAGES_DIR=public/images
CACHE_DIR=cache/images
TIMEZONE=UTC
gf=. $(CACHE_DIR)/guestfish_env && guestfish --remote

define gf_listen
	guestfish --listen --network > $(CACHE_DIR)/guestfish_env
endef

define create_empty_image
	$(call gf_listen)
	$(gf) disk-create "$(1)" qcow2 "$(2)"
	$(gf) add-drive "$(1)"
	$(gf) run
	$(gf) part-disk /dev/sda msdos
	$(gf) mkfs-opts ext4 /dev/sda1 features:^64bit
	$(gf) set-e2label /dev/sda1 cloudimg-rootfs
	$(gf) part-set-bootable /dev/sda 1 true
	$(gf) mount /dev/sda1 /
	$(gf) rm-rf /lost+found
	$(gf) umount-all
	$(gf) exit
endef

define copy_fs
	guestfish --ro -a "$(1)" -m "$(2)" -- tar-out "$(3)" - | \
		guestfish --rw -a "$(4)" -m "$(5)" -- tar-in - "$(6)"
endef

define create_alpine_image
	$(call gf_listen)
    $(gf) add-ro "$(1)"
    $(gf) disk-create "$(2)" qcow2 "$(3)"
    $(gf) add-drive "$(2)"
    $(gf) run
    $(gf) part-disk /dev/sdb msdos
    $(gf) mkfs-opts ext4 /dev/sdb1 features:^64bit
    $(gf) set-e2label /dev/sdb1 cloudimg-rootfs
    $(gf) part-set-bootable /dev/sdb 1 true
    $(gf) mount /dev/sda /
    $(gf) command "apk add --no-cache alpine-conf"
    $(gf) mount /dev/sdb1 /mnt
    $(gf) rm-rf /mnt/lost+found
    $(gf) mkdir /mnt/boot
    $(gf) command "setup-disk -k virt /mnt"
    $(gf) command "apk add --root /mnt e2fsprogs openssh tzdata"
    $(gf) write /mnt/etc/network/interfaces "$$(printf '%s\n' \
		'auto lo' \
		'iface lo inet loopback' \
	)"
    $(gf) write /mnt/etc/fstab "$$(printf '%s\n' \
		'LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,nodiratime        0 0' \
	)"
    $(gf) ln_s /etc/init.d/bootmisc /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/hostname /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/hwclock /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/modules /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/networking /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/swap /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/sysctl /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/syslog /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/urandom /mnt/etc/runlevels/boot/
    $(gf) ln_s /etc/init.d/killprocs /mnt/etc/runlevels/shutdown/
    $(gf) ln_s /etc/init.d/savecache /mnt/etc/runlevels/shutdown/
    $(gf) ln_s /etc/init.d/mount-ro /mnt/etc/runlevels/shutdown/
    $(gf) ln_s /etc/init.d/devfs /mnt/etc/runlevels/sysinit/
    $(gf) ln_s /etc/init.d/dmesg /mnt/etc/runlevels/sysinit/
    $(gf) ln_s /etc/init.d/hwdrivers /mnt/etc/runlevels/sysinit/
    $(gf) ln_s /etc/init.d/mdev /mnt/etc/runlevels/sysinit/
    $(gf) ln_s /etc/init.d/sshd /mnt/etc/runlevels/default/
    $(gf) ln_s "/usr/share/zoneinfo/$${TIMEZONE}" "/mnt/etc/localtime"
    $(gf) command "wget https://github.com/OpenNebula/addon-context-linux/releases/download/v5.8.0/one-context-5.8.0-r1.apk -O /one-context.apk"
    $(gf) command "apk add --root /mnt --allow-untrusted /one-context.apk"
    $(gf) rm_f "/one-context.apk"
    $(gf) sh "rm -rf /mnt/var/cache/apk/*"
    $(gf) command "sed -i 's/#\\?PermitRootLogin.*/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config"
    $(gf) umount-all
    $(gf) exit
endef

define create_centos6_image
    $(call create_empty_image,$(2),$(3))
	$(call copy_fs,$(1),/dev/sda1,/,$(2),/dev/sda1,/)
	$(call gf_listen)
	$(gf) add-drive "$(1)"
	$(gf) run
	$(gf) mount /dev/sda1 /
    $(gf) write /etc/fstab "$$(printf '%s\n' \
		'LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,nodiratime        0 0' \
	)"
    $(gf) write /etc/mtab "$$(printf '%s\n' \
		'/dev/sda1 / ext4 rw 0 0' \
	)"
    $(gf) write /boot/grub/device.map "$$(printf '%s\n' \
		'(fd0)   /dev/fd0' \
		'(hd0)   /dev/sda' \
	)"
	$(gf) command "grub-install /dev/sda"
	$(gf) command "sed -i 's/root=[^ ]\\+/root=UUID=$$($(gf) get-uuid /dev/sda1)/g' /boot/grub/grub.conf"
	$(gf) command "sed -i '/^\\(terminal\\|serial\\)/d' /boot/grub/grub.conf"
	$(gf) ln_sf "/usr/share/zoneinfo/$${TIMEZONE}" "/etc/localtime"
	$(gf) command "curl -L https://github.com/OpenNebula/addon-context-linux/releases/download/v5.8.0/one-context-5.8.0-1.el6.noarch.rpm -o /one-context.rpm"
	$(gf) command "yum install -y epel-release"
	$(gf) command "yum install -y /one-context.rpm"
	$(gf) rm_f "/one-context.rpm"
	$(gf) command "yum clean all"
	$(gf) command "sed -i '/^SELINUX=/ s/=.*/=disabled/g' /etc/selinux/config"
	$(gf) command "sed -i 's/#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
	$(gf) umount-all
	$(gf) exit
endef

define create_centos7_image
    $(call create_empty_image,$(2),$(3))
	$(call copy_fs,$(1),/dev/sda1,/,$(2),/dev/sda1,/)
	$(call gf_listen)
	$(gf) add-drive "$(1)"
	$(gf) run
	$(gf) mount /dev/sda1 /
    $(gf) write /etc/fstab "$$(printf '%s\n' \
		'LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,nodiratime        0 0' \
	)"
	$(gf) command "grub2-install /dev/sda"
	$(gf) command "grub2-mkconfig -o /boot/grub2/grub.cfg"
	$(gf) ln_sf "/usr/share/zoneinfo/$${TIMEZONE}" "/etc/localtime"
	$(gf) command "curl -L https://github.com/OpenNebula/addon-context-linux/releases/download/v5.8.0/one-context-5.8.0-1.el7.noarch.rpm -o /one-context.rpm"
	$(gf) command "yum install -y epel-release"
	$(gf) command "yum install -y /one-context.rpm"
	$(gf) rm_f "/one-context.rpm"
	$(gf) command "yum clean all"
	$(gf) command "sed -i '/^SELINUX=/ s/=.*/=disabled/g' /etc/selinux/config"
	$(gf) command "sed -i 's/#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
	$(gf) umount-all
	$(gf) exit
endef

define create_fedora_image
    $(call create_empty_image,$(2),$(3))
	$(call copy_fs,$(1),/dev/sda1,/,$(2),/dev/sda1,/)
	$(call gf_listen)
	$(gf) add-drive "$(1)"
	$(gf) run
	$(gf) mount /dev/sda1 /
    $(gf) write /etc/fstab "$$(printf '%s\n' \
		'LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,nodiratime        0 0' \
	)"
	$(gf) command "grub2-install /dev/sda"
	$(gf) command "grub2-mkconfig -o /boot/grub2/grub.cfg"
	$(gf) ln_sf "/usr/share/zoneinfo/$${TIMEZONE}" "/etc/localtime"
	$(gf) command "curl -L https://github.com/OpenNebula/addon-context-linux/releases/download/v5.8.0/one-context-5.8.0-1.el7.noarch.rpm -o /one-context.rpm"
	$(gf) command "yum install -y /one-context.rpm network-scripts"
	$(gf) rm_f "/one-context.rpm"
	$(gf) command "yum clean all"
	$(gf) command "sed -i '/^SELINUX=/ s/=.*/=disabled/g' /etc/selinux/config"
	$(gf) command "sed -i 's/#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
	$(gf) umount-all
	$(gf) exit
endef



.PHONY: all site server clean clean-cache

all: site

site:
	hugo -s src/hugo/ -d ../../public

server:
	hugo -s src/hugo/ -d ../../public server

$(CACHE_DIR):
	mkdir -p $(CACHE_DIR)
$(IMAGES_DIR):
	mkdir -p $(IMAGES_DIR)

clean: clean-cache
	rm -rf public
clean-cache:
	rm -rf cache

IMAGES := $(wildcard *.qcow2)
images:



### Alpine 3.10
$(CACHE_DIR)/alpine-minirootfs-%-x86_64.tar.gz: $(CACHE_DIR)
	curl -Lo "$@" "https://alpine.global.ssl.fastly.net/alpine/v3.10/releases/x86_64/$(notdir $@)"
$(CACHE_DIR)/alpine-minirootfs-%-x86_64.qcow2: $(CACHE_DIR)/alpine-minirootfs-%-x86_64.tar.gz
	virt-make-fs -s +50M -F qcow2 "$(basename $@).tar.gz" "$@"
$(IMAGES_DIR)/alpine-3.10.qcow2: $(CACHE_DIR)/alpine-minirootfs-3.10.0-x86_64.qcow2 $(IMAGES_DIR) 
	$(call create_alpine_image,$<,$@,500M)

### Centos 6
$(CACHE_DIR)/CentOS-6-x86_64-GenericCloud.qcow2c: $(CACHE_DIR)
	curl -Lo "$@" "https://cloud.centos.org/centos/6/images/$(notdir $@)"
$(IMAGES_DIR)/centos-6.qcow2: $(CACHE_DIR)/CentOS-6-x86_64-GenericCloud.qcow2c $(IMAGES_DIR) 
	$(call create_centos6_image,$<,$@,2G)

### Centos 7
$(CACHE_DIR)/CentOS-7-x86_64-GenericCloud.qcow2c: $(CACHE_DIR)
	curl -Lo "$@" "https://cloud.centos.org/centos/7/images/$(notdir $@)"
$(IMAGES_DIR)/centos-7.qcow2: $(CACHE_DIR)/CentOS-7-x86_64-GenericCloud.qcow2c $(IMAGES_DIR) 
	$(call create_centos7_image,$<,$@,2G)

### Fedora 30
$(CACHE_DIR)/Fedora-Cloud-Base-30-1.2.x86_64.qcow2: $(CACHE_DIR)
	curl -Lo "$@" "https://download.fedoraproject.org/pub/fedora/linux/releases/30/Cloud/x86_64/images/$(notdir $@)"
$(IMAGES_DIR)/fedora-30.qcow2: $(CACHE_DIR)/Fedora-Cloud-Base-30-1.2.x86_64.qcow2 $(IMAGES_DIR) 
	$(call create_fedora_image,$<,$@,2G)

### Debian 9
$(CACHE_DIR)/debian-%-openstack-amd64.qcow2: $(CACHE_DIR)
	curl -Lo "$@" "https://cdimage.debian.org/cdimage/openstack/current/$(notdir $@)"
$(IMAGES_DIR)/debian-9.qcow2: $(CACHE_DIR)/debian-%-openstack-amd64.qcow2 $(IMAGES_DIR) 
	$(call create_debian_image,$<,$@,2G)

### Ubuntu 16.04
$(CACHE_DIR)/xenial-server-cloudimg-amd64.img: $(CACHE_DIR)
	curl -Lo "$@" "https://cloud-images.ubuntu.com/xenial/current/$(notdir $@)"
$(IMAGES_DIR)/ubuntu-16.04.qcow2: $(CACHE_DIR)/xenial-server-cloudimg-amd64.img $(IMAGES_DIR) 
	$(call create_ubuntu_image,$<,$@,2G)

### Ubuntu 18.04
$(CACHE_DIR)/bionic-server-cloudimg-amd64.img: $(CACHE_DIR)
	curl -Lo "$@" "https://cloud-images.ubuntu.com/bionic/current/$(notdir $@)"
$(IMAGES_DIR)/ubuntu-18.04.qcow2: $(CACHE_DIR)/bionic-server-cloudimg-amd64.img $(IMAGES_DIR) 
	$(call create_ubuntu_image,$<,$@,2G)

### Devuan 2
$(CACHE_DIR)/devuan_ascii_%_amd64_qemu.qcow2.xz: $(CACHE_DIR)
	curl -Lo "$@" "https://mirror.leaseweb.com/devuan/devuan_ascii/virtual/$(notdir $@)"
$(CACHE_DIR)/devuan_ascii_%_amd64_qemu.qcow2: $(CACHE_DIR)/devuan_ascii_%_amd64_qemu.qcow2.xz
	xz --decompress  "$@.xz"
$(IMAGES_DIR)/devuan-2.qcow2: $(CACHE_DIR)/devuan_ascii_2.0.0_amd64_qemu.qcow2 $(IMAGES_DIR) 
	$(call create_debian_image,$<,$@,2G)
