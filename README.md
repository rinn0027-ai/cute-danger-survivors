# Cute Danger Survivors

一个 Godot 2D 实时动作 roguelike MVP。当前核心循环包括：随机地牢房间、弹幕战斗、自动射击、经验升级、道具组合、宝箱房、商店、Boss 房和无限层数。

网页试玩版会导出到 `docs/`，用于 GitHub Pages 发布。

## 怎么打开

1. 安装 Godot 4.x。
2. 打开 Godot Project Manager。
3. 选择 Import，指向这个文件夹里的 `project.godot`。
4. 点击 Run。

## 操作

- WASD 或方向键移动。
- 桌面端：鼠标方向自动射击。
- 手机端：左侧虚拟摇杆移动，自动瞄准最近敌人。
- 打败敌人会掉落经验宝石。
- 升级后点击强化按钮选择 3 个随机强化之一。

## 当前框架

- `scenes/Main.tscn`：主场景。
- `scripts/main.gd`：地牢生成、房间切换、战斗、升级、HUD、道具。
- `scripts/player.gd`：玩家移动和受伤。
- `scripts/enemy.gd`：敌人追踪、Boss/普通敌人和死亡。
- `scripts/xp_gem.gd`：经验宝石收集。
- `scripts/virtual_joystick.gd`：手机触控摇杆。
- `assets/`：可爱但危险的像素风资产。
- `docs/`：GitHub Pages 网页试玩版。

## 下一步

1. 加强房间内容密度和事件类型。
2. 做正式道具池、套装组合和稀有度。
3. 增加更多敌人、精英怪和 Boss 招式。
4. 替换成更统一的 PNG sprite sheet 和中文像素字体。
5. 加音效、音乐、保存进度和设置界面。
