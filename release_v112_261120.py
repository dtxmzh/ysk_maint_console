# -*- coding: utf-8 -*-
# ysk_maint_console v1.1.2 release: master's 22:36 live-fire round 2 fixes (261120).
# Token via git-credential-manager, never printed. api.github.com via curl; git via SSH@443.
import os, shutil, subprocess, zipfile, json, sys

REPO   = r"F:/WorkStation/ysk_work/gh_ysk_maint_console"
GIT    = r"D:/ProgramFiles/Hermes_Desktop/tools/git-2.56.1+1-win32-x64/ucrt64/bin/git.exe"
GCM    = r"D:/ProgramFiles/Hermes_Desktop/tools/git-2.56.1+1-win32-x64/ucrt64/bin/git-credential-manager.exe"
CURL   = r"C:/Windows/System32/curl.exe"
OWNER, NAME = "dtxmzh", "ysk_maint_console"
VER    = "v1.1.2"

os.makedirs(os.path.join(REPO, "scripts"), exist_ok=True)
shutil.copy2(r"D:/ProgramFiles/ysk_tools/run/ysk_maint_console.ps1",
             os.path.join(REPO, "scripts", "ysk_maint_console.ps1"))
shutil.copy2(r"D:/ProgramFiles/ysk_tools/ysk_维护操作台.bat",
             os.path.join(REPO, "scripts", "ysk_维护操作台.bat"))

def git(*a):
    r = subprocess.run([GIT, "-C", REPO, *a], capture_output=True, timeout=180)
    return r.returncode, r.stdout.decode("utf-8", "replace").strip(), r.stderr.decode("utf-8", "replace").strip()

rc, out, err = git("add", "-A")
print("add rc:", rc, err[:120])
rc, out, err = git("commit", "-m",
    "v1.1.2: tts card pick honored in assembly shortcut + CVD single-card cold restart (kills IndexTTS two-card spread); teardown sweeps dormant watchdog loop hosts (teleocr seat-wake fix)")
print("commit rc:", rc, (out or err)[:160])
rc, out, err = git("push", "origin", "main")
print("push rc:", rc, "PUSH OK" if rc == 0 else err[:300])
if rc:
    sys.exit("push failed")
rc, out, err = git("tag", VER)
print("tag rc:", rc, err[:120])
rc, out, err = git("push", "origin", VER)
print("tag push rc:", rc, "OK" if rc == 0 else err[:300])

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

zip_name = "ysk_maint_console_%s_win-x64.zip" % VER
zip_path = os.path.join(REPO, zip_name)
pub = os.path.join(REPO, "src", "publish_win")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("ysk_maint_console.exe", "ysk_maint_console.dll",
              "ysk_maint_console.deps.json", "ysk_maint_console.runtimeconfig.json"):
        z.write(os.path.join(pub, f), "ysk_tools/ysk_maint_console/" + f)
    z.write(os.path.join(REPO, "scripts", "ysk_维护操作台.bat"), "ysk_tools/ysk_维护操作台.bat")
    z.write(os.path.join(REPO, "scripts", "ysk_maint_console.ps1"), "ysk_tools/run/ysk_maint_console.ps1")
    z.writestr("ysk_tools/README-安装说明.txt".encode("utf-8").decode("utf-8"),
        "解包到 D:\\ProgramFiles\\ysk_tools\\ 即可（保持目录层级）。\r\n"
        "入口：双击 ysk_维护操作台.bat = 窗口版；加参数 tty = 原终端交互版。\r\n"
        "首次运行若火绒拦截，把 ysk_maint_console\\ 目录加入信任区。\r\n"
        "v1.1.2 需配套脚本 run\\ysk_maint_console.ps1（本包已含）与 TTS 服务端\r\n"
        "E:\\DSDeployMaster\\yosuko-tts\\yosuko_server.py 的 /gpu/load 支持（261120 版已含 device 上报）。\r\n")
print("zip:", os.path.getsize(zip_path), "bytes")

rel_body = (
    "维护操作台 v1.1.2 — 主人 22:36 实弹二回报三连修 (261120)。\r\n\r\n"
    "### 更新内容\r\n"
    "- **声线选卡贯通**：装配里「9210已在岗」快捷路径此前漏传选卡参数（选 GPU1 仍落默认卡）——已修；"
    "指定 GPU0/GPU1 现在 = 以 CUDA_VISIBLE_DEVICES 单卡视野**冷重启 9210**，"
    "IndexTTS 不再把权重劈到两张卡（8G@GPU0 + 1.1G@GPU1 劈叉根治）；auto 仍走原地热挂载\r\n"
    "- **退出清扫休眠宿主**：不勾选的积木即使端口离线，也会清掉其 serve bat 守护循环宿主——"
    "TeleOCR 曾靠 30s 自愈环趁显存空座自行复活（任务已禁用但宿主进程还在跑的就是它）\r\n"
    "- TTS 显存门槛改按**所选卡**评估；上卡后用 nvidia-smi 验证实坐卡并如实上报\r\n\r\n"
    "### v1.1.1（同日）\r\n"
    "- 下拉菜单深色化（自制 ComboBox 模板，白色系统弹层退役）\r\n"
    "- 换卡自动重落位：改下拉即自动退出重拉起；目标卡被在岗 Strata 占用时先清退再冷加载\r\n"
    "- 守护状态改 schtasks 权威源（治 Get-ScheduledTask CIM 滞后假 armed）\r\n\r\n"
    "### 安装\r\n"
    "解包覆盖到 D:\\ProgramFiles\\ysk_tools\\ 即可（GUI 与脚本需配套）。")
code, text = curl("POST", "https://api.github.com/repos/%s/%s/releases" % (OWNER, NAME),
                  json.dumps({"tag_name": VER, "name": "维护操作台 " + VER + " — 实弹二回报三连修",
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
