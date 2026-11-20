# -*- coding: utf-8 -*-
# Publish ysk_maint_console v1.0.0 to GitHub (create repo, push, release + asset).
# Token comes from git-credential-manager and is NEVER printed.
import os, shutil, subprocess, zipfile, json, sys

REPO   = r"F:\WorkStation\ysk_work\gh_ysk_maint_console"
GIT    = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git.exe"
GCM    = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git-credential-manager.exe"
CURL   = r"C:\Windows\System32\curl.exe"
OWNER  = "dtxmzh"
NAME   = "ysk_maint_console"

# 1) backend + entry into repo
os.makedirs(os.path.join(REPO, "scripts"), exist_ok=True)
shutil.copy2(r"D:\ProgramFiles\ysk_tools\run\ysk_maint_console.ps1",
             os.path.join(REPO, "scripts", "ysk_maint_console.ps1"))
shutil.copy2(r"D:\ProgramFiles\ysk_tools\ysk_维护操作台.bat",
             os.path.join(REPO, "scripts", "ysk_维护操作台.bat"))

# 2) token via GCM
p = subprocess.run([GCM, "get"], input="protocol=https\nhost=github.com\n\n",
                   capture_output=True, text=True, timeout=60)
tok = ""
for line in (p.stdout or "").splitlines():
    if line.startswith("password="):
        tok = line[9:].strip()
print("token acquired:", bool(tok))
if not tok:
    sys.exit("no token")

def curl(method, url, body=None, extra=None):
    cmd = [CURL, "-s", "-w", "\n%{http_code}", "-X", method, url,
           "-H", "Authorization: token " + tok,
           "-H", "Accept: application/vnd.github+json"]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "--data-binary", body]
    if extra:
        cmd += extra
    r = subprocess.run(cmd, capture_output=True, timeout=180)
    raw = r.stdout.decode("utf-8", "replace")
    code = raw.rsplit("\n", 1)[-1].strip()
    text = raw[:-len(code) - 1] if raw.endswith(code) and raw != code else raw
    return code, text

# 3) mirror visibility of the existing repo
code, body = curl("GET", "https://api.github.com/repos/" + OWNER + "/ysk_model_monitor")
priv = True
try:
    priv = json.loads(body).get("private", True)
except Exception:
    pass
print("model_monitor probe:", code, "private =", priv)

# 4) create repo if missing
code, body = curl("GET", "https://api.github.com/repos/" + OWNER + "/" + NAME)
print("repo exists?", code)
if code.strip() == "404":
    payload = json.dumps({"name": NAME,
                          "description": "维护操作台 — 本机运维窗口操作台（WPF 前端 + ps1 执行后端）",
                          "private": priv, "auto_init": False,
                          "has_issues": False, "has_wiki": False})
    code, body = curl("POST", "https://api.github.com/user/repos", payload)
    print("create repo:", code)
    if code.strip() not in ("201", "200"):
        print(body[:300]); sys.exit("repo create failed")

# 5) git init / commit / push
def git(*a):
    r = subprocess.run([GIT, "-C", REPO, *a], capture_output=True, timeout=180)
    return r.returncode, r.stdout.decode("utf-8", "replace").strip(), r.stderr.decode("utf-8", "replace").strip()

git("init", "-b", "main")
git("config", "user.name", "dtxmzh")
git("config", "user.email", "dtxmzh@users.noreply.github.com")
if git("remote", "get-url", "origin")[1] == "":
    git("remote", "add", "origin", "https://github.com/" + OWNER + "/" + NAME + ".git")
rc, out, err = git("add", "-A")
print("add rc:", rc, err[:120])
rc, out, err = git("status", "--porcelain")
print("staged files:", len(out.splitlines()))
rc, out, err = git("commit", "-m",
    "v1.0.0: 维护操作台窗口版首发（WPF 纯代码前端 + ps1 单发协议 + 状态灯/进度条/强杀/同步日志）")
print("commit rc:", rc, (out or err)[:100])
rc, out, err = git("push", "-u", "origin", "main")
print("push rc:", rc, "PUSH OK" if rc == 0 else err[:300])
if rc:
    sys.exit("push failed")

# 6) release zip mirroring the D:\ProgramFiles\ysk_tools layout
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

# 7) release + asset
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
                      "body": rel_body, "draft": False, "prerelease": False})
code, body = curl("POST", "https://api.github.com/repos/" + OWNER + "/" + NAME + "/releases", payload)
try:
    rel = json.loads(body)
except Exception:
    rel = {}
print("release create:", code, rel.get("html_url"))
upload_url = (rel.get("upload_url") or "").split("{")[0]
if upload_url:
    code, body = curl("POST", upload_url + "?name=" + os.path.basename(zip_path),
                      extra=["--data-binary", "@" + zip_path,
                             "-H", "Content-Type: application/zip"])
    print("asset upload:", code, "OK" if "browser_download_url" in body else body[:300])
else:
    print("!! no upload_url; body:", body[:300])
