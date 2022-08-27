@ECHO OFF
SETLOCAL

SET BASE_DIR=%CD%
SET BUILD_DIR=%BASE_DIR%\build
SET DL_DIR=%BASE_DIR%\dl
SET STAGE_DIR=%BASE_DIR%\stage
SET PREFIX=%STAGE_DIR%\usr
SET BASE_DIR_UNIX=%CD:\=/%
SET STAGE_DIR_UNIX=%BASE_DIR_UNIX%/stage
SET PREFIX_UNIX=%STAGE_DIR_UNIX%/usr
SET PATH=%PREFIX%\bin;%STAGE_DIR%\myperl\perl\site\bin;%STAGE_DIR%\myperl\perl\bin;%STAGE_DIR%\myperl\c\bin;%STAGE_DIR%\7z;%PATH%

:: Create the needed folders
CALL :MKDIRS "%BUILD_DIR%" "%DL_DIR%" "%STAGE_DIR%" "%PREFIX%" "%PREFIX%\bin" "%STAGE_DIR%\myperl" "%STAGE_DIR%\7z"

:: Download and install 7z
SET _7z_ver=2201
CALL :DOWNLOAD "7z%_7z_ver%-x64.exe" "https://www.7-zip.org/a"
CALL "%DL_DIR%\7z%_7z_ver%-x64.exe" /S /D="%STAGE_DIR%\7z"
IF ERRORLEVEL 1 ( EXIT /B %ERRORLEVEL% )

:: Download and unpack jom
SET _jom_ver=1_1_3
CALL :DOWNLOAD "jom_%_jom_ver%.zip" "https://download.qt.io/official_releases/jom" "%PREFIX%\bin"
IF ERRORLEVEL 1 ( EXIT /B %ERRORLEVEL% )

:: Download and unpack perl
SET _perl_ver=5.32.1.1
CALL :DOWNLOAD "strawberry-perl-%_perl_ver%-64bit-portable.zip" "https://strawberryperl.com/download/%_perl_ver%" "%STAGE_DIR%\myperl"
IF ERRORLEVEL 1 ( EXIT /B %ERRORLEVEL% )

:: Download and unpack nasm
SET _nasm_ver=2.15.05
CALL :DOWNLOAD "nasm-%_nasm_ver%-win64.zip" "https://www.nasm.us/pub/nasm/releasebuilds/%_nasm_ver%/win64" "%PREFIX%"
IF ERRORLEVEL 1 ( EXIT /B %ERRORLEVEL% )
ROBOCOPY /MOVE /E /XX /NDL /NFL /NJH /NJS "%PREFIX%\nasm-%_nasm_ver%" "%PREFIX%\bin"
IF EXIST "%PREFIX%\nasm-%_nasm_ver%" ( RMDIR /Q /S "%PREFIX%\nasm-%_nasm_ver%" )

:: Download and unpack git
SET _git_main_version=2.37.3
SET _git_sub_version=1
SET _git_version=%_git_main_version%.%_git_sub_version%
CALL :DOWNLOAD "PortableGit-%_git_main_version%-64-bit.7z.exe" "https://github.com/git-for-windows/git/releases/download/v%_git_main_version%.windows.%_git_sub_version%" "%STAGE_DIR%\git"
IF ERRORLEVEL 1 ( EXIT /B %ERRORLEVEL% )

:: Download and unpack zlib
SETLOCAL
SET _zlib_ver=1.2.12
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\zlib-%_zlib_ver%

CALL :DOWNLOAD "zlib-%_zlib_ver%.tar.gz" "https://zlib.net" "%BUILD_DIR%"

:: Compiling Zlib
CD /D "%PKG_BUILD_DIR%"
powershell -Command "& { (Get-Content 'win32/Makefile.msc') | ForEach-Object { $_ -replace '(^CFLAGS.*) -MD (.*)', '$1 -MT $2' } |  Set-Content 'win32/Makefile.msc' }"
powershell -Command "& { (Get-Content 'win32/Makefile.msc') | ForEach-Object { $_ -replace '(^LDFLAGS.*)', '$1 /OPT:ICF=5 /LTCG' } |  Set-Content 'win32/Makefile.msc' }"

jom -f win32/Makefile.msc LOC="/Gy /Gw /GL /FS" -j %NUMBER_OF_PROCESSORS%

