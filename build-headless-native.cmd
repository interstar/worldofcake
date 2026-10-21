@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 exit /b %errorlevel%
haxe hxml/tests/test-gbloink-native.hxml -D NO_AUTO_MSVC
if errorlevel 1 exit /b %errorlevel%
haxe hxml/tests/test-timeslider-native.hxml -D NO_AUTO_MSVC
if errorlevel 1 exit /b %errorlevel%
haxe hxml/tests/test-tileland-native.hxml -D NO_AUTO_MSVC
if errorlevel 1 exit /b %errorlevel%
haxe hxml/tests/test-kdiagram-native.hxml -D NO_AUTO_MSVC
if errorlevel 1 exit /b %errorlevel%
haxe hxml/tests/test-zewp-native.hxml -D NO_AUTO_MSVC
if errorlevel 1 exit /b %errorlevel%
