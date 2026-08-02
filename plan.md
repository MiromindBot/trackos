# TrackOS 项目计划

## 任务目标
修复App经常提示系统位置服务（GPS开关）未开启，需要获取权限，但实际上已经赋予权限了的问题（仅Android）。

## 根因分析

### 问题根源：`Geolocator.isLocationServiceEnabled()` 与 `forceLocationManager` 不一致

1. **geolocator 包的行为差异**：
   - 位置请求（`getCurrentPosition`、`getPositionStream`）使用 `forceLocationManager: true`，强制使用 Android 原生 `LocationManager`，无需 Google Play Services
   - 但 `isLocationServiceEnabled()` 在 `GeolocationManager.java` 中**硬编码** `forceAndroidLocationManager = false`，始终优先使用 Google Play Services 的 `FusedLocationClient`
   
2. **FusedLocationClient 的检查逻辑**：
   - 使用 `SettingsClient.checkLocationSettings()` 检查 Google Location Accuracy 状态
   - 如果 Google Location Accuracy 关闭（但系统 GPS 开启），返回 `false`
   - 在没有 Google Play Services 的设备上（如国内市场的手机），可能崩溃或返回错误结果

3. **表现**：用户在系统设置中开启了 GPS，但因为 Google Location Accuracy 关闭或设备无 GMS，App 始终提示"系统位置服务未开启"

## 修复方案

### 1. MainActivity.kt（新增原生方法通道）
- 添加 `MethodChannel("com.rethinkos.trackos/location")` 
- `isLocationServiceEnabled`：使用 Android 原生 `LocationManager.isProviderEnabled()` 检查 GPS_PROVIDER 和 NETWORK_PROVIDER
- `openLocationSettings`：直接打开系统位置设置

### 2. location_service.dart（修改）
- `isLocationServiceEnabled()`：Android 上优先使用原生方法通道，fallback 到 geolocator
- `openLocationSettings()`：Android 上优先使用原生方法通道，fallback 到 geolocator

### 3. home_screen.dart（修改）
- Android 上添加定时轮询（10秒间隔）通过原生方法通道检查位置服务状态
- Geolocator 的 serviceStatusStream 作为辅助信号：只在报告"enabled"时更新 UI，不因 "disabled" 覆盖（Android 上的原生轮询作为真实来源）

## 当前进展
1. ✅ 分析代码结构，确认bug原因
2. ✅ Android 端修复：MainActivity.kt 添加原生位置服务检查方法通道
3. ✅ location_service.dart：优先使用原生检查
4. ✅ home_screen.dart：添加 Android 原生轮询 + 保护性流处理

## 未完成工作
- 编译测试修复后的 APK
- PR 提交与审核

## 下一步
- 测试修复后的版本
- 提交 PR