XCOPY /Y zlib.h "%PREFIX%\include\"
XCOPY /Y zconf.h "%PREFIX%\include\"
XCOPY /Y zlib.lib "%PREFIX%\lib\"

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack openssl
SETLOCAL
SET _openssl_ver=3.0.5
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\openssl-%_openssl_ver%

CALL :DOWNLOAD "openssl-%_openssl_ver%.tar.gz" "https://www.openssl.org/source" "%BUILD_DIR%"

:: Compiling OpenSSL
CD /D "%PKG_BUILD_DIR%"
perl Configure VC-WIN64A no-shared no-zlib no-zlib-dynamic threads --release --openssldir=C:\openssl --prefix="%PREFIX%" -I"%PREFIX%\include" -L"%PREFIX%\lib" --with-zlib-lib="%PREFIX%\lib\zlib.lib"
powershell -Command "& { (Get-Content 'makefile') | ForEach-Object { $_ -replace '^CFLAGS=(.*)', 'CFLAGS=$1 /Gy /Gw /GL /FS' } |  Set-Content 'makefile' }"
powershell -Command "& { (Get-Content 'makefile') | ForEach-Object { $_ -replace '/debug', '/debug /LTCG /opt:ref /opt:icf /incremental:no' } |  Set-Content 'makefile' }"

jom build_libs -j %NUMBER_OF_PROCESSORS%
jom install_dev

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack boost
SETLOCAL
SET _boost_major_ver=1
SET _boost_middle_ver=80
SET _boost_minor_ver=0
SET _boost_ver=%_boost_major_ver%.%_boost_middle_ver%.%_boost_minor_ver%
SET _boost_ver_sub=%_boost_major_ver%_%_boost_middle_ver%_%_boost_minor_ver%
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\boost_%_boost_ver_sub%

CALL :DOWNLOAD "boost_%_boost_ver_sub%.tar.bz2" "https://boostorg.jfrog.io/artifactory/main/release/%_boost_ver%/source" "%BUILD_DIR%"

:: Compiling Boost
CD /D "%PKG_BUILD_DIR%"
CALL bootstrap.bat

b2 -q ^
	--prefix="%PREFIX%" ^
	--with-system ^
	--with-date_time ^
	--toolset=msvc-14.3 ^
	address-model=64 ^
	variant=release ^
	link=static ^
	runtime-link=static ^
	include="%PREFIX%\include" ^
	library-path="%PREFIX%\lib" ^
	cxxflags="/O2 /Gy /Gw /GL" ^
	linkflags="/NOLOGO /DYNAMICBASE /NXCOMPAT /LTCG /OPT:REF /OPT:ICF=5 /MANIFEST:EMBED /INCREMENTAL:NO" ^
	--hash install ^
	-j %NUMBER_OF_PROCESSORS%

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack libtorrent-rasterbar
SETLOCAL
SET _libt_ver=2.0.7
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\libtorrent-rasterbar-%_libt_ver%

CALL :DOWNLOAD "libtorrent-rasterbar-%_libt_ver%.tar.gz" "https://github.com/arvidn/libtorrent/releases/download/v%_libt_ver%" "%BUILD_DIR%"

:: Compiling Libtorrent
CD /D "%PKG_BUILD_DIR%"

cmake -S . ^
	-DCMAKE_C_COMPILER=cl ^
	-DCMAKE_CXX_COMPILER=cl ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DCMAKE_GENERATOR="Ninja" ^
	-DCMAKE_CXX_FLAGS="/guard:cf /O2 /Gy /Gw /GL /FS" ^
	-DCMAKE_INSTALL_PREFIX="%PREFIX_UNIX%" ^
	-DCMAKE_FIND_ROOT_PATH="%PREFIX_UNIX%" ^
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

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack qtbase
SETLOCAL
SET _qt_major_ver=6.3
SET _qt_minor_ver=1
SET _qt_ver=%_qt_major_ver%.%_qt_minor_ver%
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\qtbase-everywhere-src-%_qt_ver%

CALL :DOWNLOAD "qtbase-everywhere-src-%_qt_ver%.tar.xz" "https://download.qt.io/official_releases/qt/%_qt_major_ver%/%_qt_ver%/submodules" "%BUILD_DIR%"

