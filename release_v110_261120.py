# -*- coding: utf-8 -*-
# ysk_maint_console v1.1.0: commit+push+tag, then Release + asset (261120 开工装配 tab +
# GPU/CPU 选卡下拉). Token via git-credential-manager, never printed. api.github.com direct.
import os, shutil, subprocess, zipfile, json, sys

REPO   = r"F:\WorkStation\ysk_work\gh_ysk_maint_console"
GIT    = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git.exe"
GCM    = r"D:\ProgramFiles\Hermes_Desktop\tools\git-2.56.1+1-win32-x64\ucrt64\bin\git-credential-manager.exe"
CURL   = r"C:\Windows\System32\curl.exe"
OWNER, NAME = "dtxmzh", "ysk_maint_console"
VER    = "v1.1.0"

# 1) refresh backend + entry inside the repo
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
    "v1.1.0: 开工装配积木面板(标签页仅切左栏) + 每件GPU0/GPU1/CPU选卡下拉 + 守护复选框集中UAC; 后端 b>1 装配协议/-BlocksState 探针/YSK_GPU 选卡贯穿六个bat与TTS /gpu/load?device=")
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

# 3) asset zip
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
        "首次运行若火绒拦截，把 ysk_maint_console\\ 目录加入信任区。\r\n"
        "v1.1.0 需要配套脚本 run\\ysk_maint_console.ps1（本包已含）；选卡功能另依赖\r\n"
        "E:\\DSDeployMaster\\ysk_autostart\\ 下各 serve_*.bat 的 YSK_GPU 支持（本机已就位）。\r\n")
print("zip:", os.path.getsize(zip_path), "bytes")

# 4) release + asset
rel_body = (
    "维护操作台 v1.1.0 — 开工装配积木台 (261120 主人设计)。\r\n\r\n"
    "### 更新内容\r\n"
    "- **新标签页「开工装配」(默认页)**：左栏顶部标签条在两页间切换，右侧终端回显/指示灯/进度条两页共享不变\r\n"
    "- **积木面板**：每个小模型一行——主勾选框=在岗，旁边的下拉=**自动/GPU0/GPU1/CPU 自由选卡**(零显存三件套固定CPU；KVMem无CPU形态)，行内小勾选框=守护计划任务开关\r\n"
    "- **「▶ 启动 Strata」一键装配**：不勾的全部退出→勾选的按指定卡先落座(门槛在点火一刻评估)→最后拉 Strata(已在岗则复用)；ComfyUI 勾选=独吞卡本轮不拉 Strata\r\n"
    "- **守护集中一次 UAC**：普通权限改得动的直接改，改不动的攒到最后一次提权弹窗，提权助手跑完自退(防权限混用)\r\n"
    "- 选项排序：装配页与菜单 m 组都按**装配使用可能性从大到小**重排(声线→OCR→KVMem→Tele→Comfy→whisper→三件套)\r\n"
    "- 运行时契约=**pwsh 7 唯一宿主**(exe 内部本就调用 pwsh7；脚本 hint/菜单全部改 pwsh，5.1 不再是支持面)\r\n"
    "- 后端新协议：-BlocksState 批量探针(约3秒)、b>1 装配 spec(id=1/0,g.id=1/0,pick.id=卡)、YSK_GPU 环境变量选卡贯穿六个启动 bat、TTS /gpu/load?device=N\r\n\r\n"
    "### 安装\r\n"
    "解包覆盖到 D:\\ProgramFiles\\ysk_tools\\ 即可。窗口版与脚本需配套更新（脚本协议变了）。\r\n")
code, text = curl("POST", "https://api.github.com/repos/%s/%s/releases" % (OWNER, NAME),
                  json.dumps({"tag_name": VER, "name": "维护操作台 " + VER + " — 开工装配积木台",
                              "body": rel_body, "draft": False, "prerelease": False}))
print("release:", code)
rel = json.loads(text)
up_url = rel.get("upload_url", "").split("{")[0]
if not up_url:
    print(text[:400]); sys.exit("no upload url")
code, text = curl("POST", up_url + "?name=" + zip_name,
                  extra=["--data-binary", "@" + zip_path,
                         "-H", "Content-Type: application/zip"])
print("asset:", code, json.loads(text).get("browser_download_url", text[:200]))
