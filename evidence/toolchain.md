# 项目局部分析工具链

锁定日期 2026-10-18。只有本项目 `.tools/` 安装，未运行 `rea setup`、未注册全局 MCP，未替换系统 JDK。CLI 运行不使用额外云模型服务。

## 版本与供应来源

- REA 6.5.0，npm 包 `rea-agents@6.5.0`；Node 24.12.0。依赖及 integrity 锁定在 `tooling/rea/package-lock.json`。
- [REA 6.5.0 release](https://github.com/morluto/rea/releases/tag/rea-agents-6.5.0)，官方仓库 commit `3b79af28e80785afce9f5998d8f03289402a1847`。npm integrity 与 git commit 是不同来源标识，不声称二者逐文件可重现。
- [Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build)，官方 ZIP，SHA-256 `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`，下载后匹配 GitHub release asset digest。
- Temurin arm64 JDK 21.0.12.1+1，Adoptium 官方 API 返回的 [release](https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.12.1%2B1)，SHA-256 `3623232f33a9c3baadf304480b2535f9a3cba8a58d42ecbb438ba267315d9998`，下载后匹配发布 checksum。
- 精确下载 URL、版本与本地编译产物 hash：`tooling/versions.json`。Node/JDK 为命令级选择；不改 shell profile。

## 首次故障与修复

`rea doctor --provider ghidra --format json` 首次失败，唯一必需项缺口是 `ghidra-native_decompiler`。官方 ZIP 只附带 Linux/Windows 原生反编译器。使用同一 release 自带 C++ 源码、现有 CLT 编译 arm64 版本：

```sh
make -C .tools/ghidra_12.1.4_PUBLIC/Ghidra/Features/Decompiler/src/decompile/cpp -j4 ghidra_opt ARCH_TYPE='-arch arm64' OSDIR=mac_arm_64
mkdir -p .tools/ghidra_12.1.4_PUBLIC/Ghidra/Features/Decompiler/os/mac_arm_64
cp .tools/ghidra_12.1.4_PUBLIC/Ghidra/Features/Decompiler/src/decompile/cpp/ghidra_opt .tools/ghidra_12.1.4_PUBLIC/Ghidra/Features/Decompiler/os/mac_arm_64/decompile
scripts/rea doctor --provider ghidra --format json
```

随后 `healthy=true`，9 个所需 scope checks 均通过。`environment_healthy=false` 涉及未安装的其他引擎与未注册的 agent clients，不属于本次 ghidra CLI 所需范围。没有据此连装其他工具。

Python urllib 首次拉取 release metadata 出现 TLS EOF；改用系统 curl 成功，未关闭 TLS 校验。npm 报传递依赖 prebuild-install 弃用警告；本轮未擅自升级锁定包。安装原始日志保留在忽略目录。

## 在新 checkout 复现

1. 依据 `tooling/versions.json` 的 URL 下载 Ghidra ZIP/JDK tar.gz，计算 SHA-256 与锁定值比较，再分别解压至 `.tools/`。ZIP 解压须保留 Unix executable mode；若使用 Python zipfile，需为 `support/launch.sh`、`support/analyzeHeadless` 加执行位。
2. `mkdir -p .tools/rea`；将 `tooling/rea/package*.json` 复制到 `.tools/rea/`，执行 `npm ci --prefix .tools/rea`。
3. 按上段编译 mac_arm_64 decompiler。无需 Homebrew/JDK 全局安装。
4. `scripts/rea doctor --provider ghidra --format json`。
5. 用 `lipo -thin arm64 '<研究副本内可执行文件>' -output analysis/slices/<名称>.arm64`；核对 `evidence/slice-manifest.json`。
6. `scripts/rea function analysis/slices/OneSwitchXPC.arm64 --procedure=0x1000014e0 --provider ghidra --format json`。

`--format json` 已用本机 CLI --help 验证；未沿用资料中可能存在的 `--json` 别名。脚本只设置 JAVA_HOME/GHIDRA_INSTALL_DIR 并透传参数。

## 项目与回退范围

REA 6.5.0 Ghidra launcher 使用 `-readOnly -deleteProject`，每次命令建立隔离临时项目，随后删除。故本轮“重开验证”采用相同 thin file 的全新导入并比较地址/汇编/伪代码，**不是持久 .gpr 重开**。原始分析 JSON 保留 `evidence/raw/rea/`，不入库。结果的 address、slice hash、provider version 入证据摘要。

卸载仅需删除本轮 `.tools/`（约数 GB）及不再需要的 analysis/raw，不影响已有 Java、Node、Xcode。研究样本需按自己的保留决定处理，不自动删除。工具二进制、原包、批量反编译文本均不入 Git。

官方参考：[安装说明](https://github.com/morluto/rea/blob/3b79af28e80785afce9f5998d8f03289402a1847/docs/installation.md)、[CLI](https://github.com/morluto/rea/blob/3b79af28e80785afce9f5998d8f03289402a1847/docs/cli.md)。
