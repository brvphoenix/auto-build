#
# Copyright (C) 2007-2020 OpenWrt
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtorrent-rasterbar
PKG_VERSION:=1.2.10
PKG_RELEASE:=2

PKG_SOURCE_VERSION:=a9ea3c85b8ce47e140a5498b58df37d95e61a1b3
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/arvidn/libtorrent/tar.gz/$(PKG_SOURCE_VERSION)?
PKG_HASH:=365472f851ddaf35d87e744814b2099e7015d0eed8e206cc462543c8d8c7a550
PKG_BUILD_DIR:=$(BUILD_DIR)/libtorrent-$(PKG_SOURCE_VERSION)

PKG_LICENSE:=BSL-1.0
PKG_LICENSE_FILES:=LICENSE

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

ifneq ($(PKG_JOBS),-j1)
	PKG_JOBS:=-j2
endif

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk

define Package/$(PKG_NAME)
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Rasterbar BitTorrent library
  URL:=https://www.libtorrent.org
  DEPENDS:=+boost-system +libgcc +libopenssl +libstdcpp $(ICONV_DEPENDS)
endef

define Package/$(PKG_NAME)/description
  Rasterbar libtorrent is an open source C++ library implementing the BitTorrent
  protocol, along with most popular extensions, making it suitable for real world
  deployment. It is configurable to be able to fit both servers and embedded devices.
endef

TARGET_CFLAGS += -std=c++14 $(FPIC) -ffunction-sections -fdata-sections
TARGET_LDFLAGS += -Wl,--gc-sections,--as-needed

CONFIGURE_ARGS += \
	--enable-shared=yes \
	--enable-static=yes \
	--disable-debug \
	--disable-rpath \
	--enable-logging=no \
	--enable-encryption \
	--disable-deprecated-functions \
	--with-gnu-ld \
	--with-boost=$(STAGING_DIR)/usr \
	--with-libiconv \
	--with-libiconv-prefix=$(ICONV_PREFIX)

define Build/Prepare
	$(call Build/Prepare/Default)
	cd $(PKG_BUILD_DIR) && ./autotool.sh
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)
	$(CP) $(PKG_INSTALL_DIR)/* $(1)/
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))