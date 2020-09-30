define Build/Configure
	$(SED) 's;\(cd "\$$$$\w*\/qmake".*"\$$$$\w*"\);\1 "\-j$(NPROC)";g' $(PKG_BUILD_DIR)/configure
	$(call Build/Configure/Default)
endef
