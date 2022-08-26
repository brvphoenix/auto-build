@echo OFF
setlocal

set BUILD_DIR=%cd%
set BASE_DIR=%BUILD_DIR%\base
set PREFIX=%BASE_DIR%\usr
set PATH=%PREFIX%\bin;%BASE_DIR%\myperl\perl\site\bin;%BASE_DIR%\myperl\perl\bin;%BASE_DIR%\myperl\c\bin;%BASE_DIR%\7z;%PATH%
set BUILD_DIR_UNIX=%cd:\=/%
set BASE_DIR_UNIX=%BUILD_DIR_UNIX%/base
set PREFIX_UNIX=%BASE_DIR_UNIX%/usr

:: Create the needed folders
mkdir %BASE_DIR% %PREFIX% %PREFIX%\bin %BASE_DIR%\myperl %BASE_DIR%\7z %BUILD_DIR%\qt6

:: Download and install 7z
set _7z_ver=2201
CALL :Download "7z%_7z_ver%-x64.exe" "https://www.7-zip.org/a"
CALL 7z%_7z_ver%-x64.exe /S /D="%BASE_DIR%\7z"

:: Download and unpack jom
set _jom_ver=1_1_3
CALL :Download "jom_%_jom_ver%.zip" "https://download.qt.io/official_releases/jom"
7z x -mmt%NUMBER_OF_PROCESSORS% -o"%PREFIX%\bin" -spe -aos -y -- "jom_%_jom_ver%.zip"

:: Download and unpack perl
set _perl_ver=5.32.1.1
CALL :Download "strawberry-perl-%_perl_ver%-64bit-portable.zip" "https://strawberryperl.com/download/%_perl_ver%"
7z x -mmt%NUMBER_OF_PROCESSORS% -o"%BASE_DIR%\myperl" -spe -aos -y -- "strawberry-perl-%_perl_ver%-64bit-portable.zip"

:: Download and unpack nasm
set _nasm_ver=2.15.05
CALL :Download "nasm-%_nasm_ver%-win64.zip" "https://www.nasm.us/pub/nasm/releasebuilds/%_nasm_ver%/win64"
7z x -mmt%NUMBER_OF_PROCESSORS% -spe -aos -y -- "nasm-%_nasm_ver%-win64.zip"
robocopy /move /e "nasm-%_nasm_ver%" "%PREFIX%\bin"
IF EXIST "nasm-%_nasm_ver%" ( RMDIR /Q /S "nasm-%_nasm_ver%" )

:: Download and unpack zlib
set _zlib_ver=1.2.12
CALL :Download "zlib-%_zlib_ver%.tar.gz" "https://zlib.net"

echo %BUILD_DIR%
7z x -tgzip -mmt%NUMBER_OF_PROCESSORS% -so -- "zlib-%_zlib_ver%.tar.gz" | 7z x -ttar -si -aos -y -o"%BUILD_DIR%"

:: Compiling Zlib
cd /d "%BUILD_DIR%\zlib-%_zlib_ver%"
powershell -Command "& { (Get-Content 'win32/Makefile.msc') | ForEach-Object { $_ -replace '^CFLAGS(.*) -MD (.*)', 'CFLAGS$1 -MT $2 /FS' } |  Set-Content 'win32/Makefile.msc' }"

jom -f win32/Makefile.msc -j %NUMBER_OF_PROCESSORS%

xcopy /Y zlib.h %PREFIX%\include\
xcopy /Y zconf.h %PREFIX%\include\
xcopy /Y zlib.lib %PREFIX%\lib\

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\zlib-%_zlib_ver%" ( RMDIR /Q /S "%BUILD_DIR%\zlib-%_zlib_ver%" )

:: Download and unpack openssl
set _openssl_ver=3.0.5
CALL :Download "openssl-%_openssl_ver%.tar.gz" "https://www.openssl.org/source"
7z x -tgzip -mmt%NUMBER_OF_PROCESSORS% -so -- "openssl-%_openssl_ver%.tar.gz" | 7z x -ttar -si -aos -y -o"%BUILD_DIR%"

:: Compiling OpenSSL
cd /d "%BUILD_DIR%\openssl-%_openssl_ver%"
perl Configure VC-WIN64A no-shared no-zlib no-zlib-dynamic threads --release --openssldir=C:\openssl --prefix=%PREFIX% -I%PREFIX%\include -L%PREFIX%\lib --with-zlib-lib=%PREFIX%\lib\zlib.lib
powershell -Command "& { (Get-Content 'makefile') | ForEach-Object { $_ -replace '/debug', '/debug /opt:ref /opt:icf /incremental:no' } |  Set-Content 'makefile' }"
powershell -Command "& { (Get-Content 'makefile') | ForEach-Object { $_ -replace '^CFLAGS=(.*)', 'CFLAGS=$1 -Gy -Gw -GL /FS' } |  Set-Content 'makefile' }"

jom build_libs -j %NUMBER_OF_PROCESSORS%
jom install_dev

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\openssl-%_openssl_ver%" ( RMDIR /Q /S "%BUILD_DIR%\openssl-%_openssl_ver%" )