:: Compiling qtbase
CD /D "%PKG_BUILD_DIR%"

cmake -S . ^
	-DCMAKE_C_COMPILER=cl ^
	-DCMAKE_CXX_COMPILER=cl ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DCMAKE_INSTALL_PREFIX="%PREFIX_UNIX%" ^
	-DQT_EXTRA_INCLUDEPATHS="%PREFIX_UNIX%/include" ^
	-DQT_EXTRA_LIBDIRS="%PREFIX_UNIX%/lib" ^
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

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack qttools
SETLOCAL
SET _qt_major_ver=6.3
SET _qt_minor_ver=1
SET _qt_ver=%_qt_major_ver%.%_qt_minor_ver%
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\qttools-everywhere-src-%_qt_ver%

CALL :DOWNLOAD "qttools-everywhere-src-%_qt_ver%.tar.xz" "https://download.qt.io/official_releases/qt/%_qt_major_ver%/%_qt_ver%/submodules" "%BUILD_DIR%"

CD /D "%PKG_BUILD_DIR%"

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
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON ^
	-DCMAKE_DISABLE_FIND_PACKAGE_Clang=TRUE ^
	-DCMAKE_DISABLE_FIND_PACKAGE_WrapLibClang=TRUE

ninja -C . install

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack qtsvg
SETLOCAL
SET _qt_major_ver=6.3
SET _qt_minor_ver=1
SET _qt_ver=%_qt_major_ver%.%_qt_minor_ver%
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\qtsvg-everywhere-src-%_qt_ver%

CALL :DOWNLOAD "qtsvg-everywhere-src-%_qt_ver%.tar.xz" "https://download.qt.io/official_releases/qt/%_qt_major_ver%/%_qt_ver%/submodules" "%BUILD_DIR%"

CD /D "%PKG_BUILD_DIR%"

CALL qt-configure-module . -- -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

ninja -C . install

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%PKG_BUILD_DIR%" ( RMDIR /Q /S "%PKG_BUILD_DIR%" ) )
ENDLOCAL

:: Download and unpack qbittorrent
SETLOCAL
SET _qbt_ver=4.4.5
SET PKG_BUILD=1
SET PKG_BUILD_DIR=%BUILD_DIR%\qtsvg-everywhere-src-%_qt_ver%

CALL :DOWNLOAD "qbittorrent-%_qbt_ver%.tar.gz" "https://codeload.github.com/qbittorrent/qBittorrent/tar.gz/refs/tags/release-%_qbt_ver%?" "%BUILD_DIR%"

:: Compile qbittorrent
CD /D "%BUILD_DIR%\qBittorrent-release-%_qbt_ver%"

cmake -S . ^
	-DCMAKE_C_COMPILER=cl ^
	-DCMAKE_CXX_COMPILER=cl ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DCMAKE_GENERATOR="Ninja" ^
	-DCMAKE_CXX_FLAGS="/guard:cf /O2 /Gy /Gw /GL" ^
	-DCMAKE_EXE_LINKER_FLAGS:STRING="/NOLOGO /DYNAMICBASE /NXCOMPAT /LTCG /OPT:REF /OPT:ICF /INCREMENTAL:NO" ^
	-DCMAKE_INSTALL_PREFIX="%PREFIX_UNIX%" ^
	-DCMAKE_FIND_ROOT_PATH="%PREFIX_UNIX%" ^
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

CD "%BASE_DIR%"
IF "%AUTO_REMOVE%" == "1" ( IF EXIST "%BUILD_DIR%\qBittorrent-release-%_qbt_ver%" ( RMDIR /Q /S "%BUILD_DIR%\qBittorrent-release-%_qbt_ver%" ) )
ENDLOCAL

@ECHO ON

EXIT /B %ERRORLEVEL%

:MKDIRS
	SET INDEX=%1
	IF %INDEX%! == ! GOTO :EOF
	IF NOT EXIST "%INDEX%" (
		ECHO Create directory: "%INDEX%"
		MKDIR "%INDEX%"
	)
	SHIFT
	GOTO MKDIRS
GOTO :EOF

:DOWNLOAD
SETLOCAL ENABLEDELAYEDEXPANSION

