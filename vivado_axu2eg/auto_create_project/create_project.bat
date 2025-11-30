@echo off
REM ============================================
REM AXU2EG Vivado Project Creation Script
REM 请修改下面的 Vivado 安装路径
REM ============================================

REM Vivado 安装路径 (请根据实际情况修改)
set VIVADO_PATH=D:\apps\Xilinx\2025.1\Vivado\bin\vivado.bat

echo ============================================
echo  AXU2EG Project Builder
echo  Using: %VIVADO_PATH%
echo ============================================

CALL "%VIVADO_PATH%" -mode batch -source create_project.tcl

echo.
echo Build completed! Check above for any errors.
echo XSA file location: ..\design_1_wrapper.xsa
echo.

PAUSE

