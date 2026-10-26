# BFG Calibration iOS — 自动编译

## 使用方法

push 后 GitHub 会自动触发云端 Mac 编译：

1. 打开仓库页面 → 点 **Actions** 标签
2. 看到黄色圆点 = 正在编译
3. 变绿勾 = 编译成功（约 3-5 分钟）
4. 点进成功的 workflow → 底部 **Artifacts** 区域
5. 下载 `BFGCalibration-unsigned`，解压得到 `BFGCalibration.ipa`

## 装到 iPhone

IPA 是未签名的，用以下任一工具签名安装：

| 工具 | 说明 |
|---|---|
| **Sideloadly** | 电脑端，用 Apple ID 免费签名，7 天有效 |
| **AltStore** | 电脑端，后台自动续签 |
| **TrollStore** | 如果 iOS 版本支持（15.0-16.6.1），可永久签名 |