:: Download and unpack boost
set _boost_major_ver=1
set _boost_middle_ver=80
set _boost_minor_ver=0
set _boost_ver=%_boost_major_ver%.%_boost_middle_ver%.%_boost_minor_ver%
set _boost_ver_sub=%_boost_major_ver%_%_boost_middle_ver%_%_boost_minor_ver%
CALL :Download "boost_%_boost_ver_sub%.tar.bz2" "https://boostorg.jfrog.io/artifactory/main/release/%_boost_ver%/source"
7z x -tBZip2 -mmt%NUMBER_OF_PROCESSORS% -so -- "boost_%_boost_ver_sub%.tar.bz2" | 7z x -ttar -si -aos -y -o"%BUILD_DIR%"

:: Compiling Boost
cd /d "%BUILD_DIR%\boost_%_boost_ver_sub%"
CALL bootstrap.bat

b2 -q --with-system --with-date_time --toolset=msvc-14.2 address-model=64 variant=release link=static runtime-link=static include=%PREFIX%\include library-path=%PREFIX%\lib --prefix=%PREFIX% cxxflags="-O1 -Gy -Gw -GL" linkflags="/NOLOGO /DYNAMICBASE /NXCOMPAT /LTCG /OPT:REF /OPT:ICF=5 /MANIFEST:EMBED /INCREMENTAL:NO" --hash install -j %NUMBER_OF_PROCESSORS%

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\boost_%_boost_ver_sub%" ( RMDIR /Q /S "%BUILD_DIR%\boost_%_boost_ver_sub%" )

:: Download and unpack libtorrent-rasterbar
set _libt_ver=2.0.7
CALL :Download "libtorrent-rasterbar-%_libt_ver%.tar.gz" "https://github.com/arvidn/libtorrent/releases/download/v%_libt_ver%"
7z x -tgzip -mmt%NUMBER_OF_PROCESSORS% -so -- "libtorrent-rasterbar-%_libt_ver%.tar.gz" | 7z x -ttar -si -aos -y -o"%BUILD_DIR%"

:: Compiling Libtorrent
cd /d "%BUILD_DIR%\libtorrent-rasterbar-%_libt_ver%"

cmake -S . ^
	-DCMAKE_C_COMPILER=cl ^
	-DCMAKE_CXX_COMPILER=cl ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DCMAKE_GENERATOR="Ninja" ^
	-DCMAKE_CXX_FLAGS=/guard:cf ^
	-DCMAKE_INSTALL_PREFIX=%PREFIX_UNIX% ^
	-DCMAKE_FIND_ROOT_PATH=%PREFIX_UNIX% ^
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=BOTH ^
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY ^
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY ^
	-DBUILD_SHARED_LIBS=OFF ^
	-Dstatic_runtime=ON ^
	-DCMAKE_BUILD_TYPE=Release ^
	-Ddeprecated-functions=OFF ^
	-Dlogging=OFF ^
	-DCMAKE_CXX_STANDARD=17

ninja -C . install

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\libtorrent-rasterbar-%_libt_ver%" ( RMDIR /Q /S "%BUILD_DIR%\libtorrent-rasterbar-%_libt_ver%" )

:: Download and unpack QT6
mkdir %BUILD_DIR%\qt6
set _qt_major_ver=6.3
set _qt_minor_ver=1
set _qt_ver=%_qt_major_ver%.%_qt_minor_ver%
for %%q in (qtbase qttools qtsvg) do (
	CALL :Download "%%q-everywhere-src-%_qt_ver%.tar.xz" "https://download.qt.io/official_releases/qt/%_qt_major_ver%/%_qt_ver%/submodules"
	7z x -txz -mmt%NUMBER_OF_PROCESSORS% -so -- "%%q-everywhere-src-%_qt_ver%.tar.xz" | 7z x -ttar -si -aos -y -o"%BUILD_DIR%\qt6"
)

:: Compiling Qt6
:: Compiling qtbase
cd /d "%BUILD_DIR%\qt6\qtbase-everywhere-src-%_qt_ver%"

