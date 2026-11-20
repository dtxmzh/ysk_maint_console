# -*- coding: utf-8 -*-
# v1.1.2 hot-fix round: banner const was hardcoded 1.1.1; ship corrected 4-pack.
# (a) rebuild zip, replace release asset; (b) API-commit MainWindow.cs bump + tag retarget.
import base64, json, os, subprocess, urllib.request, zipfile

REPO = r"F:/WorkStation/ysk_work/gh_ysk_maint_console"
GCM = r"D:/ProgramFiles/Hermes_Desktop/tools/git-2.56.1+1-win32-x64/ucrt64/bin/git-credential-manager.exe"
OWNER, NAME = "dtxmzh", "ysk_maint_console"
VER = "v1.1.2"

p = subprocess.run([GCM, "get"], input="protocol=https\nhost=github.com\n\n",
                   capture_output=True, text=True, timeout=60)
tok = next((l[9:].strip() for l in (p.stdout or "").splitlines() if l.startswith("password=")), "")
assert tok, "no token"

def api(method, url, body=None, rawdata=None, ctype="application/json"):
    if body is not None:
        data = json.dumps(body).encode()
    elif rawdata is not None:
        data = rawdata
    else:
        data = None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + tok,
        "Accept": "application/vnd.github+json",
        "User-Agent": "ysk-maint-console",
        "Content-Type": ctype,
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            txt = r.read()
            return r.status, (json.loads(txt) if txt and "json" in (r.headers.get("content-type") or "") else txt)
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:300].decode("utf-8", "replace")

# (a) fresh zip with corrected dll
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

st, rel = api("GET", f"https://api.github.com/repos/{OWNER}/{NAME}/releases/tags/{VER}")
assert st == 200, rel
rel_id = rel["id"]
for a in rel.get("assets", []):
    st2, _ = api("DELETE", a["url"])
    print("del old asset", a["name"], st2)
up = rel["upload_url"].split("{")[0] + "?name=" + zip_name
st, j = api("POST", up, rawdata=open(zip_path, "rb").read(), ctype="application/zip")
print("asset upload:", st, (j or {}).get("browser_download_url", str(j)[:150]) if isinstance(j, dict) else str(j)[:150])

# (b) API commit: MainWindow.cs banner bump (remote main = 8027a58a...)
remote = "8027a58a41b1ae402629e028345a32a4cfc3ac97"
st, cmt = api("GET", f"https://api.github.com/repos/{OWNER}/{NAME}/git/commits/{remote}")
assert st == 200, cmt
base_tree = cmt["tree"]["sha"]
raw = open(os.path.join(REPO, "src", "MainWindow.cs"), "rb").read()
st, bl = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/blobs",
             {"content": base64.b64encode(raw).decode(), "encoding": "base64"})
assert st in (200, 201), bl
st, tr = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/trees",
             {"base_tree": base_tree, "tree": [{"path": "src/MainWindow.cs", "mode": "100644", "type": "blob", "sha": bl["sha"]}]})
assert st in (200, 201), tr
st, nc = api("POST", f"https://api.github.com/repos/{OWNER}/{NAME}/git/commits", {
    "message": "v1.1.2 hotfix: banner const was hardcoded 1.1.1 (csproj/zip were fine); also redeploy 4-pack (single-file 131MB exe APPCRASHed on master's box - FD 4-pack is the shipping form)",
    "tree": tr["sha"], "parents": [remote]})
assert st in (200, 201), nc
new_sha = nc["sha"]
st, rr = api("PATCH", f"https://api.github.com/repos/{OWNER}/{NAME}/git/refs/heads/main", {"sha": new_sha, "force": False})
print("main:", st, new_sha[:8])
st, rr = api("PATCH", f"https://api.github.com/repos/{OWNER}/{NAME}/git/refs/tags/{VER}", {"sha": new_sha, "force": True})
print("tag retarget:", st, rr if st != 200 else "OK")
print("DONE new_sha", new_sha)
