# -*- coding: utf-8 -*-
# v1.1.2 full-API release: github.com git channel is walled tonight, but
# api.github.com + uploads.github.com answer 200/302. Push the commit as Git
# Data API objects (blobs->tree->commit->ref), tag via refs, then Release+asset.
import base64
import json
import os
import subprocess
import urllib.request
import zipfile

REPO = r"F:/WorkStation/ysk_work/gh_ysk_maint_console"
GCM = r"D:/ProgramFiles/Hermes_Desktop/tools/git-2.56.1+1-win32-x64/ucrt64/bin/git-credential-manager.exe"
GIT = r"D:/ProgramFiles/Hermes_Desktop/tools/git-2.56.1+1-win32-x64/ucrt64/bin/git.exe"
OWNER, NAME = "dtxmzh", "ysk_maint_console"
BASE = "44cf4a50896b78509e5b963e421c52bf9164d3e4"   # remote main right now
VER = "v1.1.2"

p = subprocess.run([GCM, "get"], input="protocol=https\nhost=github.com\n\n",
                   capture_output=True, text=True, timeout=60)
tok = next((l[9:].strip() for l in (p.stdout or "").splitlines() if l.startswith("password=")), "")
assert tok, "no token"


def api(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + tok,
        "Accept": "application/vnd.github+json",
        "User-Agent": "ysk-maint-console",
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:300].decode("utf-8", "replace")


def git(*a):
    r = subprocess.run([GIT, "-C", REPO, *a], capture_output=True, timeout=60)
    return r.stdout.decode("utf-8", "replace").strip()


# 1) rebuild the v1.1.2 zip from publish_win (framework-dependent 4-pack, same shape as v1.1.1)
zip_name = "ysk_maint_console_%s_win-x64.zip" % VER
zip_path = os.path.join(REPO, zip_name)
pub = os.path.join(REPO, "src", "publish_win")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("ysk_maint_console.exe", "ysk_maint_console.dll",
              "ysk_maint_console.deps.json", "ysk_maint_console.runtimeconfig.json"):
        z.write(os.path.join(pub, f), "ysk_tools/ysk_maint_console/" + f)
    z.write(os.path.join(REPO, "scripts", "ysk_\u7ef4\u62a4\u64cd\u4f5c\u53f0.bat"), "ysk_tools/ysk_\u7ef4\u62a4\u64cd\u4f5c\u53f0.bat")
    z.write(os.path.join(REPO, "scripts", "ysk_maint_console.ps1"), "ysk_tools/run/ysk_maint_console.ps1")
    z.writestr("ysk_tools/README-\u5b89\u88c5\u8bf4\u660e.txt",
        "\u89e3\u5305\u5230 D:\\ProgramFiles\\ysk_tools\\ \u5373\u53ef\uff08\u4fdd\u6301\u76ee\u5f55\u5c42\u7ea7\uff09\u3002\r\n"
        "\u5165\u53e3\uff1a\u53cc\u51fb ysk_\u7ef4\u62a4\u64cd\u4f5c\u53f0.bat = \u7a97\u53e3\u7248\uff1b\u52a0\u53c2\u6570 tty = \u539f\u7ec8\u7aef\u4ea4\u4e92\u7248\u3002\r\n"
        "\u9996\u6b21\u8fd0\u884c\u82e5\u706b\u7ed2\u62e6\u622a\uff0c\u628a ysk_maint_console\\ \u76ee\u5f55\u52a0\u5165\u4fe1\u4efb\u533a\u3002\r\n"
        "v1.1.2 \u9700\u914d\u5957\u811a\u672c run\\ysk_maint_console.ps1\uff08\u672c\u5305\u5df2\u542b\uff09\u3002\r\n")
print("zip:", os.path.getsize(zip_path))

# 2) commit contents = current HEAD tree vs BASE
st = git("diff", "--name-status", BASE, "HEAD")
changes = []
for line in st.splitlines():
    parts = line.split("\t")
    changes.append((parts[0], parts[1]))
# also ship the fresh v1.1.2 zip in the repo, like the v1.1.1 one already lives there
changes.append(("A", zip_name))
print("changes:", changes)

st, ref = api("GET", f"https://api.github.com/repos/{OWNER}/{NAME}/git/ref/heads/main")
assert st == 200, ref
remote_sha = ref["object"]["sha"]
assert remote_sha == BASE, ("remote moved?", remote_sha)
base_tree = ref["object"]["url"]  # resolve below via commit
st, cmt = api("GET", f"https://api.github.com/repos/{OWNER}/{NAME}/git/commits/{BASE}")
base_tree = cmt["tree"]["sha"]
print("base tree:", base_tree[:8])

tree_entries = []
for typ, path in changes:
    if typ == "D":
        tree_entries.append({"path": path, "mode": "100644", "type": "blob", "sha": None})
        continue
    raw = open(os.path.join(REPO, path.replace("/", os.sep)), "rb").read()
    if typ == "M":
        st, cur = api("GET", f"https://api.github.com/repos/{OWNER}/{NAME}/git/blobs/{base_tree}")  # placeholder, skipped
    st, bl = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/blobs",
                 {"content": base64.b64encode(raw).decode(), "encoding": "base64"})
    if st not in (200, 201):
        print("blob FAIL", path, st, bl); raise SystemExit(1)
    tree_entries.append({"path": path, "mode": "100644", "type": "blob", "sha": bl["sha"]})
    print("blob ok:", path, len(raw), "->", bl["sha"][:8])