IF "%~1" == "" (
    ECHO "Error: file name is empty" & EXIT /B 110
) ELSE (
    SET FILENAME=%~1
    ECHO **********************************************************************
    ECHO **********************************************************************
    ECHO **
    ECHO **                !FILENAME!
    ECHO **
    ECHO *********************************************************************
    ECHO *********************************************************************
    ECHO Filename is: !FILENAME!
)
IF "%~2" == "" (
    ECHO "Error: URL is empty" & EXIT /B 110
) ELSE (
    SET SITE_URL=%~2
    SET DOWNLOAD_URL=%~2/%FILENAME%
    ECHO Download URL is: !DOWNLOAD_URL!
)

IF NOT EXIST "%DL_DIR%\%FILENAME%" (
	curl -kLZ -C - -o "%DL_DIR%\%FILENAME%" "%DOWNLOAD_URL%"
)

IF "%~3" == "" (
    ECHO "Warning: extracting path is empty and skip the extracting."
    GOTO :EOF
) ELSE (
    SET EXTRACT_DIR=%~3
    ECHO Extract to: "!EXTRACT_DIR!"
)

IF NOT ERRORLEVEL 1 (
    CALL :CAN_FIND 7z.exe || ( GOTO FINISH )
    IF EXIST "%PKG_BUILD_DIR%" ( IF EXIST "%PKG_BUILD_DIR%\.unpack" GOTO PATCH )
    FOR /F %%f IN ('ECHO %FILENAME% ^| FINDSTR ".*\.tar\.bz2\>"')  DO (
        7z x -tbzip2 -mmt%NUMBER_OF_PROCESSORS% -so -- "%DL_DIR%\%%f" | 7z x -ttar -mmt%NUMBER_OF_PROCESSORS% -si -aos -y -o"%EXTRACT_DIR%"
        GOTO PATCH
    )
    FOR /F %%f IN ('ECHO %FILENAME% ^| FINDSTR ".*\.tar\.gz\> .*\.tgz\>"')  DO (
        7z x -tgzip -mmt%NUMBER_OF_PROCESSORS% -so -- "%DL_DIR%\%%f" | 7z x -ttar -mmt%NUMBER_OF_PROCESSORS% -si -aos -y -o"%EXTRACT_DIR%"
        GOTO PATCH
    )
    FOR /F %%f IN ('ECHO %FILENAME% ^| FINDSTR ".*\.tar\.xz\>"')  DO (
        7z x -txz -mmt%NUMBER_OF_PROCESSORS% -so -- "%DL_DIR%\%%f" | 7z x -ttar -mmt%NUMBER_OF_PROCESSORS% -si -aos -y -o"%EXTRACT_DIR%"
        GOTO PATCH
    )
    7z x -mmt%NUMBER_OF_PROCESSORS% -spe -aos -y -o"%EXTRACT_DIR%" -- "%DL_DIR%\%FILENAME%"
    GOTO PATCH
)
GOTO FINISH

:PATCH
IF ERRORLEVEL 1 ( GOTO FINISH )
IF NOT "%PKG_BUILD%" == "1" ( GOTO FINISH )
IF EXIST "%PKG_BUILD_DIR%" ( IF NOT EXIST "%PKG_BUILD_DIR%\.unpack" ( ECHO=>"%PKG_BUILD_DIR%\.unpack" ) )
IF EXIST "%PKG_BUILD_DIR%\.patched" ( GOTO FINISH )
IF NOT EXIST "%BASE_DIR%\batch\%PKG%\patches" ( GOTO FINISH )
IF "%PKG_BUILD_DIR%" == "" ( GOTO FINISH )

FOR /F %%p IN ('DIR /B /A-D /ON "%BASE_DIR%\batch\%PKG%\patches"') DO (
    CD "%PKG_BUILD_DIR%"
    bash -c 'patch -p1 -i "%BASE_DIR%\batch\%PKG%\patches\%%p"' && ECHO=>"%PKG_BUILD_DIR%\.patched"
    CD "%BASE_DIR%"
)
GOTO :EOF

:CAN_FIND
SETLOCAL
SET WHICH_DIR=%~$PATH:1
IF "%WHICH_DIR%" == "" (
    EXIT /B 101
) ELSE (
    EXIT /B 0
)
GOTO :EOF

:FINISH
EXIT /B %ERRORLEVEL%
