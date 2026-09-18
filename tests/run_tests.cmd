@echo off
REM Tests unitaires des calculs (TopoCore.js / TopoCalc.js) avec le runtime Qt d'OSGeo4W, sans QField.
call C:\OSGeo4W\bin\o4w_env.bat >nul
set QT_ASSUME_STDERR_HAS_CONSOLE=1
set QT_FORCE_STDERR_LOGGING=1
set QML2_IMPORT_PATH=C:\OSGeo4W\apps\Qt5\qml
C:\OSGeo4W\apps\Qt5\bin\qmlscene.exe "%~dp0test_calculs.qml"