st, tr = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/trees",
             {"base_tree": base_tree, "tree": tree_entries})
if st not in (200, 201):
    print("tree FAIL", st, tr); raise SystemExit(1)
print("tree:", tr["sha"][:8])

msg = git("log", "-1", "--pretty=%B")
st, nc = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/commits",
             {"message": msg, "tree": tr["sha"], "parents": [BASE]})
if st not in (200, 201):
    print("commit FAIL", st, nc); raise SystemExit(1)
new_sha = nc["sha"]
print("commit:", new_sha[:8])

st, rr = api("PATCH", f"https://api.github.com/repos/{OWNER}/{NAME}/git/refs/heads/main",
             {"sha": new_sha, "force": False})
print("ref main:", st, rr if st != 200 else "OK")
assert st == 200, rr

st, tg = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/refs",
             {"ref": "refs/tags/" + VER, "sha": new_sha})
print("tag ref:", st, tg if st != 201 else "OK")

# 3) Release + asset (uploads.github.com answers tonight)
body = (
    "\u7ef4\u62a4\u64cd\u4f5c\u53f0 v1.1.2 \u2014 \u4e3b\u4eba 22:36 \u5b9e\u5f39\u4e8c\u56de\u62a5\u4e09\u8fde\u4fee (261120)\u3002\r\n\r\n"
    "### \u66f4\u65b0\u5185\u5bb9\r\n"
    "- **\u58f0\u7ebf\u9009\u5361\u8d2f\u901a**\uff1a\u88c5\u914d\u91cc\u300c9210\u5df2\u5728\u5c97\u300d\u5feb\u6377\u8def\u5f84\u6f0f\u4f20\u9009\u5361\u53c2\u6570\uff08\u9009 GPU1 \u4ecd\u843d\u9ed8\u8ba4\u5361\uff09\u2014\u2014\u5df2\u4fee\uff1b"
    "\u6307\u5b9a GPU0/GPU1 \u73b0\u5728 = CUDA_VISIBLE_DEVICES \u5355\u5361\u89c6\u91ce**\u51b7\u91cd\u542f 9210**\uff0cIndexTTS \u4e0d\u518d\u628a\u6743\u91cd\u5288\u5230\u4e24\u5f20\u5361"
    "\uff088G@GPU0 + 1.1G@GPU1 \u5288\u53c9\u6839\u6cbb\uff09\uff1bauto \u4ecd\u8d70\u539f\u5730\u70ed\u6302\u8f7d\r\n"
    "- **\u9000\u51fa\u6e05\u626b\u4f11\u7720\u5bbf\u4e3b**\uff1a\u4e0d\u52fe\u9009\u7684\u79ef\u6728\u5373\u4f7f\u7aef\u53e3\u79bb\u7ebf\u4e5f\u6e05\u6389 serve bat \u5faa\u73af\u5bbf\u4e3b\u2014\u2014"
    "TeleOCR \u66fe\u9760 30s \u81ea\u6108\u73af\u8d81\u663e\u5b58\u7a7a\u5ea7\u81ea\u884c\u590d\u6d3b\uff08\u4efb\u52a1\u5df2\u7981\u7528\u4f46\u5bbf\u4e3b\u8fd8\u5728\u8dd1\uff09\r\n"
    "- TTS \u663e\u5b58\u95e8\u69db\u6309**\u6240\u9009\u5361**\u8bc4\u4f30\uff1b\u4e0a\u5361\u540e nvidia-smi \u9a8c\u5b9e\u5750\u5361\u5982\u5b9e\u4e0a\u62a5\r\n\r\n"
    "### v1.1.1\uff08\u540c\u65e5\uff09\r\n"
    "- \u4e0b\u62c9\u83dc\u5355\u6df1\u8272\u5316\uff1b\u6362\u5361\u81ea\u52a8\u9000\u51fa\u91cd\u62c9\u8d77\uff1b\u5b88\u62a4\u72b6\u6001 schtasks \u6743\u5a01\u6e90\r\n\r\n"
    "### \u5b89\u88c5\r\n"
    "\u89e3\u5305\u8986\u76d6\u5230 D:\\ProgramFiles\\ysk_tools\\ \u5373\u53ef\uff08GUI \u4e0e\u811a\u672c\u9700\u914d\u5957\uff09\u3002")
st, rel = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/releases",
              {"tag_name": VER, "name": "\u7ef4\u62a4\u64cd\u4f5c\u53f0 " + VER + " \u2014 \u5b9e\u5f39\u4e8c\u56de\u62a5\u4e09\u8fde\u4fee",
               "body": body, "draft": False, "prerelease": False, "make_latest": "true"})
print("release:", st)
if st not in (200, 201):
    print(rel); raise SystemExit(1)
up = rel["upload_url"].split("{")[0] + "?name=" + zip_name
data = open(zip_path, "rb").read()
req = urllib.request.Request(up, data=data, method="POST", headers={
    "Authorization": "Bearer " + tok, "Content-Type": "application/zip",
    "User-Agent": "x", "Accept": "application/vnd.github+json"})
with urllib.request.urlopen(req, timeout=180) as r:
    j = json.loads(r.read())
    print("asset:", r.status, j["browser_download_url"], j["size"])
print("DONE sha", new_sha[:8])
