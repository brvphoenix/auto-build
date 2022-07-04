#
# Copyright (C) 2007-2021
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtorrent-rasterbar
PKG_VERSION:=1.2.16
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-RC_1_2.tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/arvidn/libtorrent/tar.gz/RC_1_2?
PKG_HASH:=skip
PKG_BUILD_DIR:=$(BUILD_DIR)/libtorrent-RC_1_2

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE
PKG_CPE_ID:=cpe:/a:libtorrent:libtorrent

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk

define Package/$(PKG_NAME)
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=C++ bittorrent library by Rasterbar Software
  URL:=https://www.libtorrent.org
  DEPENDS:=+boost +boost-system +libgcc +libopenssl +libstdcpp $(ICONV_DEPENDS)
  ABI_VERSION:=10
endef

define Package/$(PKG_NAME)/description
  Libtorrent is a feature complete C++ bittorrent implementation focusing on
  efficiency and scalability. It runs on embedded devices as well as desktops.
  It boasts a well documented library interface that is easy to use.
endef

TARGET_CFLAGS += $(FPIC) -ffunction-sections -fdata-sections
TARGET_LDFLAGS += -Wl,--gc-sections,--as-needed

CONFIGURE_ARGS += \
	--enable-shared=yes \
	--enable-static=yes \
	--disable-debug \
	--disable-rpath \
	--enable-logging=no \
	--enable-encryption \
	--disable-deprecated-functions \
	--with-cxx-standard=17 \
	--with-gnu-ld \
	--with-boost=$(STAGING_DIR)/usr \
	--with-libiconv

define Build/Prepare
	$(call Build/Prepare/Default)
	cd $(PKG_BUILD_DIR) && ./autotool.sh
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)
	$(CP) $(PKG_INSTALL_DIR)/* $(1)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.so* $(1)/usr/lib
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
