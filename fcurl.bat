@echo off
setlocal EnableDelayedExpansion

if "%~1"=="" (
    echo Usage: fcurl.bat ^<URL^>
    echo Example: fcurl.bat http://192.168.130.33:8080/shared/test.txt 
    exit /b 1
)

set "URL=%~1"

:: 自动补全 http:// 协议头（如果没有的话）
echo %URL%|findstr /B "http://" >nul || (
    echo %URL%|findstr /B "https://" >nul || (
        set "URL=http://%URL%"
    )
)

:: 移除协议头，方便解析
set "URL_NO_PROTO=!URL:http://=!"
set "URL_NO_PROTO=!URL_NO_PROTO:https://=!"

:: 解析 host:port 和 path
:: 格式: host:port/path 或 host:port/ 或 host:port
for /f "tokens=1,* delims=/" %%a in ("!URL_NO_PROTO!") do (
    set "HOST_PORT=%%a"
    set "PATH_PART=%%b"
)

if "!HOST_PORT!"=="" (
    echo Error: Invalid URL format
    exit /b 1
)

:: 判断是文件还是目录
set IS_DIR=0

:: 检查原始 URL 是否以 / 结尾
if "!URL:~-1!"=="/" set IS_DIR=1

:: 如果没有以 / 结尾，检查是否有文件扩展名
if !IS_DIR!==0 (
    if not "!PATH_PART!"=="" (
        for %%f in ("!PATH_PART!") do set "LAST_PART=%%~nxf"
        echo !LAST_PART!|findstr "\." >nul || (
            set IS_DIR=1
            set "PATH_PART=!PATH_PART!/"
        )
    ) else (
        :: PATH_PART 为空，说明只有 host:port 或 host:port/
        set IS_DIR=1
    )
)

:: 构建签名 URL
if !IS_DIR!==1 (
    set "SIGN_URL=http://!HOST_PORT!/list/!PATH_PART!"
) else (
    set "SIGN_URL=http://!HOST_PORT!/download/!PATH_PART!"
)


:: 调用 sign.exe 获取签名 URL
for /f "tokens=*" %%i in ('sign.exe "!SIGN_URL!" 2^>nul ^| findstr /B "http://"') do (
    set "SIGNED_URL=%%i"
    
    if !IS_DIR!==1 (
        curl "!SIGNED_URL!"
    ) else (
        curl -OJ "!SIGNED_URL!"
    )
    exit /b 0
)

echo Error: Failed to generate signed URL
exit /b 1
