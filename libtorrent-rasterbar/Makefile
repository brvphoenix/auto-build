#
# Copyright (C) 2007-2020 OpenWrt
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtorrent-rasterbar
PKG_VERSION:=1.2.5
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=3185b627ef36c5c2a8aa25f2f829ef874b2b6587
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/arvidn/libtorrent/tar.gz/$(PKG_SOURCE_VERSION)?
PKG_HASH:=9fe73b173fe4e766d7e56433c9c16be21e12df49f6c025f96b5b64cb22a9eb94
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

define Package/libtorrent-rasterbar
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Rasterbar BitTorrent library
  URL:=https://www.libtorrent.org
  DEPENDS:=+boost-system +libopenssl +libstdcpp
endef

define Package/libtorrent-rasterbar/description
  Rasterbar libtorrent is an open source C++ library implementing the BitTorrent
  protocol, along with most popular extensions, making it suitable for real world
  deployment. It is configurable to be able to fit both servers and embedded devices.
endef

TARGET_CXXFLAGS += -std=c++14 $(FPIC) -ffunction-sections -fdata-sections
TARGET_LDFLAGS += -Wl,--gc-sections,--as-needed

CONFIGURE_ARGS += \
	--enable-shared=yes \
	--enable-static=yes \
	--disable-debug \
	--disable-rpath \
	--enable-logging=no \
	--enable-encryption \
	--enable-deprecated-functions \
	--with-gnu-ld  \
	--with-boost=$(STAGING_DIR)/usr

define Build/Prepare
	$(call Build/Prepare/Default)
	cd $(PKG_BUILD_DIR) && ./autotool.sh
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)
	$(CP) $(PKG_INSTALL_DIR)/* $(1)/
endef

define Package/libtorrent-rasterbar/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libtorrent-rasterbar))
