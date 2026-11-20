# -*- coding: utf-8 -*-
# v1.0.0 release + asset upload (repo already pushed).
import os, subprocess, zipfile, json

REPO  = r"F:\WorkStation\ysk_work\gh_ysk_maint_console"
GCM   = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git-credential-manager.exe"
CURL  = r"C:\Windows\System32\curl.exe"
OWNER, NAME = "dtxmzh", "ysk_maint_console"

p = subprocess.run([GCM, "get"], input="protocol=https\nhost=github.com\n\n",
                   capture_output=True, text=True, timeout=60)
tok = next((l[9:].strip() for l in (p.stdout or "").splitlines() if l.startswith("password=")), "")
assert tok, "no token"

def curl(method, url, body=None, extra=None):
    cmd = [CURL, "-s", "-w", "\n%{http_code}", "-X", method, url,
           "-H", "Authorization: token " + tok,
           "-H", "Accept: application/vnd.github+json"]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "--data-binary", body]
    if extra:
        cmd += extra
    r = subprocess.run(cmd, capture_output=True, timeout=240)
    raw = r.stdout.decode("utf-8", "replace")
    code = raw.rsplit("\n", 1)[-1].strip()
    text = raw[:-len(code) - 1] if raw.endswith(code) and raw != code else raw
    return code, text

zip_path = os.path.join(REPO, "ysk_maint_console_v1.0.0_win-x64.zip")
pub = os.path.join(REPO, "src", "publish_win")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("ysk_maint_console.exe", "ysk_maint_console.dll",
              "ysk_maint_console.deps.json", "ysk_maint_console.runtimeconfig.json"):
        z.write(os.path.join(pub, f), "ysk_tools/ysk_maint_console/" + f)
    z.write(os.path.join(REPO, "scripts", "ysk_维护操作台.bat"), "ysk_tools/ysk_维护操作台.bat")
    z.write(os.path.join(REPO, "scripts", "ysk_maint_console.ps1"), "ysk_tools/run/ysk_maint_console.ps1")
    z.writestr("ysk_tools/README-安装说明.txt",
        "解包到 D:\\ProgramFiles\\ysk_tools\\ 即可（保持目录层级）。\r\n"
        "入口：双击 ysk_维护操作台.bat = 窗口版；加参数 tty = 原终端交互版。\r\n"
        "首次运行若火绒拦截，把 ysk_maint_console\\ 目录加入信任区。\r\n")
print("zip:", os.path.getsize(zip_path), "bytes")

rel_body = (
    "维护操作台 v1.0.0 — 首个窗口版。\r\n\r\n"
    "### 功能\r\n"
    "- 左侧分组菜单树（启动时从 ps1 `-DumpMenu` 实时装载，标签/危险级永不漂移）\r\n"
    "- 行内任意位置双击执行 / 选中后回车执行；组行单击开合；⚠ 危险项强确认\r\n"
    "- 彩色终端回显：自由框选复制 / 复制全部 / 导出日志 / 逐行落盘同步日志\r\n"
    "- 大号运行状态灯（未运行灰·运行中黄闪·完毕绿·错误红·告警橙）+ 底部进度条计时\r\n"
    "- 强制终止（停止按钮 / 无选中 Ctrl+C / F6，杀 pwsh 进程树）\r\n"
    "- 单实例互斥 + 3 分钟无输出看门狗（只提示不自杀）\r\n\r\n"
    "### 安装\r\n解压 zip（目录层级即 `D:\\ProgramFiles\\ysk_tools\\` 布局）到该目录，"
    "双击 `ysk_维护操作台.bat`。详见 README。")
payload = json.dumps({"tag_name": "v1.0.0", "name": "维护操作台 v1.0.0 (win-x64)",
                      "body": rel_body, "draft": False, "prerelease": False,
                      "target_commitish": "main"})
code, body = curl("POST", "https://api.github.com/repos/" + OWNER + "/" + NAME + "/releases", payload)
rel = json.loads(body) if body.strip().startswith("{") else {}
print("release create:", code, rel.get("html_url"))
upload_url = (rel.get("upload_url") or "").split("{")[0]
if upload_url:
    code, body = curl("POST", upload_url + "?name=" + os.path.basename(zip_path),
                      extra=["--data-binary", "@" + zip_path, "-H", "Content-Type: application/zip"])
    durl = ""
    try:
        durl = json.loads(body).get("browser_download_url", "")
    except Exception:
        pass
    print("asset upload:", code, durl or body[:200])
