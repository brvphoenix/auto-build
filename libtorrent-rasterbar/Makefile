#
# Copyright (C) 2007-2020 OpenWrt
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtorrent-rasterbar
PKG_VERSION:=1.2.10
PKG_RELEASE:=3

PKG_SOURCE:=$(PKG_NAME)-RC_1_2.tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/arvidn/libtorrent/tar.gz/RC_1_2?
PKG_HASH:=skip
PKG_BUILD_DIR:=$(BUILD_DIR)/libtorrent-RC_1_2

PKG_LICENSE:=BSL-1.0
PKG_LICENSE_FILES:=LICENSE

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=python3
PKG_USE_MIPS16:=0

ifneq ($(PKG_JOBS),-j1)
	PKG_JOBS:=-j2
endif

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/nls.mk
include $(TOPDIR)/feeds/packages/lang/python/python3-version.mk

define Package/$(PKG_NAME)
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Rasterbar BitTorrent library
  URL:=https://www.libtorrent.org
  DEPENDS:=+boost +boost-system +libgcc +libopenssl +libstdcpp $(ICONV_DEPENDS)
endef

define Package/$(PKG_NAME)/description
  Rasterbar libtorrent is an open source C++ library implementing the BitTorrent
  protocol, along with most popular extensions, making it suitable for real world
  deployment. It is configurable to be able to fit both servers and embedded devices.
endef

define Package/python-libtorrent
  $(call Package/$(PKG_NAME))
  TITLE:=Rasterbar BitTorrent library for Python
  DEPENDS:=+boost-python3 +libopenssl +libtorrent-rasterbar +python3
endef

define Package/python-libtorrent/description
  $(call Package/$(PKG_NAME)/description)
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
	--with-cxx-standard=14 \
	--with-gnu-ld \
	--with-boost=$(STAGING_DIR)/usr \
	--with-libiconv \
	--with-libiconv-prefix=$(ICONV_PREFIX)

ifdef CONFIG_PACKAGE_python-libtorrent
CONFIGURE_ARGS += \
	--enable-python-binding \
	PYTHON=$(STAGING_DIR_HOSTPKG)/bin/python3 \
	PYTHON_CPPFLAGS=-I$(STAGING_DIR)/usr/include/python$(PYTHON3_VERSION)
endif

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

define Package/python-libtorrent/install
	$(INSTALL_DIR) $(1)/usr/lib/python$(PYTHON3_VERSION)/site-packages
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/python$(PYTHON3_VERSION)/site-packages/*.so* $(1)/usr/lib/python$(PYTHON3_VERSION)/site-packages
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
$(eval $(call BuildPackage,python-libtorrent,+boost-python3,+libopenssl,+libtorrent-rasterbar))
