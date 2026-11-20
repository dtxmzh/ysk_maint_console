# -*- coding: utf-8 -*-
# ysk_maint_console v1.0.1: commit+push+tag, then Release + asset (master 261120 requests:
# window geometry memory + [reset window] button + dialog first-click fix; ps1 venv-cmake fix).
# Token via git-credential-manager, never printed. api.github.com direct; git via SSH@443.
import os, shutil, subprocess, zipfile, json, sys

REPO   = r"F:\WorkStation\ysk_work\gh_ysk_maint_console"
GIT    = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git.exe"
GCM    = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git-credential-manager.exe"
CURL   = r"C:\Windows\System32\curl.exe"
OWNER, NAME = "dtxmzh", "ysk_maint_console"
VER    = "v1.0.1"

# 1) refresh backend + entry inside the repo (ps1 carries the venv-cmake probe fix)
os.makedirs(os.path.join(REPO, "scripts"), exist_ok=True)
shutil.copy2(r"D:\ProgramFiles\ysk_tools\run\ysk_maint_console.ps1",
             os.path.join(REPO, "scripts", "ysk_maint_console.ps1"))
shutil.copy2(r"D:\ProgramFiles\ysk_tools\ysk_维护操作台.bat",
             os.path.join(REPO, "scripts", "ysk_维护操作台.bat"))

def git(*a):
    r = subprocess.run([GIT, "-C", REPO, *a], capture_output=True, timeout=180)
    return r.returncode, r.stdout.decode("utf-8", "replace").strip(), r.stderr.decode("utf-8", "replace").strip()

rc, out, err = git("add", "-A")
print("add rc:", rc, err[:120])
rc, out, err = git("commit", "-m",
    "v1.0.1: 窗口大小位置记忆+恢复窗口按钮; 弹窗首击防吞(Arm+Activate); ps1 venv cmake 真身探测")
print("commit rc:", rc, (out or err)[:160])
rc, out, err = git("push", "origin", "main")
print("push rc:", rc, "PUSH OK" if rc == 0 else err[:300])
if rc:
    sys.exit("push failed")
rc, out, err = git("tag", VER)
print("tag rc:", rc, err[:120])
rc, out, err = git("push", "origin", VER)
print("tag push rc:", rc, "OK" if rc == 0 else err[:300])

# 2) token
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

# 3) asset zip (same ysk_tools layout as v1.0.0)
zip_name = "ysk_maint_console_%s_win-x64.zip" % VER
zip_path = os.path.join(REPO, zip_name)
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

# 4) release + asset
rel_body = (
    "维护操作台 v1.0.1 — 主人 261120 反馈三连修。\r\n\r\n"
    "### 更新内容\r\n"
    "- **窗口记忆**：关闭时记住大小/位置（含最大化态），下次启动原地重开；显示器变化导致越界自动回落默认\r\n"
    "- **[恢复窗口] 按钮**：底部按钮栏新增，一键回到默认 800x600 居中并清除位置记忆\r\n"
    "- **弹窗首击防吞**：输入/选择/确认框的按钮改为按下即响应 + 弹出强制激活，"
    "修复「留空后单击确定没反应、要按 Enter 才继续」\r\n"
    "- **[u>1] 升级修复（后端 ps1）**：0.2.16 布局 venv 迁入 terminal\\ 后 pip 的 cmake shim 哑火"
    "（静默 rc=1），构建配方现自动探测并改用 site-packages 下的 cmake 真身\r\n\r\n"
    "### 安装\r\n解压 zip（目录层级即 `D:\\ProgramFiles\\ysk_tools\\` 布局）覆盖即可。详见 README。")
payload = json.dumps({"tag_name": VER, "name": "维护操作台 " + VER + " (win-x64)",
                      "body": rel_body, "draft": False, "prerelease": False})
code, body = curl("POST", "https://api.github.com/repos/" + OWNER + "/" + NAME + "/releases", payload)
try:
    rel = json.loads(body)
except Exception:
    rel = {}
print("release create:", code, rel.get("html_url"))
upload_url = (rel.get("upload_url") or "").split("{")[0]
if upload_url:
    code, body = curl("POST", upload_url + "?name=" + zip_name,
                      extra=["--data-binary", "@" + zip_path,
                             "-H", "Content-Type: application/zip"])
    print("asset upload:", code, "OK" if "browser_download_url" in body else body[:300])
else:
    print("!! no upload_url; body:", body[:300])
