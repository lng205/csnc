@echo off
REM ============================================================
REM RS IP 核资源基准测试 - 启动脚本
REM 使用 Xilinx Vivado 综合 RS IP 获取真实资源数据
REM ============================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================
echo  RS IP Benchmark - Xilinx Reed-Solomon IP 资源测试
echo ============================================================
echo.

REM ============================================================
REM Vivado 路径配置 (D盘)
REM ============================================================
set VIVADO_VERSIONS=2025.1 2024.2 2024.1 2023.2 2023.1 2022.2 2022.1

REM 检查常见安装路径
set VIVADO_FOUND=0

REM 首先检查 D 盘 (用户自定义路径)
for %%V in (%VIVADO_VERSIONS%) do (
    if exist "D:\apps\Xilinx\%%V\Vivado\bin\vivado.bat" (
        set VIVADO_PATH=D:\apps\Xilinx\%%V\Vivado
        set VIVADO_FOUND=1
        echo [OK] 找到 Vivado %%V @ D:\apps\Xilinx\%%V\Vivado
        goto :vivado_found
    )
    if exist "D:\Xilinx\Vivado\%%V\bin\vivado.bat" (
        set VIVADO_PATH=D:\Xilinx\Vivado\%%V
        set VIVADO_FOUND=1
        echo [OK] 找到 Vivado %%V @ D:\Xilinx\Vivado\%%V
        goto :vivado_found
    )
    if exist "D:\Vivado\%%V\bin\vivado.bat" (
        set VIVADO_PATH=D:\Vivado\%%V
        set VIVADO_FOUND=1
        echo [OK] 找到 Vivado %%V @ D:\Vivado\%%V
        goto :vivado_found
    )
)

REM 检查 C 盘
for %%V in (%VIVADO_VERSIONS%) do (
    if exist "C:\Xilinx\Vivado\%%V\bin\vivado.bat" (
        set VIVADO_PATH=C:\Xilinx\Vivado\%%V
        set VIVADO_FOUND=1
        echo [OK] 找到 Vivado %%V @ C:\Xilinx\Vivado\%%V
        goto :vivado_found
    )
)

REM 检查 PATH 中是否有 vivado
where vivado >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] 在 PATH 中找到 Vivado
    set VIVADO_PATH=
    set VIVADO_FOUND=1
    goto :vivado_found
)

REM 未找到 Vivado
echo.
echo [错误] 未找到 Vivado 安装
echo.
echo 请检查以下位置:
echo   - D:\Xilinx\Vivado\{version}
echo   - D:\Vivado\{version}
echo   - C:\Xilinx\Vivado\{version}
echo.
echo 或手动设置环境变量后重试:
echo   set VIVADO_PATH=您的Vivado安装路径
echo.
pause
exit /b 1

:vivado_found

REM 设置环境变量
if defined VIVADO_PATH (
    echo.
    echo 配置 Vivado 环境: %VIVADO_PATH%
    call "%VIVADO_PATH%\settings64.bat"
)

REM 切换到脚本目录
cd /d "%~dp0"
echo.
echo 工作目录: %CD%
echo.

REM ============================================================
REM 运行基准测试
REM ============================================================
echo 开始运行 RS IP 基准测试...
echo 这可能需要 30-60 分钟，取决于配置数量
echo.

REM 运行 TCL 脚本
if defined VIVADO_PATH (
    "%VIVADO_PATH%\bin\vivado.bat" -mode batch -source rs_ip_benchmark.tcl -nojournal -nolog
) else (
    vivado -mode batch -source rs_ip_benchmark.tcl -nojournal -nolog
)

set EXIT_CODE=%ERRORLEVEL%

echo.
echo ============================================================
if %EXIT_CODE% equ 0 (
    echo  测试完成! 结果保存在: rs_ip_results.csv
) else (
    echo  测试过程中出现错误 (退出代码: %EXIT_CODE%^)
)
echo ============================================================
echo.

REM 显示结果预览
if exist "rs_ip_results.csv" (
    echo 结果预览:
    echo ----------
    type rs_ip_results.csv
    echo.
)

pause
exit /b %EXIT_CODE%
