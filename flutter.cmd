@echo off
:: Retail Mind - Flutter Helper Script
:: Run this instead of 'flutter' directly
:: Usage: flutter.cmd <any flutter command>
:: Example: flutter.cmd pub get
::          flutter.cmd build apk --debug
::          flutter.cmd clean

set FLUTTER_BIN=C:\Users\LENOVO\flutter\bin
set JAVA_HOME=C:\jdk-17
set ANDROID_HOME=C:\Android\Sdk

set PATH=%FLUTTER_BIN%;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%

"%FLUTTER_BIN%\flutter.bat" %*
