# -*- coding: utf-8 -*-
# insert work-library entry: 维护操作台 261120 GUI 首发全案
import json, urllib.request

CONTENT = """【更名】维护控制台→维护操作台（主人261120拍板，防与Windows组件混淆；ps1可见文案/exe标题/入口bat/桌面lnk全量改名，旧bat与旧lnk已退役）。
【形态】.NET10 WPF 纯代码GUI（无XAML；沿用浮窗双Main坑经验）·win-x64目录版约390K。源码仓=F:\\WorkStation\\ysk_work\\gh_ysk_maint_console\\src\\（Program/Config/MenuModel/ScriptRunner/StatusProbe/TerminalView/Dialogs/RunStateLight/MainWindow+app.ico/make_icon.py）。部署=D:\\ProgramFiles\\ysk_tools\\ysk_maint_console\\ 全套；入口=D:\\ProgramFiles\\ysk_tools\\ysk_维护操作台.bat（无参=窗口版，tty=原终端版）；桌面D:\\Users\\Dtxmzh\\Desktop\\ysk_维护操作台.lnk。单实例互斥Local\\ysk_maint_console_single_instance（二次启动激活既有窗即退，日志源唯一）。
【ps1侧协议】（已入定版ps1；改造前备份ysk_backups\\ysk_maint_console.ps1.bak_261120_pre_gui；ps1保持BOM+纯LF）：-DumpMenu 全菜单JSON(k/t/r/w/p，r=danger|confirm驱动GUI红标+强确认)；-ListBak Strata回滚库JSON(u>2输入弹窗数据源)；-Run <key> [-Arg v] 单发执行，stdin关闭时Ask()队列落安全默认；退出码0正常/2组项缺子项/1失败。
【GUI定版】双击行内任意位置=执行（自研判定：同两行down≤1.2s或ClickCount≥2，不信OS提升）；组行单击开合；EXIT双击防误。关键根因=官方TreeViewItem模板把header放Auto列、行右侧死区点不到→自定义模板StackPanel+DockPanel(LastChildFill)+整行透明Border+模板triggers画hover/选中。状态灯黑体大字：未运行灰/运行中黄闪/告警橙/完毕绿/错误红/手动停止橙常亮；进度条不定长滑动+计时终态定格(用时+exit)。强杀=停止按钮/无选中Ctrl+C/F6→杀pwsh进程树(危险项先确认；已放飞的自重启不承诺拦截，文案诚实)。回显RichTextBox只读框选复制+复制全部+导出日志+_data\\ysk_maint_console.log逐行落盘清屏不丢。状态探测3s一轮=端口灯8080/18200/9210/10808+主力+GPU余量。3分钟无输出看门狗只转橙提示不自杀。ini旁路=exe同目录ysk_maint_console.ini(script=/pwsh=)。
【GitHub】dtxmzh/ysk_maint_console(public同model_monitor)：main+tag v1.0.0+Release v1.0.0(asset=ysk_maint_console_v1.0.0_win-x64.zip 206KB：目录层级=ysk_tools布局，exe全套+bat+ps1+安装说明)。推送链路=github.com:443直连死→remote切SSH走~/.ssh/config(HostName ssh.github.com Port 443, key=~/.ssh/ysk_gh443，与hermes-agent同路)；API用curl+git-credential-manager.exe get取token(永不打印)；api.github.com直连可达。git全家桶在D:\\ProgramFiles\\Hermes_Desktop\\tools\\git-2.56.1+1-win32-x64\\ucrt64\\bin(gh CLI无)。
【坑录】1)WPF官方树模板header=Auto列死区(主人目击实锤) 2)注入双击不保证OS双击提升→自研时窗 3)gateway终端里Popen起的GUI会被进程树连坐清理，测试启动一律pwsh Start-Process(常驻铁律二次实证) 4)RichTextBox初始化CaretPosition=null即崩 5)Setter值禁NaN 6)FrameworkElementFactory无Child属性(用AppendChild)；ColumnDefinition/RowDefinitions走factory是灰色地带→DockPanel.LastChildFill替代；LastChildFillProperty定义在DockPanel非Panel 7)sql-proxy五库body键={"dbname","sql","params"}·占位符%s·键错静默回退webui主库(看返回db字段验) 8)bash heredoc内嵌python单引号/反斜杠易被咬→先写.py文件再跑。
【维护要点】GUI改动流程=改src→dotnet publish -c Release -r win-x64→拷deploy→git push+tag+curl传Release；菜单增删只改ps1(GUI经-DumpMenu自动跟)。火绒注意：新exe目录首启可能弹窗，主人已见其正常运行；若日后升级exe记得提醒主人确认信任区。"""

payload = {
    "dbname": "work",
    "sql": "INSERT INTO entries (category, title, content, source) VALUES (%s,%s,%s,%s) RETURNING id",
    "params": ["hermes-ops", "维护操作台261120窗口版首发与GitHub维护全案", CONTENT, "session 2026-11-20"],
}
r = urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:8090/query",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"}), timeout=30)
print(r.read().decode())
