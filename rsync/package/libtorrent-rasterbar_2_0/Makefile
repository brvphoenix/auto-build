#
# Copyright (C) 2007-2021
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtorrent-rasterbar
PKG_VERSION:=2.0.6
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/arvidn/libtorrent.git
PKG_SOURCE_VERSION:=b075fdf76e337b3a5f0f3266ec10294c94906668
PKG_SOURCE_DATE:=2021-05-16
PKG_MIRROR_HASH:=d40ef4ede135b3377ebe1cb390a40fd61d1579f35550c139e185657600e0869c

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=COPYING
PKG_CPE_ID:=cpe:/a:libtorrent:libtorrent

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk
# include $(TOPDIR)/feeds/packages/lang/python/python3-package.mk

define Package/libtorrent-rasterbar
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=C++ bittorrent library by Rasterbar Software
  URL:=https://www.libtorrent.org
  DEPENDS:=+boost +boost-system +libatomic +libgcc +libopenssl +libstdcpp
  ABI_VERSION:=2.0
endef

#define Package/python3-libtorrent
#  $(call Package/libtorrent-rasterbar)
#  TITLE:=Python bindings for libtorrent-rasterbar
#  DEPENDS+=+PACKAGE_python3-libtorrent:boost-python3 +libtorrent-rasterbar
#endef

define Package/libtorrent-rasterbar/description
  Libtorrent is a feature complete C++ bittorrent implementation focusing on
  efficiency and scalability. It runs on embedded devices as well as desktops.
  It boasts a well documented library interface that is easy to use.
endef

#define Package/python3-libtorrent/description
#  Building the libtorrent python bindings will produce a shared library which
#  is a python module that can be imported in a python program.
#endef

TARGET_CFLAGS += $(FPIC) -ffunction-sections -fdata-sections -flto
TARGET_LDFLAGS += -Wl,--gc-sections,--as-needed -flto

CMAKE_OPTIONS += \
	-DBUILD_SHARED_LIBS=ON \
	-DCMAKE_BUILD_TYPE=Release \
	-Ddeprecated-functions=OFF \
	-Dlogging=OFF \
	-DCMAKE_CXX_STANDARD=17 \
	-Dpython-bindings=$(if $(CONFIG_PACKAGE_python3-libtorrent),ON,OFF) \
	-Dpython-egg-info=$(if $(CONFIG_PACKAGE_python3-libtorrent),ON,OFF)

define Build/InstallDev
	$(INSTALL_DIR) $(1)
	$(CP) $(PKG_INSTALL_DIR)/* $(1)
endef

define Package/libtorrent-rasterbar/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libtorrent-rasterbar.so.* $(1)/usr/lib
endef

#define Package/python3-libtorrent/install
#	$(INSTALL_DIR) $(1)/usr/lib/python$(PYTHON3_VERSION)/site-packages
#	$(CP) $(PKG_INSTALL_DIR)/usr/lib/python$(PYTHON3_VERSION)/site-packages/*.so* $(1)/usr/lib/python$(PYTHON3_VERSION)/site-packages/
#endef

$(eval $(call BuildPackage,libtorrent-rasterbar))
#$(eval $(call BuildPackage,python3-libtorrent))