cmake -S . ^
	-DCMAKE_C_COMPILER=cl ^
	-DCMAKE_CXX_COMPILER=cl ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DCMAKE_INSTALL_PREFIX=%PREFIX_UNIX% ^
	-DQT_EXTRA_INCLUDEPATHS=%PREFIX_UNIX%/include ^
	-DQT_EXTRA_LIBDIRS=%PREFIX_UNIX%/lib ^
	-DQT_QMAKE_TARGET_MKSPEC=win32-msvc ^
	-DBUILD_SHARED_LIBS=OFF ^
	-DFEATURE_static_runtime=ON ^
	-DFEATURE_optimize_size=ON ^
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON ^
	-DCMAKE_SKIP_RPATH=TRUE ^
	-DFEATURE_system_zlib=ON ^
	-DFEATURE_cups=OFF ^
	-DFEATURE_dbus=OFF ^
	-DFEATURE_libudev=OFF ^
	-DFEATURE_widgets=ON ^
	-DFEATURE_zstd=OFF ^
	-DFEATURE_concurrent=OFF ^
	-DFEATURE_testlib=OFF ^
	-DQT_BUILD_EXAMPLES=OFF ^
	-DQT_BUILD_TESTS=OFF ^
	-DFEATURE_system_doubleconversion=OFF ^
	-DFEATURE_system_pcre2=OFF ^
	-DFEATURE_mimetype_database=ON ^
	-DFEATURE_glib=OFF ^
	-DFEATURE_icu=OFF ^
	-DFEATURE_gui=ON ^
	-DFEATURE_gbm=OFF ^
	-DFEATURE_harfbuzz=ON ^
	-DFEATURE_jpeg=OFF ^
	-DFEATURE_png=ON ^
	-DFEATURE_system_png=OFF ^
	-DFEATURE_mtdev=OFF ^
	-DINPUT_opengl=no ^
	-DFEATURE_tslib=OFF ^
	-DFEATURE_xcb=OFF ^
	-DFEATURE_xcb_xlib=OFF ^
	-DFEATURE_xkbcommon=OFF ^
	-DINPUT_openssl=linked ^
	-DFEATURE_libproxy=OFF ^
	-DFEATURE_gssapi=OFF ^
	-DFEATURE_sql=ON ^
	-DFEATURE_system_sqlite=OFF ^
	-DFEATURE_sql_db2=OFF ^
	-DFEATURE_sql_ibase=OFF ^
	-DFEATURE_sql_mysql=OFF ^
	-DFEATURE_sql_oci=OFF ^
	-DFEATURE_sql_odbc=OFF ^
	-DFEATURE_sql_psql=OFF ^
	-DFEATURE_androiddeployqt=OFF ^
	-DCMAKE_GENERATOR="Ninja"

ninja -C . install

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\qt6\qtbase-everywhere-src-%_qt_ver%" ( RMDIR /Q /S "%BUILD_DIR%\qt6\qtbase-everywhere-src-%_qt_ver%" )

:: Compiling qttools
cd /d "%BUILD_DIR%\qt6\qttools-everywhere-src-%_qt_ver%"

CALL qt-configure-module . ^
	-no-feature-assistant ^
	-no-feature-clang ^
	-no-feature-clangcpp ^
	-no-feature-distancefieldgenerator ^
	-no-feature-kmap2qmap ^
	-no-feature-pixeltool ^
	-no-feature-qdbus ^
	-no-feature-qev ^
	-no-feature-qtattributionsscanner ^
	-no-feature-qtdiag ^
	-no-feature-qtplugininfo ^
	-- ^
	-DCMAKE_DISABLE_FIND_PACKAGE_Clang=TRUE ^
	-DCMAKE_DISABLE_FIND_PACKAGE_WrapLibClang=TRUE

ninja -C . install

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\qt6\qttools-everywhere-src-%_qt_ver%" ( RMDIR /Q /S "%BUILD_DIR%\qt6\qttools-everywhere-src-%_qt_ver%" )

:: Compiling qtsvg
cd /d "%BUILD_DIR%\qt6\qtsvg-everywhere-src-%_qt_ver%"

CALL qt-configure-module .

ninja -C . install

cd "%BUILD_DIR%"

IF EXIST "%BUILD_DIR%\qt6\qtsvg-everywhere-src-%_qt_ver%" ( RMDIR /Q /S "%BUILD_DIR%\qt6\qtsvg-everywhere-src-%_qt_ver%" )

:: Download and unpack qbittorrent
set _qbt_ver=4.4.4
CALL :Download "qbittorrent-%_qbt_ver%.tar.gz" "https://codeload.github.com/qbittorrent/qBittorrent/tar.gz/refs/tags/release-%_qbt_ver%?"
7z x -tgzip -mmt%NUMBER_OF_PROCESSORS% -so -- "qbittorrent-%_qbt_ver%.tar.gz" | 7z x -ttar -si -aos -y -o"%BUILD_DIR%"

:: Compile qbittorrent
cd /d "%BUILD_DIR%\qBittorrent-release-%_qbt_ver%"

cmake -S . ^
	-DCMAKE_C_COMPILER=cl ^
	-DCMAKE_CXX_COMPILER=cl ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DCMAKE_GENERATOR="Ninja" ^
	-DCMAKE_INSTALL_PREFIX=%PREFIX_UNIX% ^
	-DCMAKE_FIND_ROOT_PATH=%PREFIX_UNIX% ^
	-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=BOTH ^
	-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY ^
	-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY ^
	-DBUILD_STATIC=ON ^
	-DMSVC_RUNTIME_DYNAMIC=OFF ^
	-DSTACKTRACE=ON ^
	-DWEBUI=ON ^
	-DGUI=ON ^
	-DVERBOSE_CONFIGURE=ON ^
	-DQT6=ON

ninja -C . install
cd "%BUILD_DIR%"

@echo ON
EXIT /B %ERRORLEVEL%

:Download
echo filename is %~1%
echo site at %~2%
echo Download URL is "%~2/%~1"
IF not exist "%~1" (
	curl -kLZ -C - -o "%~1" "%~2/%~1"
)
EXIT /B 0
