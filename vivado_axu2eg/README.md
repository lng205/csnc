# AXU2EG Vivado 工程

适用于 ALINX AXU2EG 开发板的 Vivado 工程。

## 开发板信息

| 项目 | 说明 |
|------|------|
| 开发板 | ALINX AXU2EG |
| 芯片 | Zynq UltraScale+ xczu2eg-sfvc784-1-e |
| Vivado 版本 | 2020.1 / 2025.1 (已测试) |

## 快速开始

### 方法1: 使用 BAT 脚本 (Windows)

1. 编辑 `auto_create_project/create_project.bat`，修改 Vivado 路径：
```batch
set VIVADO_PATH=D:\apps\Xilinx\2025.1\Vivado\bin\vivado.bat
```

2. 双击运行 `create_project.bat`

### 方法2: 使用 Vivado TCL Console

1. 打开 Vivado
2. 在 TCL Console 中执行：
```tcl
cd <path_to>/vivado_axu2eg/auto_create_project
source ./create_project.tcl
```

## 输出文件

构建完成后，XSA 文件位于：
```
vivado_axu2eg/design_1_wrapper.xsa
```

## 功能说明

此基础工程包含：
- PS 端基本外设配置 (UART, USB, SD, QSPI, DDR, etc.)
- PL 端 GPIO (LED, 按键, 风扇控制)
- PL UART (EMIO)

## 与 AXU3EG 的区别

| 特性 | AXU2EG | AXU3EG |
|------|--------|--------|
| 芯片 | xczu2eg | xczu3eg |
| PL 逻辑单元 | ~103K | ~154K |
| DSP | 240 | 360 |
| Block RAM | 150 (36Kb) | 216 (36Kb) |
| 底板 | 相同 | 相同 |
| 引脚配置 | 相同 | 相同 |

## 扩展

如需添加更多功能 (如 PL DDR4, 以太网, MIPI 等)，请参考：
`../AXU2CG-E_AXU3EG_AXU4EV-E_AXU5EV-E/vivado/auto_create_project/`

## 注意事项

1. 确保 Vivado 版本与工程兼容
2. 首次运行可能需要较长时间进行综合和实现
3. XSA 文件可用于 PetaLinux 或 Vitis 开发

