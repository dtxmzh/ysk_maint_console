param([switch]$ProbeOnly, [switch]$UpdateDirect, [switch]$StrataDirect, [switch]$KvmemDirect,
      [string]$Rank2Git = '', [string]$Rank2Dl = '',
      [switch]$DumpMenu, [switch]$ListBak, [switch]$BlocksState, [string]$Run = '', [string]$Arg = '')
# runtime contract (261120 master): pwsh-7 ONLY (GUI exe + bat launcher pin pwsh.exe); 5.1 is
# never a supported host, so pwsh-7 idioms are fair game and every internal spawn uses pwsh.
# -*- coding: utf-8 -*-
# ============================================================================
# ysk_maint_console.ps1 -- this machine's maintenance console (by Yosuko;
#   main-switch merged version 2026-10-12; grew into full console and renamed
#
# merged from ysk_gsq_menu.ps1 + ysk_strata_menu.ps1 (2026-10-09 versions, both retired)
#
# launched by GUI front-end ysk_maint_console.exe ('维护操作台' window app, single-shot -Run core)
#   or by CLI fallback bat ysk_维护操作台.bat (two-level menu final 2026-10-20; grouped 2026-11-12):
#   ---- main menu (2026-11-12 regroup: hot keys + 4 group entries + [x] full map) ----
#   [1] switch main->Strata  [2] switch main->KVMem  [3] full health check  [4] GPU procs
#   [m] models & VRAM      [u] engines & upgrades   [c] creative & rescue  [h] Hermes & OS
#   [x] print every entry  [q] quit
#   group entries (q=back to main; menu text and the [x] map both come from one table):
#     m>1 ws up    m>2 ws down   m>3 stop Strata  m>4 stop KVMem  m>5 free Ollama
#     m>6 TeleCPU emergency up/down   m>8 arm KVMem resident (dual-engine, keeps Strata)
#     m>9 mount 18201 OCR on GPU0     m>0 stand 18201 down (frees its GPU0 seat)
#     m>a voice GPU up    m>b voice GPU down    m>c TeleOCR GPU up    m>d TeleOCR GPU down
#   building-blocks policy (261120): [1] keeps every small model in place (ComfyUI + Ollama
#   still evicted); all manual levers ignite via the hidden vbs and arm NO guard task
#     u>1 upgr Strata  u>2 rollback Strata  u>3 upgr KVMem  u>4 V100 speed switches
#     u>5 upgr Hermes  u>6 backup Hermes    u>7 recent upgrade receipts   u>8 restart 8080
#     c>1 ComfyUI up  c>2 ComfyUI down  c>3 ComfyUI-CPU  c>4 launch Blender
#     c>5 whisper up  c>6 whisper down  c>7 revive vision router 18207  c>8 revive zero-VRAM trio
#     h>1 self-check  h>2 repair  h>3 restart gateway  h>4 pwsh env  h>5~7 VPN status/up/down
#     h>8 task overview  h>9 open panels  h>0 tail switch log
#   ---- legacy numbering map (pre 2026-11-12 regroup, kept for old archives/briefs) ----
#   old main[1..9] = new [1],[2],(u group),[3],[4],m>3,m>4,m>1,m>2 ; also old[7]=new[3], old[8]=new[4], old[9]=h>0
#   old sub[1..5]   = m>5, c>1, c>2, c>5, c>6          old sub[6..9] = h>1, h>2, h>4, h>3
#   old u>5,[b] = u>5, u>6                     old sub[c-e]  = h>5, h>6, h>7
#   old h>8,[g] = h>8, h>9                     old m>6,[i] = m>6, m>7
#   old c>7,[k] = c>7, c>8                     old c>4,[m] = c>4, c>3
#   old u>1,[o] = u>1, u>3                     new: u>2(rollback) u>4(V100 switches) u>7(receipts)
#   (2026-10-20: old flat-27 retired, old->new: old[3]=new[1], old[1]+[6] merged=new[2],
#    old[2]=m>1, old[4]=m>2, old[5]=m>3, old[6]=m>4, old[7]=h>1, old[15]=new[3], old[22]=new[4],
#    old[25]=h>0, old[16-20]=c/m groups, old[8-11]=h group, old[26]=u>5, old[24]=u>6,
#    old[12-14]=h>5~7, old[21]=h>8, old[23]=h>9)
#   (earlier 2026-10-20 mapping snapshot, superseded by the block above):
#    old[2]=new[3], old[4]=new[4], old[5]=new[5], old[7]=new[6], old[15]=new[7], old[22]=new[8],
#    old[25]=new[9], old[16-20]=sub[1-5], old[8-11]=sub[6-9], old[26]=u>5, old[24]=u>6,
#    old[12-14]=sub[c-e], old[21]=h>8, old[23]=h>9)
#
# 2026-10-19 design points (GSQ fully removed; its engine llama-vl b11240 still shared by zero-VRAM trio):
#   - zero-VRAM trio (18202 dispatcher / 18303 embed / 18304 rerank, CUDA_VISIBLE_DEVICES=99
#     + --no-mmproj-offload) uses no VRAM, coexists with KVMem/Strata, switching never evicts them
#   - 2026-11-17 POLICY FLIP (master's call; 11-17 07:10 log evidence): Strata + KVMem COEXIST as the
#     dual-engine normal form -- Strata = main chat, KVMem = resident spare/clone on GPU1. v0.19.1 unified
#     footprint ~14.5G static (weights 11.6GiB + int8 KV page pool 2.4GiB, KV offloaded to RAM).
#     The old 10-09 'mutually exclusive' rule belonged to the v0.18.1 big-KV-prealloc era, now retired.
#   - workstation VRAM budget: GPU1 = KVMem 16G + TTS 4G + TeleOCR ~2.5G + light imggen ~10G
#     GPU0 = heavy ComfyUI creative: img 8G / 5B video 14G / HY480p 24G / TRELLIS 24G / A14B 25G / HY720p 29G / Animate 30G max
#     192G RAM carries: KVMem 240K KV offload + GGUF mmap page cache (2nd load in seconds) + ComfyUI switch buffer
#   - Strata IS mutually exclusive with whole-card GPU SUITES (ComfyUI/Blender); whisper/TeleOCR/
#     TTS-GPU are only *presumed* exclusive from the old big-prealloc era -- measured 261120 evening
#     the card split is elastic (Strata gave up ~10.6G when KVMem took GPU1 first), so [1] now keeps
#     all small models seated and the master drives them with the m>a..m>d manual levers.
#     Legacy exception line kept for reference:
#     KVMem 18200 coexists as standby (dual-engine normal since 11-17) and 18201 Xiaomi runs its CPU
#     build alongside Strata (dual-mode bat, zero VRAM) -- 2026-11-18 architecture
#     dual-engine parallel fills all 64G -- any suite is locked out. Suite co-op requires KVMem-ONLY mode
#     ([2] solo switch or m>1 workstation frees whole GPU0 ~31G for ComfyUI; GPU1 keeps ~15G spare).
#
# never touches: smart_dispatch guard, ComfyUI (master starts it on purpose)
# log: E:\DSDeployMaster\ysk_autostart\main_switch.log
# ============================================================================
# CLI direct modes (2026-11-03; for scheduled tasks / out-of-gateway process tree):
#   pwsh -File this.ps1 -ProbeOnly      = rank mirrors by speed only, never touch hermes
#   pwsh -File this.ps1 -UpdateDirect = rank + upgrade in one shot (same as u>5)
#   pwsh -File this.ps1 -StrataDirect = Strata upgrade fully unattended (u>1; for tasks/out-of-tree runs, see u>1 notice)
#   pwsh -File this.ps1 -KvmemDirect  = KVMem upgrade fully unattended (u>3; ~GB downloads MUST run out of gateway tree)
#   pwsh -File this.ps1 -DumpMenu     = print the grouped menu tree (incl r/p/w metadata) as one JSON line
#   pwsh -File this.ps1 -ListBak      = print engine\*.bak.exe inventory as JSON (GUI rollback radio source)
#   pwsh -File this.ps1 -BlocksState  = assembly-desk blocks+vram JSON (GUI 开工装配 tab feed, 261120)
#   pwsh -File this.ps1 -Run 'u>8' [-Arg v1,v2] = single-shot menu item then exit (GUI front-end core;
#       mid-run prompts consume the comma-split -Arg queue first, then fall back to stdin)
$ErrorActionPreference = "Continue"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$LOG     = "E:\\DSDeployMaster\\ysk_autostart\\main_switch.log"
$HERMEXE = "D:\\ProgramFiles\\Hermes_Desktop\\hermes-agent\\.hermes\\bin\\hermes.exe"
$CONFIG  = "D:\\ProgramFiles\\Hermes_Desktop\\config.yaml"
$S_URL   = "http://127.0.0.1:8080/v1/models"
$K_URL   = "http://127.0.0.1:18200/v1/models"
$OCRG_URL = "http://127.0.0.1:18201/v1/models"
$O_URL   = "http://127.0.0.1:11434"
$T_URL   = "http://127.0.0.1:9210"
$TASK_S  = "ysk_strata_autostart"
$TASK_K  = "ysk_kvmem_autostart"
$TASK_OCR = "ysk_ocr_autostart"   # 18201 Xiaomi-OCR-0 DUAL-MODE guard (2026-11-18: GPU build when GPU0 free>=2300MB, else CPU build zero-VRAM ~1min/page)
$OCR_BAT  = "E:\DSDeployMaster\ysk_autostart\ysk_serve_ocr.bat"   # the 18201 dual-mode bat+watchdog itself; launchable via $HID_VBS when the task is ACL-locked (261120)
$TL_BAT   = "E:\DSDeployMaster\ysk_autostart\ysk_serve_teleocr.bat"  # 18205 GPU1 serve bat (own 2048MB gate + 30s self-heal), used by m>c without any guard task (261120)
$TASK_TL  = "\ysk\ysk_teleocr_guard"   # 11-18 fix: real task lives under \ysk\ (bare name made schtasks /TN silently fail); 10-25: TeleOCR 18205 (main OCR head for vision in KVMem/creative scenes)
$TASK_KV  = "\ysk\ysk_kvmem_vision_guard"   # 11-18 fix: \ysk\ prefix; 10-25: KV-vision 18206 (retired 10-27, guard kept for revival)
$TASK_R   = "\ysk\ysk_vision_router_guard"   # 11-18 fix: \ysk\ prefix; 10-25: vision router 18207 (zero-VRAM CPU daemon)
# 2026-11-18: 18203 ocr-cpu retired (task+bat+Ovis weights dismantled). m>6/m>7 repurposed
# for the TeleOCR-CPU emergency instance (manual-only, launched via hidden vbs):
$TL_CPU_BAT = "E:\DSDeployMaster\ysk_autostart\ysk_run_teleocr_cpu.bat"
$HID_VBS    = "E:\DSDeployMaster\ysk_autostart\ysk_run_hidden.vbs"
$TASK_TTS   = "ysk_yosuko_autostart"   # voice line guard task (block policy default disarmed)
$TTS_BAT    = "E:\DSDeployMaster\ysk_autostart\ysk_serve_yosuko.bat"   # 9210 serve+30s loop; env YSK_GPU pins the CUDA card view (261120)
$TASK_B   = "ysk_brain_autostart"   # dispatcher 18202 (command approval)
$TASK_VLE = "ysk_vlembedding_autostart"   # embed 18303
$TASK_VLR = "ysk_vlreranker_autostart"   # rerank 18304
# handoff flag: [1]/[2] write it after Strata fully stops; kvmem guard bat consumes once, deletes it, skips corpse recheck (2026-10-22 final)
$K_FLAG   = "E:\DSDeployMaster\ysk_autostart\kvmem_wanted.flag"

function Note($m) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m
    Write-Host $line
    Add-Content -Path $LOG -Value $line -Encoding UTF8
}
# ---- GUI front-end plumbing (ysk_maint_console.exe '维护操作台', added 2026-11-20) ----
# Single-shot mode: -Run "u>8" executes ONE menu item then exits, so the window app never has
# to guess where a stateful REPL is parked. Mid-run prompts are served from the comma-split
# -Arg queue first; queue exhausted -> plain Read-Host (old CLI behaviour kept: on closed
# stdin it returns null -> '' which every existing confirmation already treats as its safe
# cancel/default branch).
$global:RUN_ARGQ = @()
function Ask([string]$prompt) {
    if ($global:RUN_ARGQ.Count -gt 0) {
        $v = $global:RUN_ARGQ[0]
        $global:RUN_ARGQ = @($global:RUN_ARGQ | Select-Object -Skip 1)
        Write-Host ($prompt + '  -> ' + $v + '  (-Arg)')
        return $v
    }
    return Read-Host $prompt
}
function Http($method, $url, $body, $timeout) {
    try {
        $args_ = @{ Method = $method; Uri = $url; UseBasicParsing = $true; TimeoutSec = $timeout }
        if ($body) { $args_.Body = [Text.Encoding]::UTF8.GetBytes($body); $args_.ContentType = "application/json" }
        return (Invoke-WebRequest @args_).StatusCode
    } catch {
        if ($_.Exception.Response) { try { return [int]$_.Exception.Response.StatusCode } catch { } }
        return $null
    }
}
function PortPid($port) {
    $p = (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
          Select-Object -First 1 -ExpandProperty OwningProcess)
    if ($p) { return [int]$p }
    return $null
}
function KillService($label, $port) {
    $pid_ = PortPid $port
    if ($pid_) {
        taskkill /F /T /PID $pid_ 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        Note ("{0} 已请走 (PID {1})" -f $label, $pid_)
        return $true
    }
    Note ("{0} 没在跑, 跳过" -f $label)
    return $false
}
# split "\folder\task" into (path, leaf); bare names pass through (2026-11-18: guard tasks under \ysk\ were invisible to bare /TN)
function SplitTaskPath($task) {
    if ($task -match '^(.*?)\\([^\\]+)$') { return @($Matches[1], $Matches[2]) }
    return @($null, $task)
}
function Get-TaskObj($task) {
    $tp, $tn = SplitTaskPath $task
    if ($tp) { return Get-ScheduledTask -TaskName $tn -TaskPath ($tp + '\') -ErrorAction SilentlyContinue }
    return Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
}
function TaskStop($task) {
    try {
        $t = Get-TaskObj $task
        if ($t) {
            if ($t.State -ne "Disabled") { Disable-ScheduledTask -InputObject $t | Out-Null }
            schtasks /End /TN $task 2>&1 | Out-Null
            Note ("   守护任务 {0} 已停 (不会自嗨重启)" -f $task)
        }
    } catch { Note ("   守护任务 {0} 操作异常: {1}" -f $task, $_.Exception.Message) }
}
# start guard task: Enable first, then Run (same as the inline branch in [2]; helper added 2026-10-18 after [6] crashed on this)
function TaskRun($task) {
    try {
        $t = Get-TaskObj $task
        if ($t -and $t.State -eq "Disabled") { Enable-ScheduledTask -InputObject $t | Out-Null }
        Note ("   守护任务 {0} 已启用" -f $task)
    } catch {
        # 2026-11-17 live test: Enable-ScheduledTask is DENIED by ysk_* task ACLs while plain
        #   'schtasks /Change /ENABLE' still succeeds unelevated. Try the fallback before
        #   declaring the task stuck (261120 audit; ArmKvmemResident had this recipe inline).
        & schtasks /Change /TN $task /ENABLE 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Note ("   Cmdlet 被拒 -- schtasks /Change /ENABLE 兜底成功: {0}" -f $task) }
        else { Note ("   守护启用异常 (非提权常报拒绝访问, 任务 ACL 锁给 Administrators): {0}" -f $_.Exception.Message) }
    }
    $o = (schtasks /Run /TN $task 2>&1) -join " "
    if ($LASTEXITCODE -eq 0) { Note ("   守护任务 {0} 已触发拉起" -f $task); return }
    # 11-13 real case: when the last run sits in zombie 'Finished' state (result 267014), /Run is silently refused; must /End first
    Note ("   /Run 被拒: " + $o.Trim() + " -- 试 /End 清僵尸实例后重试")
    schtasks /End /TN $task 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    $o2 = (schtasks /Run /TN $task 2>&1) -join " "
    if ($LASTEXITCODE -eq 0) { Note ("   重试成功: {0} 已拉起" -f $task); return }
    Note ("   仍被拒: " + $o2.Trim())
    Note "   多半是任务被禁用且 ACL 锁给 Administrators (属主非提权也改不动) -- UAC 提权定式:"
    Note ("     Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command','schtasks /End /TN {0}; schtasks /Change /TN {0} /ENABLE; schtasks /Run /TN {0}'" -f $task)
}
# kill watchdog hosts (bat/cmd/python) by commandline regex, so a stopped service is not resurrected by its own watchdog
function KillGuard($pattern) {
    $n = 0
    Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match $pattern
    } | ForEach-Object {
        taskkill /F /T /PID $_.ProcessId 2>&1 | Out-Null
        $n++
        Note ("   守护宿主已杀 (PID {0})" -f $_.ProcessId)
    }
    if ($n -eq 0) { Note "   没有匹配的守护宿主进程, 跳过" }
}
function HermesMain() {
    try {
        $c = Get-Content $CONFIG -TotalCount 8
        $m = ($c | Select-String -Pattern "^\s*provider:\s*(\S+)" | Select-Object -First 1)
        if ($m) { return $m.Matches[0].Groups[1].Value }
    } catch { }
    return $null
}
# vision routing (2026-10-26 final: all vision goes through 18207 router -- docs/charts/receipts take the OCR
#   head verbatim-first; scenes/design images go straight to the VL head following the main engine;
#   the router probes OCR heads itself, switching needs no config change)
#   OCR heads (2026-11-18 master architecture): GPU-side ONLY = 18205 TeleOCR (~3-5s/page, mounts only when GPU1 has >=2048MB room = single-engine states) | 18201 Xiaomi-OCR-0 dual-mode bat (GPU0 room -> GPU build ~2.8G; full -> auto CPU build ~1min/page zero-VRAM, always available incl. dual-engine) | 18203 retired 11-18 (Ovis weights deleted too)
function SetHermesVision($prov, $model, $url) {
    & $HERMEXE config set auxiliary.vision.provider $prov 2>&1 | Out-Null
    & $HERMEXE config set auxiliary.vision.model $model   2>&1 | Out-Null
    & $HERMEXE config set auxiliary.vision.base_url $url  2>&1 | Out-Null
    & $HERMEXE config set auxiliary.vision.timeout 180    2>&1 | Out-Null
    Note ("   vision 路由 -> " + $prov + " (" + $url + ")")
}
function SetHermesStrata() {
    Note "--- 切换 Hermes 主力 -> strata (8080) ---"
    & $HERMEXE config set model.provider strata                    2>&1 | ForEach-Object { Note ("   " + $_) }
    & $HERMEXE config set model.base_url http://127.0.0.1:8080/v1  2>&1 | ForEach-Object { Note ("   " + $_) }
    & $HERMEXE config set model.key_env HERMES_CUSTOM_STRATA_API_KEY 2>&1 | ForEach-Object { Note ("   " + $_) }
    & $HERMEXE config set model.default Strata-125B 2>&1 | ForEach-Object { Note ("   " + $_) }
    SetHermesVision "ocr" "vision-router" "http://127.0.0.1:18207/v1"   # 10-25/26: all vision goes via the router (OCR head auto-probes 18201)
    Note "   新会话/下一条消息即走 Strata; 当前活跃会话保持原模型不变"
}
function GpuReport() {
    nvidia-smi --query-gpu=index,memory.used,memory.free --format=csv,noheader | ForEach-Object { Note ("   " + $_) }
}
# common yield: unload yosuko-tts GPU endpoint + evict whisper/bonsai + free Ollama (zero-VRAM trio stays: coexists anyway)
# 11-04: senko (Qwen3-TTS lazy) -> yosuko (IndexTTS-2.5, CPU-resident + on-demand GPU dual endpoint); yield only unloads the GPU endpoint
function FreeUpCard() {
    # 261120 building-blocks policy (master): [1] no longer evicts ANY small model -- voice GPU,
    #   whisper and TeleOCR all keep their seats through the cold-load and Strata reshifts its own
    #   layer split instead (proved live 19:45-19:46 with KVMem holding 14.5G on GPU1).
    #   Steps below are commented out, NOT deleted: un-comment to restore the old yield behaviour.
    #   Still active in this flow: ComfyUI eviction (whole-card suite, in SwitchToStrata) + Ollama.
    Note "--- 让位: 小模型一律不清场 (积木模式 261120; 声线GPU/whisper/TeleOCR/小米OCR 全部原地保留) ---"
    # $r = Http "POST" "$T_URL/gpu/unload" $null 20
    # if ($r) { Note "   GPU 端点已让位" } else { Note "   TTS 没跑, 跳过" }
    # foreach ($tk in "ysk_whisper_autostart", $TASK_TL) { TaskStop $tk }
    # KillGuard "ysk_serve_teleocr|ysk_task_teleocr"
    # KillService "whisper-asr" 9003 | Out-Null
    # KillService "TeleOCR 18205" 18205 | Out-Null
    # 2026-11-20 master's call: [1] must NOT clear 18201 (it is the always-available CPU-side OCR).
    #   The zero-VRAM CPU build stays untouched; only a GPU build holding ~2.8G on GPU0 is borrowed
    #   back for the cold-load window, and the re-arm block below brings it right back (the dual-mode
    #   bat then auto-drops to CPU mode on its own once the seats are full).
    if (PortPid 18201) {
        if ((OcrBuildMode) -eq 'cpu') {
            Note "   小米OCR 18201 = CPU 版 (零显存) -- 保留不动, Strata 冷加载不受影响"
        } else {
            # 261120 master's test order -- kept alive, NOT deleted: Strata's VRAM appetite is
            #   elastic (layer-split auto + KV/RAM offload; proved 19:45-19:46 when KVMem took
            #   14.5G on GPU1 first and Strata still cold-loaded fine by reshifting its own
            #   split). So the GPU build of 18201 is left in place through the cold-load and we
            #   watch whether it really needs that seat. Un-comment both lines to restore the
            #   old borrow-back; m>0 always frees the seat by hand.
            Note "   小米OCR 18201 = GPU 版 (占 GPU0 约2.8G) -- 按主人测试令不清除, 直接与 Strata 冷加载共存"
            # KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs"
            # KillService "小米OCR 18201 (GPU版)" 18201 | Out-Null
        }
    }

    Note "--- 让位: Ollama 卸载已装载模型 (keep_alive=0) ---"
    $loaded = @()
    try { $loaded = @(((Invoke-WebRequest -Uri "$O_URL/api/ps" -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json).models) } catch { }
    if ($loaded.Count -eq 0) { Note "   Ollama 没有装载模型, 跳过" } else {
        foreach ($m in $loaded) {
            $payload = @{ model = $m.name; prompt = " "; stream = $false; keep_alive = 0 } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri "$O_URL/api/generate" -Method POST -Body ([Text.Encoding]::UTF8.GetBytes($payload)) `
                    -ContentType "application/json" -UseBasicParsing -TimeoutSec 240 | Out-Null
                Note ("   已请走 {0} (keep_alive=0)" -f $m.name)
            } catch { Note ("   请走失败 {0}: {1}" -f $m.name, $_.Exception.Message) }
        }
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 3
            try { $now = (Invoke-WebRequest -Uri "$O_URL/api/ps" -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json
                  if (-not $now.models.Count) { break } } catch { break }
        }
    }
}
# kill whole Strata tree (strata.exe / strata-vision.exe / serve host)
function KillStrata() {
    taskkill /F /IM "strata.exe" 2>&1 | Out-Null
    taskkill /F /IM "strata-vision.exe" 2>&1 | Out-Null
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match "pythonw?\.exe" -and $_.CommandLine -match "serve[\\/]server\.py"
    } | ForEach-Object { taskkill /F /PID $_.ProcessId 2>&1 | Out-Null; Note ("   serve宿主已杀 (PID {0})" -f $_.ProcessId) }
}

# ---------------------------------------------------------------------------
# [1] switch main model -> Strata
# ---------------------------------------------------------------------------
function SwitchToStrata([bool]$ReArmOcr = $true, [bool]$ReArmTele = $true) {
    Note "=================== Strata 切换开始 ==================="
    Note "GPU 起始:"; GpuReport

    # evict ComfyUI first if running (Strata needs both cards, all 64G handed back)
    if (PortPid 8188) {
        Note "--- ComfyUI 在跑 -> 先请走 (Strata 双卡独占, 与创作不能同时) ---"
        KillService "ComfyUI" 8188 | Out-Null
        Start-Sleep -Seconds 3
    }
    # 2026-11-17 policy flip (master): dual-engine coexistence is the normal form -- KVMem (GPU1 ~14.5G)
    # lives alongside Strata, and its resident guard task is NOT touched here any more.
    # (old 10-09 mutual-exclusion eviction removed; GPU suites like ComfyUI are still evicted above)

    if (PortPid 8080) {
        Note "8080 已在监听 -- 复用当前 Strata, 不重复加载"
    } else {
        FreeUpCard

        Note "--- 启用守护任务并拉起 Strata 8080 ---"
        # TaskRun (261120 audit: this used to be a bare Enable+Run). m>3 DISABLES the task, so
        #   coming back here is exactly where the old code could stall: the Enable-ScheduledTask
        #   cmdlet is ACL-denied on ysk_* from a non-elevated console (2026-11-17 lesson) and a
        #   zombie 'Finished' instance silently refuses /Run (2026-11-13 lesson). TaskRun covers
        #   both (schtasks /Change fallback + /End zombie retry + UAC hint display).
        TaskRun $TASK_S
        Note "   守护已拉起 (serve_strata.bat 会再兜一遍让位再加载)"

        Note "--- 等 Strata 就绪 (262K 冷加载约100s / 512K 实测约9分钟, 最多等20分钟) ---"
        $ready = $false
        for ($i = 0; $i -lt 120; $i++) {
            Start-Sleep -Seconds 10
            if ((Http "GET" $S_URL $null 3) -eq 200) { $ready = $true; break }
            # echo elapsed + free VRAM every 60s (2026-10-20: early cold-load minutes look frozen otherwise)
            if ((($i + 1) % 6) -eq 0) {
                $fb = @(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>$null |
                        Where-Object { "$_".Trim() -match '^\d+$' })
                $rem = (($fb | ForEach-Object { "{0}G" -f [math]::Round([int]$_.Trim()/1024,1) }) -join "/")
                Note ("   加载中... 已等 {0} 分钟, 双卡空闲显存 {1} (权重上传期显存不动属正常; 久不动查 strata-iq3_s.log)" -f [int](($i+1)/6), $rem)
            }
        }
        if (-not $ready) {
            Note "   !! 20分钟未就绪 -- 查 E:\DSDeployMaster\Strata\ysk_serve_console.log 与 strata-iq3_s.log, 再看显存"
            Note "=================== Strata 未就绪, 切换中止 (回菜单可重跑) ==================="
            return
        }
        Note "   Strata 已就绪 OK"
        $c = Http "POST" "http://127.0.0.1:8080/v1/chat/completions" `
            '{"model":"Strata-125B","messages":[{"role":"user","content":"回一个字: 好"}],"max_tokens":10}' 60
        if ($c -eq 200) { Note "   推理实测正常 OK" } else { Note ("   推理实测异常 http={0}" -f $c) }
    }

    # re-arm OCR (2026-11-18 master architecture): 18201 Xiaomi dual-mode bat -- GPU0 free
    # >=2300MB -> GPU build 4-5s/page; seats full -> auto CPU build ~1min/page zero-VRAM
    # (old 300s idle wait removed, dual-engine state needs OCR always available).
    # Also re-arm TeleOCR 18205 guard (GPU-side ONLY head; its bat waits while GPU1 tight,
    # mounts in single-engine states). Router 18207 auto-prefers 18205 when it is up.
    if (-not $ReArmOcr) {
        Note "   (本装配未勾选小米OCR -- 尊重勾选不回挂)"
    } elseif (PortPid 18201) {
        Note ("   小米OCR 18201 在岗未动 (" + (OcrBuildMode) + " 模式) -- 无需回挂")
    } else {
        Note "--- Strata 就绪后自动回挂 18201 小米 (双模式bat按显存自适应 GPU/CPU) ---"
        TaskRun $TASK_OCR
        Start-Sleep -Seconds 8
        # 261120 real case: ysk_ocr_autostart ACL is locked to Administrators -- unelevated Enable
        #   reads as a silent fake-success (Cmdlet) or hard denial (schtasks), and /Run then answers
        #   "could not run because it is disabled" -> 18201 used to stay offline after every [1].
        #   Fallback = the hidden-vbs launcher (zero-VRAM-safe: the bat re-probes GPU0 itself).
        if (-not (PortPid 18201)) {
            Note "   计划任务没能拉起 (任务 Disabled 且 ACL 锁管理员) -- 静默 vbs 直起兜底"
            wscript //nologo $HID_VBS $OCR_BAT 2>&1 | Out-Null
            for ($i = 0; $i -lt 24; $i++) {
                Start-Sleep -Seconds 5
                if ((Http "GET" $OCRG_URL $null 3) -eq 200) { break }
            }
        }
        if (PortPid 18201) { Note ("   18201 已回挂 OK (" + (OcrBuildMode) + " 模式)") } else { Note "   18201 未即时起(权重加载中), 守护/vbs 会自行再来, 不影响Strata" }
    }
    # 261121 lesson: this legacy re-arm ignored the assembly's checkboxes and schtasks /Run
    #   fired the DISABLED task's loop host anyway -- the host then auto-mounted teleOCR on
    #   GPU1 and stole the voice line's seat. Assembly passes its own will; [1] keeps old
    #   auto-preference behaviour (defaults stay true).
    if (-not $ReArmTele) {
        Note "   (本装配未勾选 TeleOCR -- 尊重勾选，不再自动回挂/点火)"
    } elseif (-not (PortPid 18205)) {
        Note "--- 回挂 TeleOCR 守护 (18205, GPU1 有座时自动上岗; 双引擎态罚站属正常) ---"
        TaskRun $TASK_TL
    }

    SetHermesStrata
    Note "--- 终态 ---"
    Note "   双卡显存:"; GpuReport
    Note ("8080 http={0}" -f (Http "GET" $S_URL $null 3))
    Note "=================== Strata 切换完成 ==================="
}

# ---------------------------------------------------------------------------
# [m>3] clean Strata exit (stop 8080 process tree)
# ---------------------------------------------------------------------------
function CleanupStrata {
    Note "=================== 清洁退出 Strata 主力 ==================="
    Note "GPU 起始:"; GpuReport
    Note "--- 停守护任务 (防 RestartOnFailure 顶回来) ---"
    TaskStop $TASK_S
    # 261120 audit: schtasks /End only kills the task root -- the wscript-spawned bat host can
    #   survive as an orphan and its probe loop relaunches Strata minutes later (2026-10-22 real
    #   case). Every other Strata stop path ([2]/u>1/u>2/rollback kit) carries this KillGuard;
    #   m>3 was the odd one out.
    KillGuard "ysk_serve_strata|ysk_task_strata"
    Note "--- 杀 Strata 进程树 ---"
    KillStrata
    Start-Sleep -Seconds 3
    $alive = tasklist 2>&1 | Select-String -Pattern "strata"
    if ($alive) { Note "   !! 仍有 strata 进程:"; $alive | ForEach-Object { Note ("     " + $_.Line) } } else { Note "   strata 进程已全部退出" }
    if (PortPid 8080) { Note "   !! 8080 仍有残留, 见日志排查" } else { Note "   8080 已下线, 显存归还系统" }
    Note "   双卡显存:"; GpuReport
    if ((HermesMain) -eq "strata") {
        Note "   提醒: Hermes 主力仍指 strata 但已下线 -- 请切 KVMem[2] 或重启 Hermes 会话"
    }
    Note "=================== Strata 清洁退出完成 ==================="
}

# ---------------------------------------------------------------------------
# [2] switch to KVMem (auto-stops Strata; GPU1 single card ~16G, GPU0 whole card reserved for ComfyUI creative)
# ---------------------------------------------------------------------------
function SetHermesKvmem() {
    Note "--- 切换 Hermes 主力 -> kvmem (18200) ---"
    & $HERMEXE config set model.provider kvmem             2>&1 | ForEach-Object { Note ("   " + $_) }
    & $HERMEXE config set model.base_url http://127.0.0.1:18200/v1 2>&1 | ForEach-Object { Note ("   " + $_) }
    & $HERMEXE config set model.key_env HERMES_CUSTOM_KVMEM_API_KEY 2>&1 | ForEach-Object { Note ("   " + $_) }
    & $HERMEXE config set model.default KVMem-27B 2>&1 | ForEach-Object { Note ("   " + $_) }
    SetHermesVision "ocr" "vision-router" "http://127.0.0.1:18207/v1"   # 10-25/26: all vision goes via the router (OCR head auto-probes TeleOCR 18205)
    Note "   新会话/下一条消息即走 KVMem; 当前活跃会话保持原模型不变"
}
function SwitchToKvmem {
    Note "=================== KVMem 单独切换开始 ==================="
    Note "GPU 起始:"; GpuReport
    # KVMem-SOLO entry: coexistence with Strata is legal since 11-17, but this mode intentionally stops Strata
    # to hand GPU0's WHOLE card to GPU suites (the suite co-op form). Evict also while still cold-loading.
    # 2026-10-20 fix: probing only port 8080 has a blind spot -- during cold load the port is not yet
# listening but the process already queues/eats VRAM; that day KVMem started mid-load, both fought for VRAM and Strata died in a 3-min loaded->collapsed loop
    $strataBusy = (PortPid 8080) -or @(Get-Process -Name "strata","strata-vision" -ErrorAction SilentlyContinue)
    if ($strataBusy) {
        Note "--- 进入 KVMem 单独协同模式: 停 Strata, GPU0 整卡让给 GPU 套件 (双引擎与单独态是两种可选形态) ---"
        TaskStop $TASK_S
        KillGuard "ysk_serve_strata|ysk_task_strata"
        KillStrata
        # TeleOCR 18205 also holds VRAM, evict together (it re-arms later in the KVMem scene)
        TaskStop $TASK_TL
        KillGuard "ysk_serve_teleocr|ysk_task_teleocr"
        KillService "TeleOCR 18205" 18205 | Out-Null
        # 2026-10-22 final: poll until strata processes actually die, then write the handoff flag -- corpses
        # take 1-3 min to drain; the kvmem guard bat once mistook a lingering corpse for 'running' and stalled 600s.
        $gone = $false
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 5
            if (-not @(Get-Process -Name "strata","strata-vision" -ErrorAction SilentlyContinue)) { $gone = $true; break }
        }
        if ($gone) { Set-Content -Path $K_FLAG -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Encoding UTF8; Note "   Strata 已断气, 交接旗已写 (kvmem守护跳过尸身复查)" } else { Note "   !! 150s 内 strata 未断气 (守护bat自会按显存预检兜底)" }
        if (PortPid 8080) { Note "   !! 8080 仍残留" } else { Note "   Strata 已下线" }
    }
    Note "--- 拉起 KVMem (18200, GPU1 单卡, 独立引擎+独立模型) ---"
    if (PortPid 18200) {
        Note "   18200 已在监听 -- 复用当前 KVMem"
    } else {
        TaskRun $TASK_K
        $kready = $false
        for ($i = 0; $i -lt 60; $i++) {   # measured load ~20s, keep 5 min margin
            Start-Sleep -Seconds 5
            if ((Http "GET" "http://127.0.0.1:18200/v1/models" $null 3) -eq 200) { $kready = $true; break }
        }
        if (-not $kready) {
            Note "   !! KVMem 5分钟未就绪 -- 查 E:\DSDeployMaster\ysk_autostart\kvmem_server.log"
            Note "=================== KVMem 未就绪, 切换中止 (回菜单可重跑) ==================="
            return
        }
        Note "   KVMem 已就绪 OK"
        $c = Http "POST" "http://127.0.0.1:18200/v1/chat/completions" `
            '{"model":"KVMem-27B","messages":[{"role":"user","content":"回一个字: 好"}],"max_tokens":10}' 60
        if ($c -eq 200) { Note "   推理实测正常 OK" } else { Note ("推理实测异常 http=" + $c) }
    }
    # --- scene vision orchestration (2026-10-25 final: both [1] and [2] funnel here, one wiring point governs all) ---
    #     evict OCR-GPU 18201 first (TeleOCR covers vision in KVMem/creative scenes; GPU0 whole card freed for ComfyUI),
    #     then arm TeleOCR 18205; router 18207 probes heads automatically, Hermes config untouched
    if (PortPid 18201) {
        Note "--- 请走 小米18201 (KVMem/创作场景视觉由 TeleOCR 顶班; 双引擎并存时18201应留CPU模式) ---"
        TaskStop $TASK_OCR
        KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs"
        KillService "OCR-GPU版 18201" 18201 | Out-Null
    }
    if (PortPid 18205) {
        Note "   TeleOCR 18205 已在监听 -- 复用"
    } else {
        Note "--- 上岗 TeleOCR 18205 (KVMem/创作场景视觉主力OCR头, 守护任务接管, 最多2分钟) ---"
        TaskRun $TASK_TL
        $tready = $false
        for ($i = 0; $i -lt 24; $i++) {
            Start-Sleep -Seconds 5
            if (PortPid 18205) { $tready = $true; break }
        }
        if ($tready) { Note "   TeleOCR 18205 就绪 OK (18207 网关自动探到切换)" } else { Note "   !! TeleOCR 2分钟未监听 -- 查 teleocr_server.log (GPU1 余量不足?)" }
    }
    # probe vision router 18207 (zero-VRAM CPU daemon; if it dies all vision goes blind -- revive on sight)
    if (-not (PortPid 18207)) {
        Note "   !! 18207 视觉分流网关离线 -- 拉起"
        TaskRun $TASK_R
        Start-Sleep -Seconds 5
        if (PortPid 18207) { Note "   18207 已复活 OK" } else { Note "   !! 18207 未起 -- c>7排查" }
    }
    SetHermesKvmem
    Note "--- 终态 ---"
    Note "   双卡显存:"; GpuReport
    Note ("18200 http=" + (Http "GET" $K_URL $null 3))
    Note "=================== KVMem 单独切换完成 ==================="
}

# ---------------------------------------------------------------------------
# [m>1] creative workstation up: KVMem main (GPU1) + TeleOCR + ComfyUI (whole GPU0)
#     VRAM budget: GPU1 = KVMem~16G + TTS~4G + TeleOCR~2.5G + light imggen ~10G | GPU0 = all heavy creative
#     heaviest single job: Animate-14B ~30G (evict TTS/whisper via m/others first if tight)
# ---------------------------------------------------------------------------
function CreativeWorkspace {
    Note "=================== 创作工作站一键起 ==================="
    SwitchToKvmem
    # scene OCR head already orchestrated to TeleOCR 18205 by SwitchToKvmem (2026-10-25 final); do not pull 18201 here
    StartComfyUI
    Note "--- 工作站终态 ---"
    Note "   GPU0 = ComfyUI 创作主卡(出图/视频/3D) | GPU1 = KVMem 主力 + TTS/TeleOCR"
    Note "   出图快轨与 5B 视频可与聊天并行; Animate/A14B/HY720p 等 24G+ 重活前先跑 m>5 Ollama卸载 + c>6 whisper关闭 再挤一挤"
    Note "=================== 创作工作站就绪 ==================="
}

# [m>2] workstation teardown: evict ComfyUI + OCR-GPU + KVMem in order
function CleanupWorkspace {
    Note "=================== 创作工作站拆除 ==================="
    Note "GPU 起始:"; GpuReport
    KillService "ComfyUI" 8188 | Out-Null
    TaskStop $TASK_OCR
    KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs"
    KillService "OCR-GPU版 18201" 18201 | Out-Null
    CleanupKvmem
    Note "   工作站已整体拆除 (Strata/Hermes 配置未动)"
    Note "=================== 拆除完成 ==================="
}

# ---------------------------------------------------------------------------
# [m>4] clean KVMem exit (stop 18200 only, never touch Strata)
# ---------------------------------------------------------------------------
function CleanupKvmem {
    Note "=================== 清洁退出 KVMem ==================="
    Note "GPU 起始:"; GpuReport
    TaskStop $TASK_K
    KillGuard "ysk_serve_kvmem|ysk_task_kvmem"
    # TeleOCR only serves KVMem/creative scenes, evict along (2026-10-25 final: m>2 and m>4 both pass here)
    TaskStop $TASK_TL
    KillGuard "ysk_serve_teleocr|ysk_task_teleocr"
    KillService "TeleOCR 18205" 18205 | Out-Null
    taskkill /F /IM "ninfer-kvmem-server.exe" 2>&1 | Out-Null
    taskkill /F /IM "llama-kvmem-server.exe" 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    if (PortPid 18200) { Note "   !! 18200 仍有残留, 见日志排查" } else { Note "   18200 已下线, 显存归还系统" }
    Note "   双卡显存:"; GpuReport
    if ((HermesMain) -eq "kvmem") {
        Note "   提醒: Hermes 主力仍指 kvmem 但已下线 -- 请切 Strata[1] 或重启 Hermes 会话"
    }
    Note "=================== KVMem 清洁退出完成 ==================="
}

# ---------------------------------------------------------------------------
# [m>8] KVMem resident ignition WITHOUT evicting Strata (dual-engine form, 2026-11-17 master's call:
#       Strata = main chat, KVMem = always-on spare/clone; guard stays enabled for auto-respawn)
# ---------------------------------------------------------------------------
function ArmKvmemResident([string]$Pick = 'auto') {
    $pk = switch ($Pick) { 'gpu0' { '0' } default { '1' } }
    $pkName = switch ($Pick) { 'cpu' { 'CPU(ninfer不支持)' } 'gpu0' { 'GPU0' } default { 'GPU1' } }
    if ($Pick -eq 'cpu') { Note "=================== KVMem 无 CPU 形态 (ninfer 容器需 GPU; 要清显存按 m>4 清洁退出) ==================="; return }
    Note ("=================== KVMem 常驻点火 · 指定卡 " + $pkName + " · 不动 Strata ===================")
    Note "GPU 起始:"; GpuReport
    if (PortPid 8080) { Note "   Strata 8080 在线 -- 主力仍 Strata, 本项只补 KVMem 备胎体" } else { Note "   注意: Strata 当前离线 -- KVMem 先起, Strata 守护上线后即成双引擎" }
    if (PortPid 18200) {
        Note "   18200 已在监听 -- 复用当前 KVMem (不走 TaskRun, 守护不被误杀)"
    } else {
        $g1k = GpuFreeMib ([int]$pk)
        if ($g1k -lt 14800) {
            Note ("   !! " + $pkName + " 空闲 " + [math]::Round($g1k/1024,1) + "GB -- 不足落座门槛 14800MB(约14.45GB), KVMem 无空间 (先 m>5 卸 Ollama / m>4 清 KVMem 残骸 / 换另一张卡再试)")
            return
        }
        Note ("--- 点火 KVMem (18200, " + $pkName + ", 直起 bat 带 YSK_GPU; serve 环自带 60s 重试) ---")
        $env:YSK_GPU = $pk
        wscript //nologo $HID_VBS "E:\DSDeployMaster\ysk_autostart\ysk_serve_kvmem.bat" 2>&1 | Out-Null
        Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
        $kready = $false
        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Seconds 5
            if ((Http "GET" $K_URL $null 3) -eq 200) { $kready = $true; break }
        }
        if (-not $kready) {
            Note "   !! KVMem 5分钟未就绪 -- 查 E:\DSDeployMaster\ysk_autostart\kvmem_server.log"
            Note "=================== 双引擎未就绪, 中止 (回菜单可重跑) ==================="
            return
        }
        Note "   KVMem 已就绪 OK (实测加载约28s)"
        $ck = Http "POST" "http://127.0.0.1:18200/v1/chat/completions" `
            '{"model":"KVMem-27B","messages":[{"role":"user","content":"回一个字: 好"}],"max_tokens":10}' 60
        if ($ck -eq 200) { Note "   推理实测正常 OK" } else { Note ("推理实测异常 http=" + $ck) }
    }
    # resident-by-design: guard task stays ENABLED so a dead KVMem respawns on its own
    # (bat 2026-11-17 dropped the 'Strata online -> watcher self-exit' rule; gate = GPU1 free >= 14800MB)
    # NOTE: Enable-ScheduledTask cmdlet is DENIED by ysk_* task ACL (11-17 m>8 live test); schtasks /Change works (same as TaskStop/TaskRun)
    & schtasks /Change /TN $TASK_K /ENABLE 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Note "   KVMem 守护任务已启用 (猝死自动复活)" } else { Note ("   !! schtasks /Change /ENABLE 失败 exit=" + $LASTEXITCODE + " -- 需管理员权限，请以管理员身份重开操作台处理") }
    if ($pk -eq '0') { Note "   提醒: 本次直起坐 GPU0; 若日后守护任务自动复活会回到 bat 内置默认卡 GPU1 (守护环境不带 YSK_GPU)" }
    Note "--- 终态 ---"
    Note "   双卡显存:"; GpuReport
    Note ("   8080 http=" + (Http "GET" $S_URL $null 3) + "   18200 http=" + (Http "GET" $K_URL $null 3))
    Note "   双引擎并行显存满座=正常设计; 要起 GPU 套件请先回一级 [2] 单独态或 m>1 一键工作站"
    Note "=================== 双引擎并行就绪 ==================="
}

# ---------------------------------------------------------------------------
# local maintenance area (2026-10-17: Hermes self-check/repair / pwsh env / VPN / health check / misc)
# ---------------------------------------------------------------------------
$SB_DIR    = "D:\ProgramFiles\sing-box"
# sing-box exe lives under a version subdir (found during the 2026-10-25 double-launch pitfall); glob newest so upgrades need no edit
$SB_EXE    = @(Get-ChildItem "D:\ProgramFiles\sing-box\sing-box-*-windows-amd64\sing-box.exe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).FullName
$SB_VBS    = "E:\DSDeployMaster\ysk_autostart\ysk_task_singbox.vbs"
$PROXY_KEY = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$HERMES_BIN  = "D:\ProgramFiles\Hermes_Desktop\hermes-agent\.hermes\bin"
$HERMES_HOME = "D:\ProgramFiles\Hermes_Desktop\hermes-agent"

# [h>1] Hermes self-check
function HermesSelfCheck {
    Note "=================== Hermes 自检 ==================="
    Note "--- hermes status (组件状态) ---"
    & $HERMEXE status 2>&1 | ForEach-Object { Note ("   " + $_) }
    Note "--- hermes doctor (配置与依赖体检) ---"
    & $HERMEXE doctor 2>&1 | ForEach-Object { Note ("   " + $_) }
    Note "=================== Hermes 自检完成 ==================="
}

# [h>2] Hermes repair (historic pitfall: restrictive ACL missing Dtxmzh on tools/cron/plugins, hit twice 10-02 & 10-05)
function HermesRepair {
    Note "=================== Hermes 修复 (ACL补权) ==================="
    foreach ($d in @("D:\ProgramFiles\Hermes_Desktop\tools",
                     "D:\ProgramFiles\Hermes_Desktop\cron",
                     "D:\ProgramFiles\Hermes_Desktop\plugins")) {
        if (Test-Path $d) {
            Note ("   icacls " + $d)
            icacls $d /grant "$($env:USERNAME):(OI)(CI)F" /T /Q 2>&1 | Select-Object -Last 1 | ForEach-Object { Note ("   " + $_) }
        }
    }
    Note "--- doctor 复查 ---"
    & $HERMEXE doctor 2>&1 | ForEach-Object { Note ("   " + $_) }
    Note "=================== Hermes 修复完成 ==================="
}

# [h>4] Hermes pwsh env (EncodedCommand avoids quoting hell)
function OpenHermesPwsh {
    Note "--- 弹新 pwsh 窗口 (Hermes 环境就绪) ---"
    $cmd = '$env:PATH="' + $HERMES_BIN + ';"+$env:PATH; Set-Location "' + $HERMES_HOME + '"; Write-Host "Hermes pwsh 环境就绪: 可直接敲 hermes 命令 (hermes --help)" -ForegroundColor Green'
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process pwsh -ArgumentList @('-NoExit','-NoProfile','-EncodedCommand',$enc)
    Note "   已打开 (PATH含hermes bin, 工作目录=hermes-agent)"
}

# [h>3] restart gateway
function RestartGateway {
    Note "=================== Hermes 网关重启 ==================="
    Note "提醒: 当前聊天会话会短暂断开 (桌面/微信稍后自动重连)"
    & $HERMEXE gateway restart 2>&1 | ForEach-Object { Note ("   " + $_) }
    Note "=================== 网关重启指令已发出 ==================="
}

# [h>5] VPN status
function VpnStatus {
    Note "=================== VPN 状态 ==================="
    $sb = Get-Process -Name "sing-box" -ErrorAction SilentlyContinue
    if ($sb) { Note ("   sing-box 进程: 在跑 (PID " + ($sb.Id -join ',') + ")") } else { Note "   sing-box 进程: 没在跑" }
    $pe = (Get-ItemProperty $PROXY_KEY -ErrorAction SilentlyContinue).ProxyEnable
    Note ("   系统代理 ProxyEnable = " + $pe + $(if ($pe -eq 1) { " (开)" } else { " (关)" }))
    if (PortPid 10808) {
        Note "   10808 监听: OK, 实测外网连通 (google, 15s 超时)..."
        $code = & curl.exe -x http://127.0.0.1:10808 -m 15 -s -o NUL -w "%{http_code}" https://www.google.com
        if ("$code" -eq "302" -or "$code" -eq "204") { Note ("   外网实测: 通 OK (http " + $code + ")") } else { Note ("   外网实测: http=" + $code + " (000=不通)") }
        # tunnel speed test (2026-11-03: recovery bar = 5MB/s per master 10-16; note: VPS weekly reboot tears down the 8899 tester, rebuild first)
        Note "   隧道测速 (8MB 样本, 25s 上限)..."
        $spd = & curl.exe -x http://127.0.0.1:10808 -m 25 -s -r 0-8388607 -o NUL -w "%{speed_download}" http://23.238.1.245:8899/speedtest.bin
        $v = 0.0; [void][double]::TryParse("$spd", [ref]$v)
        if ($v -gt 5242880)      { Note ("   测速 {0}MB/s -- 过 5MB/s 恢复线, VPN 可用 OK" -f [math]::Round($v/1MB,2)) }
        elseif ($v -gt 0)        { Note ("   测速 {0}MB/s -- 未过 5MB/s 恢复线, 大文件下载仍建议走国内镜像" -f [math]::Round($v/1MB,2)) }
        else                     { Note "   测速失败 -- VPS 8899 测速服务不在(周三重启自撤)或隧道已死" }
    } else {
        Note "   10808 监听: 无 (VPN 未启动)"
    }
    Note "=================== VPN 状态完成 ==================="
}

# [h>6] VPN start (sing-box config.json already sets system proxy; registry double-checked here)
function VpnStart {
    Note "=================== VPN 启动 ==================="
    if (-not (PortPid 10808)) {
        # launch fully invisible via wscript vbs (2026-10-25 ghost-window final: Start-Process -WindowStyle Hidden
        # gets hijacked by Terminal.App and leaves a ghost host window; wscript SW_HIDE leaves zero. -ArgumentList needs parens)
        if (-not $SB_EXE -or -not (Test-Path $SB_EXE)) { Note "   !! 找不到 sing-box (版本子目录 glob 失败)"; return }
        if (-not (Test-Path $SB_VBS)) { Note ("   !! 缺启动 vbs: " + $SB_VBS); return }
        Note "--- 拉起 sing-box (mixed 10808, vbs 全隐形) ---"
        Start-Process wscript.exe -ArgumentList ('"' + $SB_VBS + '"')
        $ok = $false
        for ($i=0; $i -lt 10; $i++) { Start-Sleep -Seconds 2; if (PortPid 10808) { $ok=$true; break } }
        if (-not $ok) { Note "   !! 20秒未起 10808 -- 查 sing-box.log" } else { Note "   sing-box 已起 OK" }
    } else { Note "   sing-box 已在跑, 复用" }
    Set-ItemProperty -Path $PROXY_KEY -Name ProxyEnable -Value 1
    Set-ItemProperty -Path $PROXY_KEY -Name ProxyServer -Value "127.0.0.1:10808"
    Note "   系统代理已指向 127.0.0.1:10808 (开)"
    VpnStatus
    Note "=================== VPN 启动完成 ==================="
}

# [h>7] VPN stop
function VpnStop {
    Note "=================== VPN 关闭 ==================="
    Stop-Process -Name "sing-box" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $PROXY_KEY -Name ProxyEnable -Value 0
    Start-Sleep -Seconds 2
    if (PortPid 10808) { Note "   !! 10808 仍残留" } else { Note "   sing-box 已停, 系统代理已关 (ProxyEnable=0)" }
    Note "=================== VPN 关闭完成 ==================="
}

# [3] one-shot full health check
function FullHealth {
    Note "=================== 一键服务体检 ==================="
    # 261120 audit: dropped the dead 18203 row -- that CPU-OCR port/bat/task was dismantled on
    #   2026-11-18 (18201 Xiaomi now runs a dual-mode GPU/CPU bat), so it could only ever show '--'.
    $svcs = [ordered]@{
        "Strata 8080"=8080; "KVMem 18200"=18200
        "小米OCR 18201双模式"=18201; "调度官 18202"=18202
        "TeleOCR 18205"=18205; "视觉网关 18207"=18207
        "嵌入 18303"=18303; "重排 18304"=18304; "Ollama 11434"=11434
        "TTS 9210"=9210; "whisper 9003"=9003; "ComfyUI 8188"=8188
        "sql-proxy 8090"=8090; "filesrv 9000"=9000; "Tika 19998"=19998
        "Dify 52180"=52180; "WebUI 3303"=3303; "SearXNG 8808"=8808
        "Jupyter 8208"=8208; "VPN 10808"=10808
    }
    $line = ""
    foreach ($k in $svcs.Keys) {
        $mark = if (PortPid $svcs[$k]) { "OK" } else { "--" }
        $line += ("{0}:{1} | " -f $k, $mark)
    }
    Note $line
    if (-not (PortPid 18304)) {
        # 2026-11-19 master ruling: the reranker is by-design on-demand (ignite, serve, stop).
        #   An offline 18304 is NOT a fault -- say so before the '--' in the table alarms anyone.
        Note "   重排 18304 离线属设计内 (按需点火, 跑完即停; 11-19 定版) -- 非故障"
    }
    if ((PortPid 8080) -and (PortPid 18200)) {
        Note "   ⚙ 双引擎并行 (261117 起正式常态): 64G 满座属设计内; GPU 套件 (ComfyUI/whisper/OCR-GPU/TTS-GPU) 要进场请先 [2] 切 KVMem 单独态或 m>1 一键工作站"
    }
    Note "   双卡显存:"; GpuReport
    # C=system D=apps E=models F=home-data (261117 disk layout final) -- F added by the 261120
    #   audit: the archives/backups all live on F and used to be invisible to the health check.
    foreach ($drv in @("C","D","E","F")) {
        $d = Get-PSDrive $drv -ErrorAction SilentlyContinue
        if ($d) { Note ("   盘 " + $drv + ": 空闲 " + [math]::Round($d.Free/1GB,1) + " GB") }
    }
    # engine version line (2026-11-12: health check used to omit engine versions; master kept asking 'which build is running')
    try { Note ("   " + (EngineVerLine).Trim()) } catch { Note "   引擎版本: 读不出" }
    # live context windows (261120: 512K went into service -- max_context is now something the
    #   master verifies after every engine/config change, so pull it straight from the health API)
    foreach ($ctxp in @(@("Strata 8080", "http://127.0.0.1:8080/health"), @("KVMem 18200", "http://127.0.0.1:18200/health"))) {
        try {
            $hh = (& curl.exe -s --noproxy '*' --max-time 5 $ctxp[1]) | ConvertFrom-Json
            if ($hh.max_context) { Note ("   " + $ctxp[0] + " max_context=" + $hh.max_context) }
        } catch { }
    }
    try {
        $tags = (& git -C "E:\DSDeployMaster\Strata" tag --sort=-v:refname 2>&1 | Select-Object -First 1)
        $te = StrataTagEngineVer -tag "$tags"
        $run = StrataEngineVer
        if ($te) {
            if ((VerKey $te) -gt (VerKey $run)) {
                Note ("   Strata 官方最新 tag: " + $tags + " (引擎 " + $te + ")  ⚠比在役 exe " + $run + " 新 -- 想升走 u>1")
            } else {
                Note ("   Strata 官方最新 tag: " + $tags + " (引擎 " + $te + ")  已在最新线")
            }
        }
    } catch { }
    try {
        if (Test-Path $RECEIPT_DIR) {
            $f = @(Get-ChildItem $RECEIPT_DIR -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
            if ($f.Count) { Note ("   最近引擎操作: " + $f[0].LastWriteTime.ToString("yyyy-MM-dd HH:mm") + "  " + $f[0].Name + " (明细走 u>7)") }
        }
    } catch { }
    Note "=================== 体检完成 ==================="
}

# [m>5] free Ollama
function FreeOllama {
    Note "--- Ollama 卸载 (keep_alive=0) ---"
    # do NOT probe with /api/generate on an empty model: Ollama answers 404 (model not found) and looks dead
    # correct: list loaded models via /api/ps, then keep_alive=0 each (same recipe as FreeUpCard)
    $loaded = @()
    try { $loaded = @(((Invoke-WebRequest -Uri "$O_URL/api/ps" -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json).models) } catch {
        Note "   Ollama 未响应, 可能没在跑"; return
    }
    if ($loaded.Count -eq 0) { Note "   Ollama 在跑, 没有装载模型, 无需卸载" } else {
        foreach ($m in $loaded) {
            $payload = @{ model = $m.name; prompt = " "; stream = $false; keep_alive = 0 } | ConvertTo-Json -Compress
            try {
                Invoke-WebRequest -Uri "$O_URL/api/generate" -Method POST -Body ([Text.Encoding]::UTF8.GetBytes($payload)) `
                    -ContentType "application/json" -UseBasicParsing -TimeoutSec 240 | Out-Null
                Note ("   已请走 {0} (keep_alive=0)" -f $m.name)
            } catch { Note ("   请走失败 {0}: {1}" -f $m.name, $_.Exception.Message) }
        }
    }
}

# [c>1] ComfyUI up (GPU0 creative card, 8G gate; only in KVMem workstation mode -- impossible while Strata holds both cards)
function StartComfyUI([string]$Pick = 'auto') {
    $pk = switch ($Pick) { 'gpu1' { '1' } 'cpu' { '-1' } default { '0' } }
    $pkName = switch ($Pick) { 'cpu' { 'CPU(--cpu 极慢)' } 'gpu1' { 'GPU1' } default { 'GPU0' } }
    Note ("=================== ComfyUI 启动 (" + $pkName + ") ===================")
    if (PortPid 8188) { Note "   ComfyUI 已在跑 (8188), 复用"; return }
    if ($Pick -eq 'cpu') {
        # comfy wants the explicit --cpu flag (a plain hidden-CUDA boot dies on import guards)
        $env:COMFY_EXTRA = '--cpu'
    } else {
        $freeMb = GpuFreeMib ([int]$pk)
        if ($freeMb -lt 8000) {
            Note ("   !! " + $pkName + " 空闲仅 " + [math]::Round($freeMb/1024,1) + "GB -- Strata 大概率在双卡独占")
            Note "      换另一张卡 / 先一级 [2] 切 KVMem 创作协同整卡让出 / 或选 CPU, 再回来重开"
            return
        }
        if ($freeMb -lt 24000) {
            Note ("   提示: " + $pkName + " 空闲 " + [math]::Round($freeMb/1024,1) + "GB -- 出图/5B视频/HY480p/TRELLIS 够用;")
            Note "         Animate/A14B/HY720p 等 24G+ 重活前请先跑 m>5 Ollama卸载 + c>6 whisper关闭 再挤一挤"
        }
    }
    $vbs = "E:\DSDeployMaster\ysk_autostart\ysk_task_comfy.vbs"
    if (-not (Test-Path $vbs)) { Note ("   !! 缺启动 vbs: " + $vbs); return }
    $env:YSK_GPU = $pk
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
    Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
    if ($Pick -eq 'cpu') { Remove-Item Env:COMFY_EXTRA -ErrorAction SilentlyContinue }
    $ok = $false
    for ($i=0; $i -lt 36; $i++) { Start-Sleep -Seconds 5; if (PortPid 8188) { $ok=$true; break } }
    if ($ok) { Note ("   ComfyUI 已就绪 OK (http://127.0.0.1:8188, " + $pkName + ")") } else { Note "   !! 3分钟未就绪 -- 看 comfyui_server.log" }
    Note "==================="
}

# [c>2] ComfyUI down
function StopComfyUI {
    Note "--- ComfyUI 关闭 ---"
    KillService "ComfyUI" 8188 | Out-Null
}

# [c>5] whisper ASR up
function StartWhisper([string]$Pick = 'auto') {
    $pk = switch ($Pick) { 'gpu0' { '0' } 'cpu' { '-1' } default { '1' } }
    $pkName = switch ($Pick) { 'cpu' { 'CPU(int8, 零显存慢)' } 'gpu0' { 'GPU0' } default { 'GPU1' } }
    Note ("=================== whisper ASR 启动 (" + $pkName + ") ===================")
    if (PortPid 9003) { Note "   9003 已在监听, 复用"; return }
    # 261120 card pick: env YSK_GPU rides to start.bat; -1 hides CUDA -> CPU int8. ~4-5G GPU
    # footprint needs an admission gate on the PICKED card (Strata full cards OOM instantly).
    if ($Pick -ne 'cpu') {
        $g1w = GpuFreeMib ([int]$pk)
        if ($g1w -lt 6000) {
            Note ("   !! " + $pkName + " 空闲仅 " + [math]::Round($g1w/1024,1) + "GB -- 显存满座 (Strata/双引擎), whisper 挤不下")
            Note "      换另一张卡 / 选 CPU / 或一级 [2] 切 KVMem 单独态腾地方再来"
            return
        }
    }
    $vbs = "E:\DSDeployMaster\ysk_autostart\ysk_task_whisper.vbs"
    if (-not (Test-Path $vbs)) { Note ("   !! 缺启动 vbs: " + $vbs); return }
    $env:YSK_GPU = $pk
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
    Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
    $ok = $false
    for ($i=0; $i -lt 24; $i++) { Start-Sleep -Seconds 5; if (PortPid 9003) { $ok=$true; break } }
    if ($ok) { Note "   whisper 已就绪 OK (9003)" } else { Note "   !! 2分钟未就绪 -- 查 whisper-asr 日志" }
}

# [c>6] whisper ASR down
function StopWhisper {
    Note "--- whisper ASR 关闭 ---"
    TaskStop "ysk_whisper_autostart"
    KillGuard "task_whisper\.vbs|whisper-asr.*start\.bat|ysk_serve_whisper"
    KillService "whisper-asr" 9003 | Out-Null
}

# [m>6] TeleOCR-CPU emergency up (repurposed 2026-11-18: 18203 retired with its Ovis weights.
#   Dual-engine mainline OCR is 18201 Xiaomi auto-CPU mode (~1min/page); this entry is only
#   for emergencies/A-B runs. TeleCPU measured 26min/page on 4.3MP -- slow, no autostart.)
function StartOcrCpu {
    Note "=================== TeleCPU 应急拉起 (18205) ==================="
    if (PortPid 18205) {
        Note "   18205 已在监听 -- 直接复用 (双引擎态下此即 CPU 模式 ~26min/页)"
        return
    }
    Note "   日常主力=18201 小米(双模式自动) , 本入口仅应急/对比实测用"
    wscript //nologo $HID_VBS $TL_CPU_BAT 2>&1 | Out-Null
    $cok = $false
    for ($i = 0; $i -lt 24; $i++) {   # CPU weights load measured 30s~2min
        Start-Sleep -Seconds 5
        if ((Http "GET" "http://127.0.0.1:18205/v1/models" $null 3) -eq 200) { $cok = $true; break }
    }
    if ($cok) { Note "   TeleCPU 应急已起 OK (18205, ~26min/页, 不开机自启)" } else { Note "   !! 18205 两分钟未就绪 -- 查 teleocr_server.log" }
}
# [m>7] TeleCPU emergency stand down (kills the 18205 CPU instance; in single-engine states
#   18205 is the TeleGPU main head and should NOT be stopped -- check state before using)
function StopOcrCpu {
    Note "=================== TeleCPU 应急收回 ==================="
    KillGuard "ysk_run_teleocr_cpu\.bat"
    KillService "TeleCPU应急 18205" 18205 | Out-Null
    Note "   双引擎态 OCR 自动回 18201 小米(CPU模式), router 自行择优无需改配置"
    Note "=================== TeleCPU 收回完成 ==================="
}

# Which build the 18201 endpoint runs: 'cpu' (-ngl 0, zero VRAM, ~1min/page) | 'gpu' (-ngl 99,
#   ~2.8G on GPU0, 4-5s/page) | $null when the port has no listener. Read from the live command
#   line because the dual-mode bat picks the build by GPU0 free space at start time only.
function OcrBuildMode {
    $p = PortPid 18201
    if (-not $p) { return $null }
    $c = (Get-CimInstance Win32_Process -Filter "ProcessId=$p" -ErrorAction SilentlyContinue).CommandLine
    if (-not $c) { return 'gpu' }
    if ($c -match '-ngl\s+0(\s|$)') { return 'cpu' }
    return 'gpu'
}
function GpuFreeMib($idx) {
    $f = @(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>$null | Where-Object { "$_".Trim() -match '^\d+$' })
    if ($f.Count -gt $idx) { return [int]$f[$idx].Trim() }
    return 0
}

# [m>9] mount 18201 Xiaomi-OCR on GPU0 as the GPU build (2026-11-20 master's request: a manual
#   lever onto/off the GPU seat). The dual-mode bat itself decides GPU/CPU by GPU0 free space,
#   so this entry = guarantee the seat (>=2300MB, same gate as the bat), restart a CPU build
#   that is already sitting there, then verify the live process really is -ngl 99.
function ArmOcrGpu([string]$Pick = 'auto') {
    # card pick (261120): auto=gpu0 | gpu0 | gpu1 | cpu(-ngl 0 zero-VRAM build, forced)
    $pk = switch ($Pick) { 'gpu1' { '1' } 'cpu' { '-1' } default { '0' } }
    $pkName = switch ($Pick) { 'cpu' { 'CPU强制版(零显存)' } 'gpu1' { 'GPU1' } default { 'GPU0' } }
    if ($Pick -eq 'cpu') {
        if ((OcrBuildMode) -eq 'cpu') { Note "   小米OCR 已在 CPU 版在岗 (零显存) -- 无需再动"; return }
        if ((OcrBuildMode) -eq 'gpu') {
            Note "   当前 GPU 版 -- 请走重起为 CPU 强制版 (中途 OCR 断约1分钟)"
            TaskStop $TASK_OCR
            KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs"
            KillService "小米OCR 18201 (GPU版)" 18201 | Out-Null
        }
        Note "--- CPU 强制点火 (YSK_GPU=-1 -> 双模式bat直落 -ngl 0 零显存分支) ---"
        $env:YSK_GPU = '-1'
        wscript //nologo $HID_VBS $OCR_BAT 2>&1 | Out-Null
        Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
        $cokO = $false
        for ($i = 0; $i -lt 24; $i++) { Start-Sleep -Seconds 5; if ((Http "GET" $OCRG_URL $null 3) -eq 200) { $cokO = $true; break } }
        if ($cokO) { Note "   18201 CPU 强制版已上岗 OK (零显存, ~1min/页)" } else { Note "   !! 2分钟未就绪 -- 查 xiaomi_ocr_cpu.log" }
        return
    }
    Note ("=================== 小米OCR 18201 载入 " + $pkName + " (GPU版 4~5s/页) ===================")
    Note "GPU 起始:"; GpuReport
    $mode = OcrBuildMode
    $g0 = GpuFreeMib ([int]$pk)
    if ($mode -eq 'gpu') {
        Note ("   18201 已在 GPU 版上岗 (GPU0 空闲 " + [math]::Round($g0/1024,1) + "GB) -- 无需再动")
        Note "=================== 已在岗, 完成 ==================="
        return
    }
    if ($g0 -lt 2300) {
        Note ("   !! " + $pkName + " 空闲 " + [math]::Round($g0/1024,1) + "GB < 上岗门槛 2300MB -- 上不了卡 (换 m>0 退出 / 选另一张卡 / CPU版)")
        Note "      先 m>0 请走 18201 现实例 / c>2 停 ComfyUI / 一级[2] 切 KVMem 单独态腾地方, 再回来按 m>9"
        Note "=================== 显存不足, 未上岗 ==================="
        return
    }
    if ($mode -eq 'cpu') {
        Note "   当前是 CPU 版 (零显存) -- 先请走再按 GPU 版重起 (中途 OCR 会断约1分钟)"
        TaskStop $TASK_OCR
        KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs"
        KillService "小米OCR 18201 (CPU版)" 18201 | Out-Null
    }
    Note ("--- 点火 18201 (静默 vbs 直起, 指定卡 " + $pkName + "; 双模式bat自查该卡空闲>=2300MB -> GPU 版) ---")
    $env:YSK_GPU = $pk
    wscript //nologo $HID_VBS $OCR_BAT 2>&1 | Out-Null
    Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
    $oready = $false
    for ($i = 0; $i -lt 24; $i++) {   # 0.8B GPU build measured ~40s
        Start-Sleep -Seconds 5
        if ((Http "GET" $OCRG_URL $null 3) -eq 200) { $oready = $true; break }
    }
    if (-not $oready) {
        Note "   !! 18201 两分钟未就绪 -- 查 E:\DSDeployMaster\ysk_autostart\xiaomi_ocr_cpu.log"
        Note "=================== 上岗失败, 回菜单可重跑 ==================="
        return
    }
    $m2 = OcrBuildMode
    if ($m2 -eq 'gpu') { Note "   18201 GPU 版已上岗 OK (4~5s/页)" } else { Note "   起来了但不是 GPU 版 -- bat 探到空隙不足自动转了 CPU 版, 属正常保护" }
    # best-effort guard re-arm: this task's ACL is locked to Administrators, so unelevated
    #   Enable fails (261120) -- then the vbs instance simply has no auto-respawn, no harm.
    # Manual-lever policy (261120 master): no guard task is armed for any manual entry. The
    #   serve bat already carries its own 30s self-heal loop, so a plain crash still recovers,
    #   while a deterministic bad-config failure is not replayed by a scheduled task forever.
    Note "   按主人积木令: 不启用计划任务守护 (serve bat 自带 30s 自愈; 开机不自启属预期)"
    Note "--- 终态 ---"; GpuReport
    Note (   "   18201 http=" + (Http "GET" $OCRG_URL $null 3) + "  18205 http=" + (Http "GET" "http://127.0.0.1:18205/v1/models" $null 3))
    Note "   视觉网关 18207 自动探到 18201, Hermes 配置无需改动"
    Note "=================== 18201 GPU 上岗完毕 ==================="
}

# [m>0] stand 18201 down and free its GPU0 seat (the other half of the master's manual lever).
#   Watchdog hosts go first so the bat does not resurrect the endpoint mid-teardown.
function StanddownOcr {
    Note "=================== 小米OCR 18201 退出 (释放显存) ==================="
    if (-not (PortPid 18201)) {
        TaskStop $TASK_OCR
        KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs|ysk_run_hidden\.vbs.*ysk_serve_ocr"
        Note "   18201 没在监听 -- 顺手清循环宿主防复活 (要上岗按 m>9)"
        return
    }
    $mode = OcrBuildMode
    Note ("   当前模式: " + $mode + " -- 停守护 + 杀宿主 + 请走实例")
    TaskStop $TASK_OCR
    KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs|ysk_run_hidden\.vbs.*ysk_serve_ocr"
    KillService ("小米OCR 18201 (" + $mode + "模式)") 18201 | Out-Null
    Start-Sleep -Seconds 3
    if (PortPid 18201) {
        Note "   仍在监听 -- 宿主没杀干净, 补一轮"
        KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs|ysk_run_hidden\.vbs.*ysk_serve_ocr"
        KillService "小米OCR 18201" 18201 | Out-Null
    }
    Note "--- 终态 ---"; GpuReport
    Note (   "   18201 http=" + [string](Http "GET" $OCRG_URL $null 3) + "  (空=已离线)")
    Note "   视觉网关 18207 自动降级: 18205 TeleOCR 在岗就用它, 两头皆无则由 VL 头兜底 (逐字精度会降)"
    Note "   要再上岗: m>9 (GPU0 空隙>=2300MB 时才会真上卡)"
    Note "=================== 18201 已退出 ==================="
}

# ---------------------------------------------------------------------------
# BUILDING BLOCKS (261120, master's policy): every small model gets a manual lever and NO
# scheduled guard. A watchdog only guarantees "alive", not "right" -- on a deterministic
# failure (bad args / bad config / no VRAM seat) it replays the same crash forever and the
# human has to kill it anyway. Ignition always goes through the hidden-vbs launcher.
# ---------------------------------------------------------------------------
# which PHYSICAL gpu a live pid actually holds (nvidia-smi compute-apps, null = no VRAM seat)
function Gpu-Of-Pid([int]$procId) {
    if (-not $procId) { return $null }
    $uuT = @{}
    foreach ($row in @(nvidia-smi --query-gpu=index,uuid --format=csv,noheader 2>$null)) {
        $p = $row -split ',\s*'
        if ($p.Count -ge 2) { $uuT[$p[1].Trim()] = 'gpu' + $p[0].Trim() }
    }
    foreach ($row in @(nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader 2>$null)) {
        $p = $row -split ',\s*'
        if ($p.Count -ge 2 -and $p[1].Trim() -eq [string]$procId -and $uuT.ContainsKey($p[0].Trim())) { return $uuT[$p[0].Trim()] }
    }
    return $null
}
function TtsHealth {
    try { return ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 "$T_URL/health").Content | ConvertFrom-Json) } catch { return $null }
}
# [m>a] mount the yosuko-tts GPU endpoint (real-time speech). Gate = the service's own
#   GPU_MIN_FREE_GIB (env YOSUKO_GPU_MIN_GIB, default 8G on GPU0). Load it while Strata is
#   still off the card: the precheck only runs at load time, a live endpoint never yields.
function ArmTtsGpu([string]$Pick = 'auto') {
    # 261120 third live-fire round: IndexTTS spreads weights over EVERY visible GPU (8G@GPU0 +
    # 1.1G@GPU1 trail proven on master's box), so picking a SPECIFIC card means ONE cold restart
    # of 9210 with CUDA_VISIBLE_DEVICES single-card view (serve bat honors env YSK_GPU). Only
    # 'auto' keeps the cheap hot /gpu/load path on the server default card. cpu = endpoint off.
    if ($Pick -eq 'cpu') {
        Note "=================== 缘狐声线 CPU 选择: GPU 端点不挂 (CPU 主路常驻, 朗读不断) ==================="
        StanddownTtsGpu
        return
    }
    $pk = switch ($Pick) { 'gpu1' { '1' } 'gpu0' { '0' } default { '' } }
    $pkName = if ($pk -eq '') { '服务默认卡(今天GPU0)' } else { 'GPU' + $pk }
    Note ("=================== 缘狐声线 上 GPU · " + $pkName + " (9210 实时朗读提速) ===================")
    $h = TtsHealth
    if (-not $h) {
        Note "   !! 9210 没在回答 -- 先起 yosuko-tts 本体 (vbs 直起 serve_yosuko.bat 或任务 ysk_yosuko_autostart), 再按本项"
        return
    }
    $seat = Gpu-Of-Pid (PortPid 9210)
    if ($h.gpu.state -eq 'ready') {
        if ($pk -eq '' -or $seat -eq ('gpu' + $pk)) {
            Note ("   GPU 端点已在岗就绪 (实坐 " + $(if ($seat) { $seat.ToUpper() } else { '?' }) + ") -- 无需再动")
            return
        }
        Note ("   端点实坐 " + $(if ($seat) { $seat.ToUpper() } else { '?' }) + " ≠ " + $pkName + " -- 走单卡视野冷重启")
    }
    if ($pk -eq '') {
        # auto: hot-load on the server default card (precheck GPU0, where that default lives)
        $gfK = [math]::Round((GpuFreeMib 0) / 1024, 1)
        Note ("   门槛: 服务默认卡需 >= " + $h.gpu.min_free_gib + "G | GPU0 当前 " + $gfK + "G | gpu.state=" + $h.gpu.state)
        if ($gfK -lt [double]$h.gpu.min_free_gib) {
            Note "   !! 服务默认卡空隙不够, 服务按策略拒载 (不动主力) -- 两条路:"
            Note "      ① 推荐时序: 装配自动清退 Strata / m>3 下场 -> 按 m>a -> 再拉 Strata (积木冷共存)"
            Note "      ② 或把 TTS 门槛调低: serve_yosuko.bat 里 set YOSUKO_GPU_MIN_GIB=3 后重启 TTS (重启会让 CPU 端点重载约2分钟)"
            Note "=================== 未上岗, 回菜单 ==================="
            return
        }
    } else {
        # specific card: gate the TARGET card, then cold restart 9210 under CVD single view
        $gfi = [math]::Round((GpuFreeMib ([int]$pk)) / 1024, 1)
        if ($gfi -lt [double]$h.gpu.min_free_gib) {
            Note ("   !! " + $pkName + " 空闲 " + $gfi + "G < 门槛 " + $h.gpu.min_free_gib + "G -- 落不了座")
            Note "      装配编排会自动清退占座的 Strata; 单按 m>a 时先 m>4 清 KVMem / 换卡再试"
            Note "=================== 未上岗, 回菜单 ==================="
            return
        }
        Note ("--- 单卡冷重启: YSK_GPU=" + $pk + " 锁 CUDA 视野, IndexTTS 全家只看见 " + $pkName + " (根治斩卡开; CPU 端点重载约2分钟, 期间朗读短暂不可用) ---")
        KillGuard "ysk_serve_yosuko\.bat|ysk_task_yosuko\.vbs|ysk_run_hidden\.vbs.*yosuko"
        TaskStop $TASK_TTS
        KillService "缘狐声线 9210" 9210 | Out-Null
        Start-Sleep -Seconds 3
        $env:YSK_GPU = $pk
        wscript //nologo $HID_VBS $TTS_BAT 2>&1 | Out-Null
        Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
        Note "   等 9210 回来 (CPU 端点冷加载实测约132秒, 最多等 6 分钟)..."
        $back = $false
        for ($i = 0; $i -lt 72; $i++) { Start-Sleep -Seconds 5; $hb = TtsHealth; if ($hb -and $hb.cpu.state -eq 'ready') { $back = $true; break } }
        if (-not $back) {
            Note "   !! 6 分钟 9210 没回 -- 查 yosuko_server.log (serve bat 30s 自愈会继续尝试, 朗读稍后可能自愈)"
            Note "=================== 冷重启未完成, 回菜单可重跑 ==================="
            return
        }
        Note ("   9210 已回 (进程只看见 " + $pkName + ") -- POST /gpu/load")
    }
    $t0 = Get-Date
    $r = Http "POST" "$T_URL/gpu/load" $null 240   # no ?device: the CVD view (or server default) already fixes the card
    $t0 = Get-Date
    $r = Http "POST" "$T_URL/gpu/load" $null 240   # no ?device: the CVD view (or server default) already fixes the card
    Note ("   /gpu/load 返回 http=" + $r)
    $gon = $false; $h2 = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Seconds 5
        $h2 = TtsHealth
        if ($h2 -and $h2.gpu.state -eq 'ready') { $gon = $true; break }
    }
    if (-not $gon) {
        $errT = if ($h2) { $h2.gpu.error } else { 'health unreachable' }
        Note ("   !! 3分钟未就绪 -- 查 E:\DSDeployMaster\ysk_autostart\yosuko_server.log (error=" + $errT + ")")
        Note "=================== 上岗失败, 回菜单可重跑 ==================="
        return
    }
    $seat2 = Gpu-Of-Pid (PortPid 9210)
    if ($pk -ne '' -and $seat2 -ne ('gpu' + $pk)) {
        Note ("⚠ 实坐较验: " + $(if ($seat2) { $seat2.ToUpper() } else { '未知' }) + " 没落在 " + $pkName + " -- 查 serve_yosuko.bat 的 YSK_GPU/CVD 段")
    } else {
        Note ("   就绪 OK, 实测等待 " + [math]::Round(((Get-Date) - $t0).TotalSeconds, 1) + "s, nvidia-smi 验证实坐 " + $(if ($seat2) { $seat2.ToUpper() } else { '待确认' }) + "; 合成自动走 GPU, 不再斩卡开")
    }
    if ($h2 -and [double]$h2.gpu.idle_unload_sec -lt 86400) {
        Note ("   提醒: 空闲 " + [int]([double]$h2.gpu.idle_unload_sec / 60) + " 分钟会自动卸回 CPU (env YOSUKO_GPU_IDLE_SECONDS) -- 要常驻改大该 env 后重启 TTS")
    }
    Note "--- 终态 ---"; GpuReport
    Note "=================== 声线 GPU 上岗完毕 ==================="
}
# [m>b] hand the voice GPU seat back (CPU endpoint stays resident, speech still works, just slow)
function StanddownTtsGpu {
    Note "=================== 缘狐声线 下 GPU (让位显存) ==================="
    $r = Http "POST" "$T_URL/gpu/unload" $null 30
    if (-not $r) { Note "   9210 没在回答 -- 跳过"; return }
    Start-Sleep -Seconds 4
    $h = TtsHealth
    if ($h) {
        Note ("   gpu.state=" + $h.gpu.state + "  cpu.state=" + $h.cpu.state + " (CPU 端点常驻, 朗读不断, 只是回到 71字/149秒 那档)")
    } else { Note "   health 读不到" }
    Note "--- 终态 ---"; GpuReport
    Note "=================== 声线 GPU 已让位 ==================="
}
# [m>c] TeleOCR 18205 onto GPU1 (fastest OCR, 3~5s/page; gate = 2048MB on GPU1, same as its bat).
#   Launched by the hidden vbs straight at serve_teleocr.bat -- no scheduled guard by policy.
function ArmTeleocrGpu([string]$Pick = 'auto') {
    $pk = switch ($Pick) { 'gpu0' { '0' } default { '1' } }
    $pkName = switch ($Pick) { 'cpu' { 'CPU版(~26min/页应急)' } 'gpu0' { 'GPU0' } default { 'GPU1' } }
    Note ("=================== TeleOCR 18205 上岗 " + $pkName + " ===================")
    if ($Pick -eq 'cpu') {
        if (PortPid 18205) { Note "   18205 已在监听 -- 复用当前实例"; return }
        StartOcrCpu   # the proven TeleCPU bat (--cpu flag, zero VRAM)
        return
    }
    if (PortPid 18205) {
        Note "   18205 已在监听 -- 复用当前实例, 无需再动"
        return
    }
    $g1 = GpuFreeMib ([int]$pk)
    if ($g1 -lt 2048) {
        Note ("   !! " + $pkName + " 空闲 " + [math]::Round($g1 / 1024, 1) + "GB < 门槛 2048MB -- 上不了卡 (Strata 满座期属正常)")
        Note "      要 OCR 就用 m>9 (小米 GPU/CPU 双模式) 或 m>6 (TeleCPU 应急, 慢)"
        Note "=================== 显存不足, 未上岗 ==================="
        return
    }
    Note ("--- 点火 (静默 vbs 直起 serve_teleocr.bat, 指定卡 " + $pkName + "; 不启用计划任务守护) ---")
    $env:YSK_GPU = $pk
    wscript //nologo $HID_VBS $TL_BAT 2>&1 | Out-Null
    Remove-Item Env:YSK_GPU -ErrorAction SilentlyContinue
    $tready = $false
    for ($i = 0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 5
        if ((Http "GET" "http://127.0.0.1:18205/v1/models" $null 3) -eq 200) { $tready = $true; break }
    }
    if (-not $tready) { Note "   !! 2分钟未就绪 -- 查 E:\DSDeployMaster\ysk_autostart\teleocr_server.log"; return }
    Note "   TeleOCR 18205 已就绪 OK (GPU1); 18207 网关会自动优先用它"
    Note "--- 终态 ---"; GpuReport
    Note "=================== TeleOCR 上岗完毕 ==================="
}
# [m>d] take TeleOCR 18205 off (watchdog hosts first so its 30s self-heal cannot resurrect it)
function StanddownTeleocr {
    Note "=================== TeleOCR 18205 收回 (释放 GPU1) ==================="
    if (-not (PortPid 18205)) {
        TaskStop $TASK_TL
        KillGuard "ysk_serve_teleocr|ysk_task_teleocr|ysk_run_hidden\.vbs.*teleocr"
        Note "   18205 没在监听 -- 顺手清循环宿主防复活 (它会等座自己拉 serve)"
        return
    }
    KillGuard "ysk_serve_teleocr|ysk_task_teleocr|ysk_run_hidden\.vbs.*teleocr"
    KillService "TeleOCR 18205" 18205 | Out-Null
    Start-Sleep -Seconds 3
    if (PortPid 18205) {
        Note "   仍在监听 -- 补一轮宿主清理"
        KillGuard "ysk_serve_teleocr|ysk_task_teleocr|ysk_run_hidden\.vbs.*teleocr"
        KillService "TeleOCR 18205" 18205 | Out-Null
    }
    Note "--- 终态 ---"; GpuReport
    Note "   OCR 自动回到 18201 小米(或 18207 退化到 VL 头), router 自行择优无需改配置"
    Note "=================== TeleOCR 已收回 ==================="
}

# ---------------------------------------------------------------------------
# [b] ASSEMBLY DESK (261120 master's build-blocks design; the GUI first tab "开工装配"
#   is just a paint of this data -- -BlocksState is the single source of truth, so a
#   block added to $BLOCKS shows up in the window without touching the C# side).
#   Two boxes per block: main = resident (on card whenever the seat fits), guard = its
#   scheduled task armed. Semantics (master 261120): unchecked = leave completely;
#   checked = mount BEFORE Strata, because every gate below is evaluated at load time
#   only while Strata's card split is elastic and yields afterwards. ComfyUI checked ==
#   "no Strata this round" (it wants whole GPU0, genuinely exclusive). The TTS main box
#   covers its GPU endpoint only: the CPU voice core always stays resident (killing
#   9210 would silence the chat, and unchecking only hands the ~2G GPU seat back).
#   Guard-task writes are folded into ONE elevated pass at the very end (UAC pops at
#   most once; the helper exits by itself) -- plain and elevated powershell never mix,
#   so a plain window can never strand an elevated-owned task.
#   Display order = assembly priority (most-likely-used first, master 261120).
# ---------------------------------------------------------------------------
$BLOCKS = [ordered]@{
    # cards = GUI dropdown options (auto = that block's built-in default card, see dflt);
    # the pick rides to the bats as env YSK_GPU / to TTS as /gpu/load?device=N (261120).
    'tts'      = @{ n = '缘狐声线 9210'; full = 'IndexTTS-2.5 语音端点 (GPU加速提速朗读, CPU主路常驻不断声)'; port = 9210; g = 'ysk_yosuko_autostart'; gate = '任意卡空闲≥8G'; zero = $false; dflt = 'GPU0'; cards = @('auto','gpu0','gpu1','cpu') }
    'ocr'      = @{ n = '小米OCR 18201'; full = 'Xiaomi-OCR-0 双模式 (上卡4~5s/页, CPU版~1min/页零显存)';    port = 18201; g = 'ysk_ocr_autostart';   gate = '任意卡空闲≥2300MB'; zero = $false; dflt = 'GPU0'; cards = @('auto','gpu0','gpu1','cpu') }
    'kvm'      = @{ n = 'KVMem 18200';   full = 'KVMem-27B 副引擎 (大件14.5G, 常驻备胎/分身; ninfer不支持CPU)'; port = 18200; g = 'ysk_kvmem_autostart'; gate = '任意卡空闲≥14800MB'; zero = $false; dflt = 'GPU1'; cards = @('auto','gpu0','gpu1') }
    'tele'     = @{ n = 'TeleOCR 18205'; full = 'TeleOCR (最快OCR 3~5s/页; CPU版~26min/页应急)';           port = 18205; g = '\ysk\ysk_teleocr_guard'; gate = '任意卡空闲≥2048MB'; zero = $false; dflt = 'GPU1'; cards = @('auto','gpu0','gpu1','cpu') }
    'comfy'    = @{ n = 'ComfyUI 8188';  full = '出图套件 (独吞一张卡, 勾选则本轮不拉Strata; CPU极慢)';      port = 8188;  g = '';                   gate = '单卡空闲≥8G'; zero = $false; dflt = 'GPU0'; cards = @('auto','gpu0','gpu1','cpu') }
    'whisper'  = @{ n = 'whisper 9003';  full = 'whisper large-v3 ASR (长录音转写; CPU int8零显存慢)';       port = 9003; g = 'ysk_whisper_autostart'; gate = '任意卡空闲≥6G'; zero = $false; dflt = 'GPU1'; cards = @('auto','gpu0','gpu1','cpu') }
    'brain'    = @{ n = '调度官 18202';  full = 'Qwen3-0.6B 命令审批调度 (纯CPU零显存)';                 port = 18202; g = 'ysk_brain_autostart';   gate = '零显存·无卡可选'; zero = $true; dflt = 'CPU'; cards = @('cpu') }
    'vlembed'  = @{ n = '嵌入 18303';    full = 'qwen3-vl-embedding-2b (纯CPU零显存, 记忆检索用)';       port = 18303; g = 'ysk_vlembedding_autostart'; gate = '零显存·无卡可选'; zero = $true; dflt = 'CPU'; cards = @('cpu') }
    'vlrerank' = @{ n = '重排 18304';    full = 'vlreranker (纯CPU零显存, 平时按需点火)';                port = 18304; g = 'ysk_vlreranker_autostart'; gate = '零显存·无卡可选'; zero = $true; dflt = 'CPU'; cards = @('cpu') }
}
# mount order = the least elastic gate first (GPU1 big fixed seats -> GPU0 seats -> CPU trio -> suite)
$BLOCK_ORDER_UP   = @('kvm', 'whisper', 'tele', 'tts', 'ocr', 'brain', 'vlembed', 'vlrerank', 'comfy')
# unmount order = mirror (small first, the two engine-sized ones last)
$BLOCK_ORDER_DOWN = @('tts', 'vlrerank', 'vlembed', 'brain', 'ocr', 'tele', 'whisper', 'comfy', 'kvm')
$TRIO_BAT = @{
    'brain'    = 'E:\DSDeployMaster\ysk_autostart\ysk_serve_brain.bat'
    'vlembed'  = 'E:\DSDeployMaster\ysk_autostart\ysk_serve_vlembedding.bat'
    'vlrerank' = 'E:\DSDeployMaster\ysk_autostart\ysk_serve_vlreranker.bat'
}
$TRIO_GUARD_RX = @{
    'brain'    = 'ysk_serve_brain\.bat|ysk_task_brain\.vbs'
    'vlembed'  = 'ysk_serve_vlembedding\.bat|ysk_task_vlembedding\.vbs'
    'vlrerank' = 'ysk_serve_vlreranker\.bat|ysk_task_vlreranker\.vbs'
}

function Block-Status([string]$id) {
    switch ($id) {
        'tts' {
            $h = TtsHealth
            if (-not $h) { return 'off' }
            if ($h.gpu.state -eq 'ready') { return 'gpu' }
            return 'cpu'
        }
        'ocr'     { $m = OcrBuildMode; if ($m) { return $m }; return 'off' }
        'tele'    { if (PortPid 18205)  { return 'gpu' } else { return 'off' } }
        'whisper' { if (PortPid 9003)   { return 'gpu' } else { return 'off' } }
        'kvm'     { if (PortPid 18200)  { return 'up' }  else { return 'off' } }
        'comfy'   { if (PortPid 8188)   { return 'up' }  else { return 'off' } }
        default   { if (PortPid $BLOCKS[$id].port) { return 'up' } else { return 'off' } }
    }
}
function Guard-Status([string]$task) {
    if (-not $task) { return 'none' }
    # authoritative source = schtasks itself, anchored on the 计划任务状态 line. Two traps
    # proven 261120: ① Get-ScheduledTask .State comes from CIM and LAGS writes by seconds
    # (the false 'armed' master saw right after real disables); ② plain /Query LIST shows no
    # enable/disable state at all, and /V has four OTHER '已禁用' setting lines -- so match
    # ONLY '计划任务状态:/Scheduled Task State:' plus the value on that same line.
    $o = (& schtasks /Query /TN $task /V /FO LIST 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { return 'missing' }
    if ($o -match '(计划任务状态|Scheduled Task State):\s*(已禁用|Disabled)') { return 'off' }
    if ($o -match '(计划任务状态|Scheduled Task State):\s*(已启用|Enabled)')  { return 'armed' }
    return 'missing'
}
function Block-Alive([string]$id) { return (Block-Status $id) -ne 'off' }
function Mount-Block([string]$id, [string]$Pick = 'auto') {
    Note ("· 载入 " + $BLOCKS[$id].n + " (" + $BLOCKS[$id].full + ")" + $(if ($Pick -and $Pick -ne 'auto') { ' [指定 ' + $Pick + ']' } else { '' }))
    switch ($id) {
        'tts' {
            if (-not (PortPid 9210)) {
                Note "   9210 本体不在 -- 先 vbs 直起 ysk_serve_yosuko.bat 再挂 GPU 端点"
                wscript //nologo $HID_VBS "E:\DSDeployMaster\ysk_autostart\ysk_serve_yosuko.bat" 2>&1 | Out-Null
                for ($i = 0; $i -lt 60; $i++) { Start-Sleep -Seconds 5; if (TtsHealth) { break } }
                if (-not (TtsHealth)) { Note "   !! 9210 5分钟没起 (CPU模型加载慢/查 yosuko_server.log), 本件跳过"; return }
            }
            ArmTtsGpu $Pick
        }
        'ocr'     { ArmOcrGpu $Pick }
        'tele'    { ArmTeleocrGpu $Pick }
        'whisper' { StartWhisper $Pick }
        'kvm'     { ArmKvmemResident $Pick }
        'comfy'   { StartComfyUI $Pick }
        default {
            $bat = $TRIO_BAT[$id]; $p = $BLOCKS[$id].port
            if (-not (Test-Path $bat)) { Note ("   !! 缺启动脚本: " + $bat); return }
            wscript //nologo $HID_VBS $bat 2>&1 | Out-Null
            $ok = $false
            for ($i = 0; $i -lt 48; $i++) { Start-Sleep -Seconds 5; if (PortPid $p) { $ok = $true; break } }
            if ($ok) { Note ("   " + $BLOCKS[$id].n + " 已在岗 OK (零显存)") } else { Note ("   !! " + $BLOCKS[$id].n + " 4分钟未监听 -- 查对应 *_server.log") }
        }
    }
}
function Unhook-Block([string]$id) {
    Note ("· 退出 " + $BLOCKS[$id].n)
    switch ($id) {
        'tts'     { StanddownTtsGpu }
        'ocr'     { StanddownOcr }
        'tele'    { StanddownTeleocr }
        'whisper' { StopWhisper }
        'kvm'     { CleanupKvmem }
        'comfy'   { StopComfyUI }
        default {
            KillGuard $TRIO_GUARD_RX[$id]
            KillService ($BLOCKS[$id].n) $BLOCKS[$id].port | Out-Null
        }
    }
}
function AssembleBlocks {
    # spec comes from the -Arg queue (GUI single-shot: "tts=1,g.tts=0,...") or one Ask()
    # line on the CLI; tokens absent from the spec keep the CURRENT live state, so an
    # empty spec == "re-seat what is running now, change nothing".
    $spec = ''
    if ($global:RUN_ARGQ.Count -gt 0) { $spec = ($global:RUN_ARGQ -join ','); $global:RUN_ARGQ = @() }
    if (-not $spec) { $spec = Ask "  积木清单 (留空=按当前状态; 例 tts=1,g.tts=1,comfy=0)" }
    $want = @{}; $gwant = @{}; $picks = @{}
    foreach ($tok in ("$spec" -split ',')) {
        $tok = $tok.Trim(); if (-not $tok) { continue }
        $kv = $tok -split '=', 2
        if ($kv.Count -ne 2) { continue }
        $k = $kv[0].Trim().ToLower(); $raw = $kv[1].Trim().ToLower()
        if ($k.StartsWith('pick.')) { $picks[$k.Substring(5)] = $raw; continue }
        $v = ($raw -in @('1','true','on'))
        if ($k.StartsWith('g.')) { $gwant[$k.Substring(2)] = $v } else { $want[$k] = $v }
    }
    foreach ($id in $BLOCKS.Keys) {
        if (-not $want.Contains($id)) { $want[$id] = [bool](Block-Alive $id) }
        if (-not $gwant.Contains($id)) { $gwant[$id] = $null }
    }
    Note "=================== 开工装配 · 一键装配 ==================="
    Note "GPU 起始:"; GpuReport
    # live physical seats (one nvidia-smi pair) so a changed card pick can be detected and
    # relocated: 261120 master's rule = '选卡不同了就退出重拉起', no silent reuse.
    $uu0 = @{}
    foreach ($row in @(nvidia-smi --query-gpu=index,uuid --format=csv,noheader 2>$null)) {
        $p = $row -split ',\s*'
        if ($p.Count -ge 2) { $uu0[$p[1].Trim()] = 'gpu' + $p[0].Trim() }
    }
    $pc0 = @{}
    foreach ($row in @(nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader 2>$null)) {
        $p = $row -split ',\s*'
        if ($p.Count -ge 2 -and $uu0.ContainsKey($p[0].Trim())) { $pc0[$p[1].Trim()] = $uu0[$p[0].Trim()] }
    }
    $moves = @()
    foreach ($id in $BLOCK_ORDER_UP) {
        if (-not $want[$id]) { continue }
        if (-not (Block-Alive $id)) { continue }
        $p2 = if ($picks.ContainsKey($id)) { $picks[$id] } else { 'auto' }
        if ($p2 -notin @('gpu0','gpu1','cpu')) { continue }
        if ($BLOCKS[$id].zero) { continue }
        # tts with GPU endpoint unmounted (cpu mode) + a gpu pick = normal arming, not a move
        if ($id -eq 'tts' -and (Block-Status 'tts') -eq 'cpu') { continue }
        $cur = $null
        $plm = PortPid $BLOCKS[$id].port
        if ($plm) { $cur = $pc0[[string]$plm] }
        if (-not $cur) { $cur = 'cpu' }
        if ($cur -ne $p2) { $moves += ,@($id, $cur, $p2) }
    }
    foreach ($id in $BLOCK_ORDER_DOWN) { if (-not $want[$id]) { Note ("   退出 " + $BLOCKS[$id].n) } }
    foreach ($id in $BLOCK_ORDER_UP)   { if ($want[$id])    { Note ("   载入 " + $BLOCKS[$id].n + "  [" + $(if ($picks.ContainsKey($id) -and $picks[$id] -ne 'auto') { '指定卡:' + $picks[$id] } else { '默认卡' }) + " · " + $BLOCKS[$id].gate + "]") } }
    foreach ($m in $moves) { Note ("   换卡: " + $BLOCKS[$m[0]].n + "  " + $m[1] + " -> " + $m[2] + " (退出重拉起)") }
    if ($want['comfy']) { Note "   ComfyUI 已勾选 -> 独吞 GPU0, 本轮跳过 Strata (真互斥, 不硬塞)" } else { Note "   最后拉起 Strata 8080 (已在岗则复用不重载)" }
    foreach ($id in $BLOCKS.Keys) {
        if ($null -ne $gwant[$id] -and $BLOCKS[$id].g) {
            Note ("   守护 " + $BLOCKS[$id].g + " -> " + $(if ($gwant[$id]) { '启用' } else { '停用' }))
        }
    }
    # 0.4) cross-card moves need the target seat at load time: a LIVE Strata never yields a
    #   card (its elastic split only re-solves on cold load), so step it out of the way first
    #   when any move wants a GPU seat and that seat currently looks tight.
    $GATE_MIB = @{ tts = 8192; ocr = 2300; tele = 2048; whisper = 6144; kvm = 14800; comfy = 8000 }
    foreach ($m in $moves) {
        if ($m[2] -notin @('gpu0','gpu1')) { continue }
        $gi = [int]$m[2].Substring(3)
        if ((GpuFreeMib $gi) -lt $GATE_MIB[$m[0]] -and (PortPid 8080)) {
            Note "--- 换卡落座需要空隙, 目标卡被在岗 Strata 占着 -- 先清退 Strata (m>3 语义), 落完小件最后再冷加载回来 ==="
            CleanupStrata
            break
        }
    }
    # 0) comfy vs strata are exclusive: evict Strata first (task stopped too, no respawn race)
    if ($want['comfy'] -and (PortPid 8080)) {
        Note "--- ComfyUI 勾选 -> 先请走 Strata (m>3 语义: 停 8080 进程树+守护) ---"
        CleanupStrata
    }
    # 1) tear down the unchecked ones (small first, engine-sized last)
    # sweep unchecked blocks EVEN when their port is dark: the serve bats are watchdog LOOP
    # HOSTS that happily wait out a full card and resurrect at the first free seat (261120
    # 22:33 live fire: teleocr guard loop, task already disabled, woke 18205 mid-assembly).
    foreach ($id in $BLOCK_ORDER_DOWN) {
        if ($want[$id]) { continue }
        Unhook-Block $id
    }
    # 2) mount the checked ones in gate order; a live 9210 without its GPU endpoint gets the seat back
    foreach ($id in $BLOCK_ORDER_UP) {
        if (-not $want[$id]) { continue }
        if ($moves | Where-Object { $_[0] -eq $id }) {
            Note ("   " + $BLOCKS[$id].n + " 换卡重落 (先请走现实例)")
            Unhook-Block $id
            $pkk2 = if ($picks.ContainsKey($id)) { $picks[$id] } else { 'auto' }
            Mount-Block $id $pkk2
            continue
        }
        if (Block-Alive $id) {
            if ($id -eq 'tts') {
                $h = TtsHealth
                if ($h -and $h.gpu.state -eq 'ready') { Note "   缘狐声线 GPU 端点已在岗 -- 复用"; continue }
                $pkT = if ($picks.ContainsKey($id)) { $picks[$id] } else { 'auto' }
                Note ("   9210 已在岗但 GPU 端点未挂 -- 尝试上卡 (pick=" + $pkT + ")"); ArmTtsGpu $pkT; continue
            }
            Note ("   " + $BLOCKS[$id].n + " 已在岗 -- 复用 (不重复点火)")
            continue
        }
        $pkk = if ($picks.ContainsKey($id)) { $picks[$id] } else { 'auto' }
        Mount-Block $id $pkk
    }
    # 3) Strata last -- its elastic split absorbs whatever seats the blocks kept
    if ($want['comfy']) {
        Note "   (ComfyUI 本轮当家, Strata 未启动; 要回主力按一级[1]或再装配一次)"
    } elseif (PortPid 8080) {
        Note "   Strata 已在岗 8080 -- 复用不重载 (装配只补小件, 不动主力)"
    } else {
        SwitchToStrata -ReArmOcr:([bool]$want['ocr']) -ReArmTele:([bool]$want['tele'])
    }
    # 4) guard tasks: plain-privilege writes first, everything ACL-refused goes to ONE
    #    elevated helper at the very end (UAC at most once; it exits on its own)
    $elev = @()
    foreach ($id in $BLOCKS.Keys) {
        if ($null -eq $gwant[$id]) { continue }
        $task = $BLOCKS[$id].g; if (-not $task) { continue }
        $armed = (Guard-Status $task) -eq 'armed'
        if ($armed -eq $gwant[$id]) { Note ("   守护无需改动: " + $task); continue }
        $flag = if ($gwant[$id]) { '/ENABLE' } else { '/DISABLE' }
        & schtasks /Change /TN $task $flag 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Note ("   守护已" + $(if ($gwant[$id]) { '启用' } else { '停用' }) + ": " + $task)
        } else {
            Note ("   普通权限改不动 (任务ACL锁管理员), 归入集中提权: " + $task)
            $elev += ('schtasks /Change /TN "' + $task + '" ' + $flag)
        }
    }
    if ($elev.Count -gt 0) {
        $tmp = Join-Path $env:TEMP ("ysk_guard_elev_" + (Get-Date -Format 'yymmdd_HHmmss') + ".ps1")
        Set-Content -Path $tmp -Value ($elev -join "`r`n") -Encoding UTF8
        Note ("--- 守护变更 " + $elev.Count + " 项: 现在弹一次 UAC, 提权助手跑完自行退出 ---")
        try {
            Start-Process pwsh -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$tmp)
            Note "   提权执行完毕 (管理员进程已退出), 复查:"
        } catch {
            Note ("   !! UAC 被取消或提权失败, 守护改动未生效: " + $_.Exception.Message)
        }
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
    foreach ($id in $BLOCKS.Keys) {
        if ($null -eq $gwant[$id] -or -not $BLOCKS[$id].g) { continue }
        Note ("   守护 " + $BLOCKS[$id].g + " 现状: " + (Guard-Status $BLOCKS[$id].g))
    }
    # 5) final state
    Note "--- 终态 ---"
    GpuReport
    foreach ($id in $BLOCKS.Keys) {
        $s = Block-Status $id
        $tag = switch ($s) { 'gpu' { 'GPU在岗' } 'cpu' { 'CPU在岗' } 'up' { '在岗' } default { '离线' } }
        Note ("   " + (Block-Line2 $id $tag))
    }
    Note ("   8080 http=" + (Http "GET" $S_URL $null 3) + "  18200 http=" + (Http "GET" $K_URL $null 3))
    # 5) late sweep: any legacy/auto path that re-fired a disabled guard's LOOP HOST during
    #    this run (teleocr/whisper/ocr bats self-heal and happily take a free seat) gets put
    #    back in the box -- unchecked means unchecked, no resurrection after the fact.
    foreach ($id in $BLOCK_ORDER_DOWN) {
        if ($want[$id]) { continue }
        if (Block-Alive $id) {
            Note ("   迟到复活清退: " + $BLOCKS[$id].n)
            Unhook-Block $id
        }
    }
    if (-not $want['tele']) { KillGuard "ysk_serve_teleocr|ysk_task_teleocr|ysk_run_hidden\.vbs.*teleocr" }
    if (-not $want['whisper']) { KillGuard "task_whisper\.vbs|whisper-asr.*start\.bat|ysk_serve_whisper" }
    if (-not $want['ocr']) { KillGuard "ysk_serve_ocr\.bat|ysk_task_ocr\.vbs|ysk_run_hidden\.vbs.*ysk_serve_ocr" }
    Note "=================== 装配完成 ==================="
}
# fast batched snapshot for the GUI probe (plain per-block polling cost ~14s, 261120):
# ONE listen table + ONE scheduled-task enumeration + ONE tts health HTTP + at most ONE CIM
# query (the OCR cmdline). Returns hashtable: id -> @{ st; gcur }, plus _gpu/_strata/_router.
function Get-BlockSnapshot {
    $ports = @{}
    try { Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $ports["$($_.LocalPort)"] = $_.OwningProcess } } catch { }
    $tasks = @{}
    try {
        foreach ($t in (Get-ScheduledTask -TaskName "ysk_*" -ErrorAction SilentlyContinue)) {
            $tasks[$t.TaskName.ToLower()] = $(if ($t.State -eq 'Disabled') { 'off' } else { 'armed' })
        }
    } catch { }
    $h = $null
    if ($ports.ContainsKey("9210")) { $h = TtsHealth }
    $ocrMode = $null
    if ($ports.ContainsKey("18201")) {
        $opid = $ports["18201"]
        $c = (Get-CimInstance Win32_Process -Filter "ProcessId=$opid" -ErrorAction SilentlyContinue).CommandLine
        if ($c -and $c -match '-ngl\s+0(\s|$)') { $ocrMode = 'cpu' } else { $ocrMode = 'gpu' }
    }
    # physical card map: nvidia-smi says which GPU each compute pid holds (one shot)
    $uu = @{}
    foreach ($row in @(nvidia-smi --query-gpu=index,uuid --format=csv,noheader 2>$null)) {
        $p = $row -split ',\s*'
        if ($p.Count -ge 2) { $uu[$p[1].Trim()] = 'gpu' + $p[0].Trim() }
    }
    $pcard = @{}
    foreach ($row in @(nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader 2>$null)) {
        $p = $row -split ',\s*'
        if ($p.Count -ge 2 -and $uu.ContainsKey($p[0].Trim())) { $pcard[$p[1].Trim()] = $uu[$p[0].Trim()] }
    }
    $r = @{}
    foreach ($id in $BLOCKS.Keys) {
        $b = $BLOCKS[$id]; $live = $ports.ContainsKey("$($b.port)")
        $st = switch ($id) {
            'tts'     { if (-not $live) { 'off' } elseif ($h -and $h.gpu.state -eq 'ready') { 'gpu' } else { 'cpu' } }
            'ocr'     { if (-not $live) { 'off' } elseif ($ocrMode) { $ocrMode } else { 'off' } }
            'tele'    { if ($live) { 'gpu' } else { 'off' } }
            'whisper' { if ($live) { 'gpu' } else { 'off' } }
            default   { if ($live) { 'up' }  else { 'off' } }
        }
        $gcur = 'none'
        if ($b.g) {
            $tn = $b.g.Split('\')[-1].ToLower()
            $gcur = if ($tasks.ContainsKey($tn)) { $tasks[$tn] } else { 'missing' }
        }
        $card = $null
        if ($live) {
            # mode beats context-trails: a 'cpu'-mode host may still hold a tiny leftover CUDA
            # context from a failed /gpu/load attempt (9210 gpu1 trail, 261120) -- trust mode.
            if ($st -eq 'cpu' -or $b.zero) { $card = 'cpu' } else {
                $apid = [string]$ports["$($b.port)"]
                if ($pcard.ContainsKey($apid)) { $card = $pcard[$apid] }
            }
        }
        $r[$id] = @{ st = $st; gcur = $gcur; card = $card }
    }
    $r['_gpu'] = @(nvidia-smi --query-gpu=index,memory.free,memory.total --format=csv,noheader,nounits 2>$null)
    $r['_strata'] = $ports.ContainsKey('8080')
    $r['_router'] = $ports.ContainsKey('18207')
    return $r
}
function Block-Line2([string]$id, [string]$tag) {
    $b = $BLOCKS[$id]
    $gs = if ($b.g) { '  守护:' + (Guard-Status $b.g) } else { '  守护:无' }
    return ("{0,-15} {1}{2}" -f $b.n, $tag, $gs)
}
function Show-BlocksState {
    Note "=================== 积木现状快照 ==================="
    Note "GPU:"; GpuReport
    $snap = Get-BlockSnapshot
    foreach ($id in $BLOCKS.Keys) {
        $s = $snap[$id].st
        $tag = switch ($s) { 'gpu' { 'GPU在岗' } 'cpu' { 'CPU在岗' } 'up' { '在岗' } default { '离线' } }
        $b = $BLOCKS[$id]
        $gs = if ($b.g) { '  守护:' + $snap[$id].gcur } else { '  守护:无' }
        $cd = if ($snap[$id].card) { '  实坐:' + $snap[$id].card.ToUpper() } else { '' }
        Note ("   " + ("{0,-15} {1}{2}{3}" -f $b.n, $tag, $gs, $cd))
    }
    $st = if (PortPid 8080) { 'Strata 在岗' } else { 'Strata 离线' }
    Note ("   " + $st + "   18207网关: " + $(if (PortPid 18207) { '在岗' } else { '离线' }))
    Note "=================================================="
}
function BlocksStatusLine {
    $on = @($BLOCKS.Keys | Where-Object { Block-Alive $_ }).Count
    $ar = @($BLOCKS.Keys | Where-Object { $BLOCKS[$_].g -and (Guard-Status $BLOCKS[$_].g) -eq 'armed' }).Count
    $main = if (PortPid 8080) { 'Strata' } elseif (PortPid 18200) { 'KVMem' } else { '离线' }
    Write-Host ("    积木在岗 " + $on + "/" + $BLOCKS.Count + "  ·  守护启用 " + $ar + "  ·  主力: " + $main)
}

# [h>8] scheduled task overview
function TaskOverview {
    Note "=================== ysk_* 计划任务总览 ==================="
    Get-ScheduledTask -TaskName "ysk_*" -ErrorAction SilentlyContinue | ForEach-Object {
        $info = $_ | Get-ScheduledTaskInfo
        $lr = try { $info.LastRunTime.ToString("MM-dd HH:mm") } catch { "n/a" }
        Note ("   {0}  State={1}  LastRun={2}  Result={3}" -f $_.TaskName, $_.State, $lr, $info.LastTaskResult)
    }
    Note "   (Result: 267009=守护运行中正常 · 0=已退出 · 1=失败会被重拉)"
    Note "=================================================="
}

# [4] GPU process details
function GpuProcs {
    Note "=================== GPU 进程明细 ==================="
    nvidia-smi --query-compute-apps=pid,used_memory,process_name --format=csv,noheader 2>&1 | ForEach-Object { Note ("   " + $_) }
    Note "======================================"
}

# [h>9] open common panels
function OpenPanels {
    Note "--- 浏览器直达常用面板 ---"
    foreach ($u in @("http://127.0.0.1:8188", "http://127.0.0.1:3303", "http://127.0.0.1:52180", "http://127.0.0.1:8208")) {
        Start-Process $u
        Note ("   已打开 " + $u)
    }
    Note "   (ComfyUI / OpenWebUI / Dify / Jupyter)"
}

# [u>6] Hermes backup
function HermesBackup {
    Note "--- hermes backup (Hermes home -> zip) ---"
    & $HERMEXE backup 2>&1 | ForEach-Object { Note ("   " + $_) }
    Note "   备份完成 (路径见上方输出)"
}

# [h>0] tail of the switch log
function TailLog {
    Note "--- main_switch.log 尾部 30 行 ---"
    # must use Write-Host here, not Note: Note appends every read line back into the SAME log
    # file, so each [h>0] run doubled the log (it ballooned past 600KB on 2026-10-18)
    if (Test-Path $LOG) {
        Get-Content $LOG -Tail 30 -Encoding UTF8 | ForEach-Object { Write-Host ("   " + $_) }
    } else { Note "   还没有日志" }
}

# [u>5] Hermes upgrade (2026-10-20 single gh-proxy version; rewritten 2026-11-03: git+PyPI dual-channel
#   mirror auto-ranking. Why (measured 11-03): gh-proxy 4.5s vs 17s direct; Huawei PyPI 285KB/s vs pypi.org 6KB/s;
#   mirror availability shifts within minutes, hardcoding any one is doomed -- always re-rank before each update
#   - git pool = direct + 8 mirrors probed in parallel, origin temporarily points to the winner, try/finally restores
#   - PyPI injected via UV_DEFAULT_INDEX/UV_INDEX_URL/PIP_INDEX_URL env; uv/pip children spawned by
#     'hermes update' inherit them, global pip config stays clean
#   - slow-guard: git http.lowSpeedTime=8 / curl --max-time 15; all-dead git pool retries once
#   - rankings go to their own file ysk_upgrade_mirror.log (main_switch.log once bloated to 3.29GB -- do not feed it)
$UPGIT = @(
    @("direct-github",  "https://github.com/NousResearch/hermes-agent.git"),
    @("gh-proxy.com",   "https://gh-proxy.com/https://github.com/NousResearch/hermes-agent.git"),
    @("ghfast.top",     "https://ghfast.top/https://github.com/NousResearch/hermes-agent.git"),
    @("ghproxy.net",    "https://ghproxy.net/https://github.com/NousResearch/hermes-agent.git"),
    @("mirror.ghproxy", "https://mirror.ghproxy.com/https://github.com/NousResearch/hermes-agent.git"),
    @("gh.llkk.cc",     "https://gh.llkk.cc/https://github.com/NousResearch/hermes-agent.git"),
    @("moeyy.xyz",      "https://github.moeyy.xyz/https://github.com/NousResearch/hermes-agent.git"),
    @("bgithub.xyz",    "https://bgithub.xyz/NousResearch/hermes-agent.git"),
    @("gitclone.com",   "https://gitclone.com/github.com/NousResearch/hermes-agent.git")
)
$UPPYI = @(
    @("tuna",     "https://pypi.tuna.tsinghua.edu.cn/simple"),
    @("aliyun",   "https://mirrors.aliyun.com/pypi/simple"),
    @("tencent",  "https://mirrors.cloud.tencent.com/pypi/simple"),
    @("ustc",     "https://mirrors.ustc.edu.cn/pypi/simple"),
    @("huawei",   "https://repo.huaweicloud.com/repository/pypi/simple"),
    @("pypi.org", "https://pypi.org/simple")
)
$UPLOGF = "E:\DSDeployMaster\ysk_autostart\ysk_upgrade_mirror.log"

function Show-MirrorRanking {
    # git+PyPI ranked in parallel; returns @{git=best git url; pypi=best pypi url} (either may be $null)
    # SHA baseline via api.github.com (measured 11-03: git direct blocked but api still alive); falls back to pure speed ranking
    $sha = $null
    try {
        $j = & curl.exe -s --noproxy '*' --max-time 8 "https://api.github.com/repos/NousResearch/hermes-agent/commits/main" | ConvertFrom-Json
        if ($j.sha) { $sha = $j.sha }
    } catch { }
    $probe = {
        param($kind, $name, $url)
        $t0 = Get-Date
        if ($kind -eq 'git') {
            $env:GIT_TERMINAL_PROMPT = '0'
            git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=8 ls-remote --exit-code $url HEAD 2>&1 | Out-Null
            $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
            if ($LASTEXITCODE -eq 0) { return "git|$name|$sec|OK" }
            return "git|$name|$sec|FAIL rc=$LASTEXITCODE"
        }
        $spd = & curl.exe -s --noproxy '*' --max-time 15 -o NUL -w "%{speed_download}" ($url.TrimEnd('/') + '/requests/') 2>$null
        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $v = 0.0; [void][double]::TryParse("$spd", [ref]$v)
        if ($v -gt 0) { return "pypi|$name|$sec|{0}KB/s" -f [math]::Round($v/1KB, 1) }
        return "pypi|$name|$sec|FAIL"
    }
    $jobs = @()
    foreach ($m in $UPGIT) { $jobs += Start-Job -Name ("git:" + $m[0]) -ScriptBlock $probe -ArgumentList 'git', $m[0], $m[1] }
    foreach ($m in $UPPYI) { $jobs += Start-Job -Name ("pypi:" + $m[0]) -ScriptBlock $probe -ArgumentList 'pypi', $m[0], $m[1] }
    $rows = @(Wait-Job -Job $jobs -Timeout 45 | Receive-Job | Where-Object { $_ })
    if (@($rows | Where-Object { $_ -like 'git|*|OK' }).Count -eq 0) {
        Write-Host "   git 镜像全灭 -- 自动重试一轮 (镜像抖动一两分钟即恢复是实测常态)"
        $rows = @($rows | Where-Object { $_ -notlike 'git|*' })
        $rj = @()
        foreach ($m in $UPGIT) { $rj += Start-Job -Name ("gitR2:" + $m[0]) -ScriptBlock $probe -ArgumentList 'git', $m[0], $m[1] }
        $rows += @(Wait-Job -Job $rj -Timeout 45 | Receive-Job | Where-Object { $_ })
        $jobs = $jobs + $rj
    }
    # stalled/crashed jobs get placeholder rows so the ranking table never has holes when debugging
    $got = @($rows | ForEach-Object { ($_ -split '\|')[1] })
    foreach ($jb in $jobs) {
        $short = $jb.Name -replace '^(gitR2|git|pypi):', ''
        $kind  = if ($jb.Name -like 'git*') { 'git' } else { 'pypi' }
        if ($jb.State -in 'Running','Suspending','Failed' -and ($short -notin $got)) {
            $rows += ("{0}|{1}|999|TIMEOUT/崩 (45s无应答)" -f $kind, $short)
            $got += $short
        }
    }
    Remove-Job * -Force -ErrorAction SilentlyContinue
    $gitRank  = @($rows | Where-Object { $_ -like 'git|*' }  | Sort-Object { if ($_ -like '*|OK') { [double]($_ -split '\|')[2] } else { 9999 } })
    $pypiRank = @($rows | Where-Object { $_ -like 'pypi|*' } | Sort-Object { if ($_ -like '*KB/s*') { -[double](($_ -split '\|')[3] -replace 'KB/s','') } else { 999999999 } })
    $head = if ($sha) { "=== 升级镜像测速 " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " (SHA基准 " + $sha.Substring(0,12) + ") ===" }
            else      { "=== 升级镜像测速 " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " (取不到SHA基准, 只按速度排序) ===" }
    foreach ($t in (@($head, "--- git 通道 ---") + $gitRank + @("--- PyPI 通道 ---") + $pypiRank)) {
        Write-Host ("   " + ($t -replace '\|', ' | '))
        try { Add-Content -Path $UPLOGF -Value $t -Encoding UTF8 } catch { }
    }
    $bestGit = $null; $bestPypi = $null
    foreach ($r in $gitRank)  { if ($r -like '*|OK')   { $nm = ($r -split '\|')[1]; $e = @($UPGIT  | Where-Object { $_[0] -eq $nm }); if ($e.Count) { $bestGit  = $e[0][1]; break } } }
    foreach ($r in $pypiRank) { if ($r -like '*KB/s*') { $nm = ($r -split '\|')[1]; $e = @($UPPYI | Where-Object { $_[0] -eq $nm }); if ($e.Count) { $bestPypi = $e[0][1]; break } } }
    return @{ git = $bestGit; pypi = $bestPypi }
}
function HermesUpgrade {
    $gitDir   = "D:\ProgramFiles\Hermes_Desktop\hermes-agent"
    $official = "https://github.com/NousResearch/hermes-agent.git"
    $PKEY = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Note "=================== Hermes 升级 (git+PyPI 镜像自动测速择优) ==================="
    Note "提醒: 升级完成时网关会自动重启, 当前会话会短断 (桌面/微信稍后自动重连)"
    # zero out proxy residue (11-03: after sing-box stops, ProxyEnable may stay 1 and uv chokes on the dead proxy)
    if ((Get-ItemProperty $PKEY -ErrorAction SilentlyContinue).ProxyEnable -eq 1) {
        Set-ItemProperty $PKEY ProxyEnable -Value 0 -ErrorAction SilentlyContinue
        Note "   系统代理残留 (ProxyEnable=1) 已归零"
    }
    $verBefore = (& $HERMEXE --version 2>&1 | Select-Object -First 1)
    Note ("   升级前版本: " + $verBefore)
    Show-UpgradePrecheck
    Note "--- 测速选镜像 (并行探测约30s, 排名落盘 ysk_upgrade_mirror.log) ---"
    $best = Show-MirrorRanking
    if ($best.git) {
        $gn = @($UPGIT  | Where-Object { $_[1] -eq $best.git })[0][0]
        Note ("   git 通道择优: " + $gn)
    } else { Note "!! git 通道全灭 -- 保持现有 origin 直接跑 (git 步骤可能失败, 依赖镜像仍生效)" }
    if ($best.pypi) {
        $pn = @($UPPYI | Where-Object { $_[1] -eq $best.pypi })[0][0]
        Note ("   PyPI 通道择优: " + $pn)
    } else { Note "!! PyPI 通道全灭 -- uv/pip 走默认源 (大概率慢, 升级会拖长)" }
    try {
        if ($best.git) { git -C $gitDir remote set-url origin $best.git 2>&1 | Out-Null }
        if ($best.pypi) {
            $env:UV_DEFAULT_INDEX = $best.pypi
            $env:UV_INDEX_URL     = $best.pypi
            $env:PIP_INDEX_URL    = $best.pypi
        }
        # desktop shell rebuild (electron-builder) pulls electron binary + npm packages, all direct from github/npmjs;
        # measured 10-19: electron download timed out at 64% and shell build failed. npmmirror injected (261104), scoped to this function.
        $env:ELECTRON_MIRROR     = 'https://npmmirror.com/mirrors/electron/'
        $env:ELECTRON_GET_MIRROR = 'https://npmmirror.com/mirrors/electron/'
        $env:npm_config_registry = 'https://registry.npmmirror.com'
        & $HERMEXE update 2>&1 | ForEach-Object { Note ("   " + $_) }
    } finally {
        # 261112 final: finish on the SSH tunnel (no longer switch back to official https) -- GFW blocks https as the norm,
        git -C $gitDir remote set-url origin "git@github.com:NousResearch/hermes-agent.git" 2>&1 | Out-Null
        @('ELECTRON_MIRROR','ELECTRON_GET_MIRROR','npm_config_registry') | ForEach-Object { Remove-Item "env:$_" -ErrorAction SilentlyContinue }
        Note "--- origin 已定版 SSH 隧道 (git@github.com -> ssh.github.com:443, 升级怎么死都不留副作用) ---"
    }
    $verAfter = (& $HERMEXE --version 2>&1 | Select-Object -First 1)
    Note ("   升级后版本: " + $verAfter)
    Show-UpdateVerdict $verBefore $verAfter $best
}
# --- post-upgrade verdict (261104; lesson 261103: version changed but deps failed / desktop shell rebuild
#     pending, yet the old verdict printed OK from the version string alone, swallowing the debt. Now: read the freshest update_receipts JSON) ---
$global:ReceiptAgeMin = 120   # receipt freshness window (min); verdict trusts only freshly baked receipts; tests may override
function Get-LatestUpdateReceipt {
    try {
        $d = "D:\ProgramFiles\Hermes_Desktop\logs\update_receipts"
        $f = @(Get-ChildItem $d -Filter 'update_*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($f.Count -eq 0) { return $null }
        return @{ file = $f[0].FullName; ageMin = [math]::Round(((Get-Date) - $f[0].LastWriteTime).TotalMinutes); json = (Get-Content $f[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json) }
    } catch { return $null }
}
function Show-UpdateVerdict($verBefore, $verAfter, $best) {
    $changed = ([string]$verAfter -ne [string]$verBefore)
    $r = Get-LatestUpdateReceipt
    $ageCap = if ($global:ReceiptAgeMin) { $global:ReceiptAgeMin } else { 120 }   # overridable via global to widen the freshness window (tests/postmortem)
    if (-not $r -or [double]$r.ageMin -gt [double]$ageCap) {
        if ($changed) { Note "=================== 版本已变 (回执读不到/太旧, 定性看 update.log) ===================" }
        else          { Note "=================== 版本未变化 (已是最新, 或升级失败) -- 看 update.log ===================" }
        return
    }
        $j = $r.json
    $stageBad = @($j.stages | Where-Object { $_.outcome -ne 'success' })
    $follows  = @($j.followups)
    Note ("--- 升级回执: " + $r.file.Split('\')[-1] + " (outcome=" + $j.outcome + ", 写于 " + [math]::Round($r.ageMin) + " 分钟前) ---")
    foreach ($s in $stageBad)  { Note ("   !! stage " + $s.name + " = " + $s.outcome) }
    if ($j.exit_code -ne 0)    { Note ("   !! 回执 exit_code=" + $j.exit_code + " (" + $j.stop_reason + ")") }
    if ($null -ne $j.pm_exit_code -and [int]$j.pm_exit_code -ne 0) { Note ("   !! pm_exit_code=" + $j.pm_exit_code + " (依赖/组件层欠账, 详看 pm_steps)") }
    foreach ($fu in $follows)  { Note ("   欠账 followup: " + $fu.step + " -- " + ("" + $fu.reason).Substring(0, [Math]::Min(160, ("" + $fu.reason).Length))) }
    # dep-debt self-heal: 261103 proved uv.lock pins absolute files.pythonhosted.org URLs, so
    # UV_DEFAULT_INDEX does not affect lock-replay -> nemo-relay direct download timed out. Fallback:
    # retry once with tools uv + --default-index champion mirror against the live workspace env (hits the mirror, no direct);
    if (@($stageBad | Where-Object { $_.name -eq 'deps' }).Count -gt 0) {
        $uv = @(Get-ChildItem "D:\ProgramFiles\Hermes_Desktop\tools" -Directory -Filter 'uv-*' -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'uv.exe' } | Where-Object { Test-Path $_ })
        $idx = if ($best -and $best.pypi) { $best.pypi } else { $env:UV_DEFAULT_INDEX }
        $ws  = $null
        if (@($uv).Count -gt 0 -and $idx) {
            foreach ($ff in @(Get-ChildItem "D:\ProgramFiles\Hermes_Desktop\installs" -Recurse -Depth 2 -Filter facts.json -ErrorAction SilentlyContinue)) {
                try {
                    $envs = (Get-Content $ff.FullName -Raw | ConvertFrom-Json).packages
                    foreach ($p in $envs.PSObject.Properties) {
                        $cand = Join-Path ($envs.($p.Name).environment) 'workspace'
                        if (Test-Path (Join-Path $cand 'uv.lock')) { $ws = $cand }
                    }
                } catch { }
                if ($ws) { break }
            }
        }
        if (@($uv).Count -gt 0 -and $ws -and $idx) {
            Note ("   检测到依赖欠账 -> 用镜像补跑 uv sync (index=" + $idx + ", 最长15分钟) ...")
            $out = & $uv[0] sync --no-dev --default-index $idx --directory $ws 2>&1 | Select-Object -Last 12
            if ($LASTEXITCODE -eq 0) { Note "   依赖补装 OK -- 欠账已销 (桌面壳重建仍欠, 下次启动/hermes update 自动重试)" }
            else { Note "   !! 补跑仍失败 rc=$LASTEXITCODE -- 下次启动会自动再试; 全文见 update.log"; foreach ($l in $out) { Note ("      " + $l) } }
        } else {
            Note "   依赖欠账: 未找到 uv/workspace/镜像, 下次 hermes 启动会自动重试 (261103 实测可自愈)"
        }
    }
    # old/new desktop shell verdict
    try {
        $asar = Get-Item 'D:\ProgramFiles\Hermes_Desktop\hermes-agent\apps\desktop\release\win-unpacked\resources\app.asar' -ErrorAction SilentlyContinue
        if ($j.post_update -and $asar) {
            $st = [DateTimeOffset]::Parse($j.started_at).UtcDateTime
            if ($asar.LastWriteTimeUtc -lt $st) {
                Note ("   桌面壳仍是旧的 (app.asar " + $asar.LastWriteTime.ToString('MM-dd HH:mm') + " 早于本轮升级 " + $st.ToLocalTime().ToString('MM-dd HH:mm') + ") -- 下次启动/hermes update 自动补建 (electron 已配 npmmirror)")
            }
        }
    } catch { }
    if ($changed -and $stageBad.Count -eq 0 -and $follows.Count -eq 0 -and [int]$j.exit_code -eq 0) {
        Note "=================== 升级完成 OK 全清 (网关自动重启, 会话会短断) ==================="
    } elseif ($changed) {
        Note "=================== 版本已升但有上表欠账 -- 多数下次启动自愈, 追的账见上 ==================="
    } else {
        Note "=================== 版本未变化 (已是最新, 或升级失败) -- 看上方回执与 update.log ==================="
    }
}
# --- pre-upgrade debt roll-call (261104; update.log complains about autostash/stale locks/partial pkgs every run; name them upfront, report only, delete nothing) ---
function Show-UpgradePrecheck {
    Note "--- 升级前旧账点名 (只报不删) ---"
    $h = "D:\ProgramFiles\Hermes_Desktop"
    $old = @(Get-ChildItem $h -Filter '.hermes-update-*.lock' -Force -ErrorAction SilentlyContinue | Where-Object { ((Get-Date) - $_.LastWriteTime).TotalDays -gt 1 })
    if ($old.Count) { foreach ($f in $old) { Note ("   遗留升级锁(>1天): " + $f.Name + " (" + $f.LastWriteTime.ToString('MM-dd') + ") -- 升级器会自己处置, 无害") } }
    $inc = @(Get-ChildItem "$h\backups" -Filter 'pre-update-*.incomplete.zip' -ErrorAction SilentlyContinue)
    if ($inc.Count) { foreach ($f in $inc) { Note ("   未完成的升级备份残包: " + $f.Name + " (" + [math]::Round($f.Length/1MB) + "MB, 可手动删)") } }
    try {
        $st = git -C "$h\hermes-agent" stash list 2>$null | Where-Object { $_ -match 'autostash-(\d{8})' }
        foreach ($s in $st) {
            $d = [DateTime]::ParseExact($Matches[1], 'yyyyMMdd', $null)
            if (((Get-Date) - $d).TotalDays -gt 7) { Note ("   陈旧 autostash (" + [math]::Round(((Get-Date) - $d).TotalDays) + "天前) -- 多为旧版残骸; 主人点头才可 git stash drop") }
        }
    } catch { }
    $xec = "$h\.update_exit_code"
    if (Test-Path $xec) { Note ("   .update_exit_code=" + (Get-Content $xec -Raw).Trim() + " (历史残值, 下次升级会重写)") }
}

# ---------------------------------------------------------------------------
# [u>1] Strata mirror upgrade + [u>3] KVMem mirror upgrade (2026-11-03)
#   same iron rule as u>5: rank the whole mirror pool first, take the fastest, never hardcode a mirror.
#   shared pool template: {0} gets "<org>/<repo>...", one pool serves three components.
#   git lane probed by ls-remote HEAD; release-download lane probed by sampling 512KB via range.
#   lesson 1465 baked in: force --noproxy/direct for every curl/git call + ProxyEnable=0;
#   single-connection resumable download for big files (multi-thread chunks get RST'd during GFW watch).
# ---------------------------------------------------------------------------
$UPGIT_TPL = @(
    @("direct-github",  "https://github.com/{0}"),
    @("gh-proxy.com",   "https://gh-proxy.com/https://github.com/{0}"),
    @("ghfast.top",     "https://ghfast.top/https://github.com/{0}"),
    @("ghproxy.net",    "https://ghproxy.net/https://github.com/{0}"),
    @("mirror.ghproxy", "https://mirror.ghproxy.com/https://github.com/{0}"),
    @("gh.llkk.cc",     "https://gh.llkk.cc/https://github.com/{0}"),
    @("moeyy.xyz",      "https://github.moeyy.xyz/https://github.com/{0}"),
    @("bgithub.xyz",    "https://bgithub.xyz/{0}"),
    @("gitclone.com",   "https://gitclone.com/github.com/{0}")
)
$UPDL_TPL = @(
    @("direct-github",  ""),
    @("gh-proxy.com",   "https://gh-proxy.com/"),
    @("ghfast.top",     "https://ghfast.top/"),
    @("ghproxy.net",    "https://ghproxy.net/"),
    @("mirror.ghproxy", "https://mirror.ghproxy.com/"),
    @("gh.llkk.cc",     "https://gh.llkk.cc/"),
    @("moeyy.xyz",      "https://github.moeyy.xyz/")
)
function Get-GitPool([string]$repoPath) {
    return @($UPGIT_TPL | ForEach-Object { , @($_[0], ($_[1] -f $repoPath)) })
}
function Show-MirrorRanking2 {
    param([string]$GitRepo = '', [string]$DlUrl = '')
    # GitRepo='<org>/<repo>.git' ranks the git pool; DlUrl=full release url ranks the download pool; returns @{git=best; dl=best prefix}
    $probe = {
        param($kind, $name, $url)
        $t0 = Get-Date
        if ($kind -eq 'git') {
            $env:GIT_TERMINAL_PROMPT = '0'
            git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=8 ls-remote --exit-code $url HEAD 2>&1 | Out-Null
            $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
            if ($LASTEXITCODE -eq 0) { return "git|$name|$sec|OK" }
            return "git|$name|$sec|FAIL rc=$LASTEXITCODE"
        }
        $spd = & curl.exe -s --noproxy '*' -L --max-time 25 -r 0-524287 -o NUL -w "%{speed_download}" ($url + $env:UPDL_TAIL) 2>$null
        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $v = 0.0; [void][double]::TryParse("$spd", [ref]$v)
        if ($v -gt 0) { return "dl|$name|$sec|{0}KB/s" -f [math]::Round($v/1KB, 1) }
        return "dl|$name|$sec|FAIL"
    }
    $env:UPDL_TAIL = $DlUrl   # job subprocesses cannot see closure vars; pass through env inheritance to the probe block
    $jobs = @()
    if ($GitRepo) { foreach ($m in (Get-GitPool $GitRepo)) { $jobs += Start-Job -Name ("g2:" + $m[0]) -ScriptBlock $probe -ArgumentList 'git', $m[0], $m[1] } }
    if ($DlUrl)    { foreach ($m in $UPDL_TPL) { $jobs += Start-Job -Name ("d2:" + $m[0]) -ScriptBlock $probe -ArgumentList 'dl', $m[0], $m[1] } }
    $rows = @(Wait-Job -Job $jobs -Timeout 60 | Receive-Job | Where-Object { $_ })
    if ($GitRepo -and @($rows | Where-Object { $_ -like 'git|*|OK' }).Count -eq 0) {
        Write-Host "   git 镜像全灭 -- 自动重试一轮"
        $rows = @($rows | Where-Object { $_ -notlike 'git|*' })
        $rj = @()
        foreach ($m in (Get-GitPool $GitRepo)) { $rj += Start-Job -Name ("g2R2:" + $m[0]) -ScriptBlock $probe -ArgumentList 'git', $m[0], $m[1] }
        $rows += @(Wait-Job -Job $rj -Timeout 60 | Receive-Job | Where-Object { $_ }); $jobs += $rj
    }
    $got = @($rows | ForEach-Object { ($_ -split '\|')[1] })
    foreach ($jb in $jobs) {
        $short = $jb.Name -replace '^(g2R2|g2|d2):', ''
        $kind  = if ($jb.Name -like 'g2*') { 'git' } else { 'dl' }
        if ($jb.State -in 'Running','Suspending','Failed' -and ($short -notin $got)) {
            $rows += ("{0}|{1}|999|TIMEOUT/崩 (60s无应答)" -f $kind, $short); $got += $short
        }
    }
    Remove-Job * -Force -ErrorAction SilentlyContinue
    $gitRank = @($rows | Where-Object { $_ -like 'git|*' } | Sort-Object { if ($_ -like '*|OK') { [double]($_ -split '\|')[2] } else { 9999 } })
    $dlRank  = @($rows | Where-Object { $_ -like 'dl|*' }  | Sort-Object { if ($_ -like '*KB/s*') { -[double](($_ -split '\|')[3] -replace 'KB/s','') } else { 999999999 } })
    $head = "=== 升级镜像测速 " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " (" + $(if ($GitRepo) { "git:" + $GitRepo } else { "" }) + $(if ($DlUrl) { " dl:release" } else { "" }) + ") ==="
    $lines = @($head)
    if ($GitRepo) { $lines += @("--- git 通道 ---") + $gitRank }
    if ($DlUrl)   { $lines += @("--- release 下载通道 ---") + $dlRank }
    foreach ($t in $lines) { Write-Host ("   " + ($t -replace '\|', ' | ')); try { Add-Content -Path $UPLOGF -Value $t -Encoding UTF8 } catch { } }
    $bestGit = $null; $ranked = @(); $bestDl = $null
    foreach ($r in $gitRank) { if ($r -like '*|OK') { $nm = ($r -split '\|')[1]; $e = @((Get-GitPool $GitRepo) | Where-Object { $_[0] -eq $nm }); if ($e.Count) { $ranked += $e[0][1] } } }
    if ($ranked.Count) { $bestGit = $ranked[0] }
    foreach ($r in $dlRank) { if ($r -like '*KB/s*') { $nm = ($r -split '\|')[1]; $e = @($UPDL_TPL | Where-Object { $_[0] -eq $nm }); if ($e.Count) { $bestDl = $e[0][1]; break } } }
    return @{ git = $bestGit; gitRanked = $ranked; dl = $bestDl }
}
function KillProxyResidue {
    $PKEY = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if ((Get-ItemProperty $PKEY -ErrorAction SilentlyContinue).ProxyEnable -eq 1) {
        Set-ItemProperty $PKEY ProxyEnable -Value 0 -ErrorAction SilentlyContinue
        Note "   系统代理残留 (ProxyEnable=1) 已归零 (一切联网直连, 1465 实锤教训)"
    }
}
function CopyWithRetry($src, $dst, $tries) {
    # 0151 swap lesson: a dying serve process holds the exe lock -- retry until released, never fail fast
    for ($i = 0; $i -lt $tries; $i++) {
        Copy-Item $src $dst -Force -ErrorAction SilentlyContinue
        if ($?) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

# ===========================================================================
# engine-version / receipts / rollback / tuning shared kit (2026-11-12, closing the ledger-drift root cause)
#   the old way treated git describe / engine\BUILD.json as 'current version'; both drift:
#     - the 11-08 compile produced no BUILD.json -> ledger stuck at 0.1.56 while the exe was 0.1.58
#     - after 11-09 main leads the newest tag -> describe said 'already latest', u>1 could not even offer a tag
#   final rule: the only trusted source is the stamp in engine\strata.exe --version
# ===========================================================================
$script:EngVerCacheT = $null; $script:EngVerCacheLine = ''
$RECEIPT_DIR = 'E:\DSDeployMaster\Strata\ysk_upgrade_receipts'

function StrataEngineVer {
    param([string]$dir = 'E:\DSDeployMaster\Strata')
    $exe = $dir + '\engine\strata.exe'
    if (-not (Test-Path $exe)) { return 'exe缺位' }
    try {
        $o = (& $exe --version 2>&1 | Out-String)
        $m = [regex]::Match($o, '(?m)^strata\s+([0-9][0-9A-Za-z._-]*)')
        if ($m.Success) { return $m.Groups[1].Value }
    } catch { }
    return '未知'
}
function StrataRepoVer {
    param([string]$dir = 'E:\DSDeployMaster\Strata')
    try { $t = (& git -C $dir describe --tags 2>&1 | Select-Object -First 1); if ($t) { return ("$t").Trim() } } catch { }
    return '未知'
}
function StrataTagEngineVer {
    # engine version of a tag = project(strata VERSION x.y.z) in that tag's CMakeLists (local git show, no network)
    param([string]$tag, [string]$dir = 'E:\DSDeployMaster\Strata')
    # 261120 audit: v0.2.16 moved CMakeLists into engine\ (verified live: tag v0.2.16 has NO
    #   top-level CMakeLists.txt) -- with only the old path this returned '' for every new-layout
    #   tag, silently disabling u>1's 'tag engine version vs live exe' judging and [3]'s lag line.
    #   Probe engine\ first (0.2.16+), keep the top level as fallback for pre-0.2.16 tags.
    try {
        foreach ($cmp in @('engine/CMakeLists.txt', 'CMakeLists.txt')) {
            $cm = (& git -C $dir show ($tag + ':' + $cmp) 2>&1) -join "`n"
            $m = [regex]::Match($cm, 'project\(\s*strata\s+VERSION\s+([0-9][0-9.]*)')
            if ($m.Success) { return $m.Groups[1].Value }
        }
    } catch { }
    return ''
}
function KvmemEngineVer {
    param([string]$serve = 'E:\DSDeployMaster\ysk_autostart\ysk_serve_kvmem.bat')
    if (-not (Test-Path $serve)) { return '未知' }
    try {
        $sc = [IO.File]::ReadAllText($serve, [Text.Encoding]::GetEncoding(28591))
        $m = [regex]::Match($sc, 'kvmem-v([0-9.]+)-unified')
        if ($m.Success) { return 'v' + $m.Groups[1].Value }
    } catch { }
    return '未知'
}
function VerKey { param($v) try { return [version](("$v") -replace '^v', '') } catch { } return [version]'0.0' }
function VerKeyFromName { param($s) $m = [regex]::Match("$s", '[0-9]+(?:\.[0-9]+)*'); try { if ($m.Success) { return [version]$m.Value } } catch { } return [version]'0.0' }

function Set-JsonEnvKey($obj, [string]$name, $val) {
    if ($obj.PSObject.Properties.Name -contains $name) { $obj.$name = "$val" }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue "$val" }
}
function Write-StrataBuildJson {
    param([string]$version, [string]$src, [string]$recipe, [string]$note = '')
    try {
        $j = [ordered]@{ built = (Get-Date -Format 'yyyy-MM-dd'); source = 'local'; version = $version
                         archs = @(70); vision = 'gpu'; src = $src; recipe = $recipe; note = $note }
        [IO.File]::WriteAllText('E:\DSDeployMaster\Strata\engine\BUILD.json', ($j | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
        Note ('   engine\BUILD.json 已按 exe 实测版本重写: ' + $version)
    } catch { Note '   !! BUILD.json 写入失败 (不影响引擎)' }
}
function Write-EngineReceipt {
    # write a JSON receipt on every upgrade/rollback (u>5 had update_receipts; u>1/u>3 had none -> no audit trail)
    param([string]$what, [hashtable]$data)
    try {
        if (-not (Test-Path $RECEIPT_DIR)) { New-Item -ItemType Directory -Path $RECEIPT_DIR -Force | Out-Null }
        $f = Join-Path $RECEIPT_DIR ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + $what + '.json')
        ($data | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $f -Encoding UTF8
        Note ('   回执落盘: ' + $f)
        return $f
    } catch { Note '   !! 回执落盘失败 (不影响升级结果)'; return '' }
}
function Show-UpgradeHistory {
    Note '=================== 最近引擎 / Hermes 升级回执 ==================='
    try {
        if (Test-Path $RECEIPT_DIR) {
            $fs = @(Get-ChildItem $RECEIPT_DIR -Filter '*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 5)
            if ($fs.Count) {
                foreach ($f in $fs) {
                    $j = $null; try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { }
                    if ($j) {
                        $bits = @()
                        foreach ($k in @('kind','tag','engine_before','engine_after','after','rollback_to','choice','health')) {
                            if ($j.PSObject.Properties.Name -contains $k) { $bits += ($k + '=' + $j.$k) }
                        }
                        Note ('   ' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '  ' + ($bits -join '  '))
                    } else { Note ('   ' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '  ' + $f.Name + ' (JSON 读不出)') }
                }
            } else { Note '   (引擎回执目录还是空的 -- [u] 组里的升级/回滚/调参收尾都会落一份)' }
        } else { Note '   (还没有引擎回执目录)' }
    } catch { }
    try {
        $hd = 'D:\ProgramFiles\Hermes_Desktop\logs\update_receipts'
        if (Test-Path $hd) {
            $hf = @(Get-ChildItem $hd -Filter 'update_*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
            if ($hf.Count) { Note ('   Hermes 最近升级回执: ' + $hf[0].LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '  ' + $hf[0].Name) }
        }
    } catch { }
}
function Test-StrataArgsCompat {
    # collect the target exe's --help flag names and diff against the live serve config's args.
    # 11-12 real case: a rollback test picked 0.1.35, which rejects --conversation-cache-min-tokens /
    #   --spec-min-p / --vram-reserve-mib -> serve exited(2) and 8080 lied there all day. One question before install would have stopped it.
    param([string]$exe, [string]$cfg = 'E:\DSDeployMaster\Strata\strata-iq3_s.json')
    if (-not (Test-Path $exe)) { return @('__exe缺失__') }
    $help = ''
    try { $help = (& $exe --help 2>&1 | Out-String) } catch { return @('__help读不出__') }
    if ($help.Length -lt 200) { return @('__help读不出__') }
    $sup = @{}
    foreach ($m in [regex]::Matches($help, '--[a-z0-9][a-z0-9-]*')) { $sup[$m.Value] = $true }
    $j = $null
    try { $j = Get-Content $cfg -Raw | ConvertFrom-Json } catch { return @('__配置读不出__') }
    if (-not $j.args) { return @('__配置读不出__') }
    $miss = @()
    foreach ($a in $j.args) {
        $s = "$a"
        if ($s -match '^--[a-z0-9][a-z0-9-]*$' -and -not $sup.ContainsKey($s)) { $miss += $s }
    }
    return $miss
}
function Restore-StrataEngineFromBak {
    # self-rescue when 8080 cannot start after an engine swap: reinstall the just-swapped-out exe and relaunch (the old code merely printed 'rollback with the bak if needed' and walked away)
    param([string]$bakExe, [string]$bakVis = '', [string]$label = '')
    $S_DIR = 'E:\DSDeployMaster\Strata'
    if (-not (Test-Path $bakExe)) { Note ('   !! 回退物不在位: ' + $bakExe + ' -- 救不回来, 需人工'); return $false }
    Note ('=================== 自动回退自救: ' + $label + ' -> 装回 ' + (Split-Path $bakExe -Leaf) + ' ===================')
    TaskStop $TASK_S
    KillGuard 'serve_strata|task_strata'
    KillStrata
    Start-Sleep -Seconds 8
    if (-not (CopyWithRetry $bakExe (Join-Path $S_DIR 'engine\strata.exe') 30)) { Note '   !! 自救拷贝失败 (锁未释放?) -- 需人工'; return $false }
    if ($bakVis -and (Test-Path $bakVis)) { CopyWithRetry $bakVis (Join-Path $S_DIR 'engine\strata-vision.exe') 10 | Out-Null }
    $v = StrataEngineVer -dir $S_DIR
    Write-StrataBuildJson -version $v -src ('auto-rollback (' + $label + ')') -recipe 'console 自救回退' -note ('8080 起不来, 已装回 ' + (Split-Path $bakExe -Leaf))
    TaskRun $TASK_S
    return (Wait-StrataHealth -rounds 24 -EarlyAbort)
}
function Wait-StrataHealth {
    param([int]$rounds = 48, [switch]$EarlyAbort)
    $miss = 0
    for ($i = 0; $i -lt $rounds; $i++) {
        Start-Sleep -Seconds 15
        & curl.exe -s -o NUL --noproxy '*' --max-time 5 http://127.0.0.1:8080/health
        if ($LASTEXITCODE -eq 0) { return $true }
        if ($EarlyAbort -and -not (PortPid 8080)) {
            # if the serve process chain is gone, the engine simply cannot start (bad args/bad weights all look like this) -- stop waiting
            $alive = $true
            try {
                $alive = @(Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
                           Where-Object { $_.CommandLine -like '*serve*server.py*' }).Count -gt 0
            } catch { $alive = $true }
            if (-not $alive) {
                $miss++
                if ($miss -ge 4) { Note ('   serve 进程链已不在 (连续 ' + ($miss * 15) + 's) -- 判引擎起不来, 早停'); return $false }
            } else { $miss = 0 }
        }
        if ((($i + 1) % 4) -eq 0) { Note ('   加载中... 已等 ' + [int](($i + 1) / 4) + ' 分钟') }
    }
    return $false
}
function EngineVerLine {
    $now = Get-Date
    if ($script:EngVerCacheT -and (($now - $script:EngVerCacheT).TotalSeconds -lt 60)) { return $script:EngVerCacheLine }
    $run = StrataEngineVer; $bj = ''
    try { $bj = (Get-Content 'E:\DSDeployMaster\Strata\engine\BUILD.json' -Raw | ConvertFrom-Json).version } catch { }
    $drift = ''
    if ($bj -and ($bj -ne $run)) { $drift = '   ⚠BUILD.json 登记=' + $bj + ' 与在役 exe 不符' }
    $line = '    引擎: Strata exe=' + $run + '   KVMem=' + (KvmemEngineVer) + '   代码=' + (StrataRepoVer) + $drift
    $script:EngVerCacheT = $now; $script:EngVerCacheLine = $line
    return $line
}

# Shared bak inventory: u>2 prints it for humans, -ListBak dumps it as JSON for the GUI
# radio dialog -- one listing logic, two consumers (2026-11-20 GUI front-end work).
function List-StrataBakItems {
    $S_DIR = 'E:\DSDeployMaster\Strata'
    $baks = @(Get-ChildItem (Join-Path $S_DIR 'engine') -Filter 'strata-*.bak.exe' |
              Where-Object { $_.Name -notmatch 'vision' } |
              Sort-Object { VerKeyFromName ($_.BaseName -replace '^strata-', '') } -Descending)
    $visMap = @{}
    foreach ($v in @(Get-ChildItem (Join-Path $S_DIR 'engine') -Filter 'strata-vision-*.bak.exe')) {
        $k = [regex]::Match($v.BaseName, 'strata-vision-(.+)\.bak$').Groups[1].Value
        # early vision baks were named with 4 digits (strata-vision-0144.bak.exe) while engine side says 0.1.44 -- normalize to match
        if ($k -match '^0*(\d)(\d{2})$') { $k = '0.1.' + [int]$Matches[2] }
        if ($k -and -not $visMap.ContainsKey($k)) { $visMap[$k] = $v.FullName }
    }
    $out = @(); $n = 0
    foreach ($b in $baks) {
        $n++
        $bv = [regex]::Match($b.BaseName, 'strata-(.+)\.bak$').Groups[1].Value
        $vis = ''; if ($visMap.ContainsKey($bv)) { $vis = $visMap[$bv] }
        $out += [pscustomobject]@{ i = $n; ver = $bv; file = $b.FullName; visFile = $vis
            vision = [bool]$vis; sizeMb = [math]::Round($b.Length / 1MB)
            date = $b.LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
    }
    return $out
}

# ---- [u>2] Strata engine rollback (used to require hand-running ysk_strata_rollback_0144.bat, a 10-14 era name)
function StrataRollback {
    $S_DIR = 'E:\DSDeployMaster\Strata'
    KillProxyResidue
    Note '=================== Strata 引擎回滚 (从 engine\*.bak.exe 挑一件装回) ==================='
    $run = StrataEngineVer -dir $S_DIR
    Note ('   在役 exe: ' + $run + ' | 代码 git: ' + (StrataRepoVer -dir $S_DIR))
    $baks = List-StrataBakItems
    if (-not $baks.Count) { Note '!! engine\ 下没有 strata-<ver>.bak.exe -- 无从回滚'; return }
    foreach ($b in $baks) {
        $vt = if ($b.vision) { 'vision有' } else { 'vision无' }
        Note ('   [' + $b.i + '] ' + $b.ver + '   ' + $b.sizeMb + 'MB  ' + $b.date + '  ' + $vt)
    }
    $ans = Ask '   输入序号回滚 (q=取消)'
    if ("$ans".Trim().ToLower() -eq 'q' -or "$ans".Trim() -eq '') { Note '   已取消'; return }
    $n = 0
    if (-not [int]::TryParse("$ans".Trim(), [ref]$n)) { Note '!! 不是序号 -- 取消'; return }
    if ($n -lt 1 -or $n -gt $baks.Count) { Note '!! 序号超出范围 -- 取消'; return }
    $pick = $baks[$n - 1]
    $pk = $pick.ver
    if ($run -eq $pk) { Note ('   选的就是在役版本 ' + $pk + ' -- 无需回滚'); return }
    $miss = Test-StrataArgsCompat -exe $pick.FullName
    if ($miss -and ($miss[0] -notmatch '^__')) {
        Note ('!! 兼容性预检: ' + $pk + ' 不认现役 serve 配置的参数 -> ' + ($miss -join ' '))
        Note '   装上去多半直接 exit(2) 起不来 (11-12 那次 0.1.35 事故正是这症状); 起不来本功能会自动回退, 但 8080 会先躺几分钟'
    } elseif (-not $miss) { Note '   兼容性预检: 该引擎认现役配置的全部参数 OK' }
    else { Note ('   兼容性预检没跑成 (' + ($miss -join '') + ') -- 继续, 心里有数') }
    Note ('   接下来会: 停 Strata 8080 与守护 -> 在役 ' + $run + ' 存 bak -> 装 ' + $pk + ' -> 重挂守护 (短断对话属预期)')
    $cf = Ask '   确认开始回滚? (回车=开始, q=取消)'
    if ("$cf".Trim().ToLower() -eq 'q') { Note '   已取消'; return }
    Note '--- swap: 请走 KVMem/ComfyUI, 腾双卡 ---'
    if (PortPid 8188) { KillService 'ComfyUI' 8188 | Out-Null }
    if (PortPid 18200) { TaskStop $TASK_K; KillService 'KVMem快通道 18200' 18200 | Out-Null }
    TaskStop $TASK_S
    KillGuard 'serve_strata|task_strata'
    KillStrata
    Start-Sleep -Seconds 12
    $stamp = Get-Date -Format 'yyMMdd_HHmm'
    $curBak = Join-Path $S_DIR ('engine\strata-' + $run + '-swapped-' + $stamp + '.bak.exe')
    if (-not (CopyWithRetry (Join-Path $S_DIR 'engine\strata.exe') $curBak 30)) { Note '!! 备份在役 exe 失败 (锁未释放?) -- 中止, 守护未开'; return }
    if (-not (CopyWithRetry $pick.FullName (Join-Path $S_DIR 'engine\strata.exe') 30)) { Note '!! 装回失败 -- 中止, 守护未开'; return }
    $visNote = 'vision 未动'; $curVis = ''   # init: the auto-rollback below may run when no vision bak was swapped
    if ($pick.visFile) {
        $curVis = Join-Path $S_DIR ('engine\strata-vision-' + $run + '-swapped-' + $stamp + '.bak.exe')
        if (Test-Path (Join-Path $S_DIR 'engine\strata-vision.exe')) { CopyWithRetry (Join-Path $S_DIR 'engine\strata-vision.exe') $curVis 10 | Out-Null }
        if (-not (CopyWithRetry $pick.visFile (Join-Path $S_DIR 'engine\strata-vision.exe') 30)) { Note '!! vision 装回失败 (引擎已回, 继续)' }
        else { $visNote = 'vision 同步回滚: ' + $pk }
    } else { Note ('   (没有 ' + $pk + ' 的 vision bak, strata-vision.exe 保持不动)') }
    $back = StrataEngineVer -dir $S_DIR
    Write-StrataBuildJson -version $back -src ('rollback (git ' + (StrataRepoVer -dir $S_DIR) + ')') -recipe 'console [u>2]' -note ('swapped back from ' + $run + ' to ' + $pk)
    Note '--- 重挂守护并拉起, health 轮询最多 12 分钟 ---'
    TaskRun $TASK_S   # zombie-retry + ACL-safe enable (11-13/11-17 lessons), same as u>1
    $ok = Wait-StrataHealth
    # auto-rollback re-weld (261120 audit): if the restored OLD exe still cannot serve (weights/env
    #   drift beyond what the flag precheck sees), put the just-swapped-out current version back.
    if (-not $ok -and (Test-Path $curBak)) {
        $ok = Restore-StrataEngineFromBak -bakExe $curBak -bakVis $(if ($curVis -and (Test-Path $curVis)) { $curVis } else { '' }) -label ("u>2 回滚后未就绪 -- 自动装回 " + $run)
        $back = StrataEngineVer -dir $S_DIR
        Write-EngineReceipt -what 'strata_auto_rollback' -data @{ kind='strata_auto_rollback'; rollback_target=$pk; back_to=$run; health=$(if ($ok) { 'ok' } else { 'not_ready' }) } | Out-Null
    }
    $sha = ''
    try { $sha = (Get-FileHash -Algorithm SHA256 (Join-Path $S_DIR 'engine\strata.exe')).Hash.ToLower() } catch { }
    Write-EngineReceipt -what 'strata_rollback' -data @{ kind='strata_rollback'; engine_before=$run; engine_after=$back
        rollback_to=$pk; vision=$visNote; health=$(if ($ok) { 'ok' } else { 'not_ready_12min' }); exe_sha256=$sha
        backup_of_swapped_out=(Split-Path $curBak -Leaf) } | Out-Null
    if ($ok) {
        Note ('=================== 回滚完成: ' + $run + ' -> ' + $back + ' (8080 healthy) ===================')
        Note '   按 10-26 铁律: 不自动切 provider -- 主人关 Hermes 后用一级 [1] 切 Strata'
        Note ('   被换下的 ' + $run + ' 已存: ' + (Split-Path $curBak -Leaf))
        Note '   历史 bak 攒多了挪统一历史仓 F:\WorkStation\ysk_work\history\ 归档, 别手删'
    } else {
        Note '=================== 未就绪且自动装回也未救活 -- 查 ysk_serve_console.log, 人工定夺 ==================='
    }
}

# ---- [u>4] Strata V100(sm_70) speed switches (per official docs/NVIDIA_V100.md measured table; 2026-11-12)
function StrataV100Tuning {
    $CFG = 'E:\DSDeployMaster\Strata\strata-iq3_s.json'
    $SAFE = [ordered]@{
        'STRATA_SM70_TABLE'       = '三个 sm_70 解码内核 (逐位一致; 官方 SXM2 实测 verify 窗口 GPU 22.8->21.2ms)'
        'STRATA_ARGMAX_ROWS_SM70' = '多块贪心选择 (逐位一致; 解码 +0.7~0.8%)'
        'STRATA_GR_NORM_FAST'     = '寄存器分裂超连接归一 (逐位一致; +0.5~0.6%)'
        'STRATA_FUSE_DECODE'      = '解码 GEMV/MoE 融合 (逐位一致; 每词元省 4-16us)'
    }
    $TUNE = [ordered]@{
        'STRATA_PF_WMMA'          = 'FP16 张量核 prompt 专家 (prompt +10%, 但激活转 FP16, 答案会有差异)'
        'STRATA_GDN_REC_WARP'     = 'DeltaNet 递归链分裂 (prompt +6~9%, FP32 求和顺序变, 答案会有差异)'
    }
    Note '=================== Strata V100 提速开关 (写 strata-iq3_s.json 的 env) ==================='
    Note '   引擎侧开关只在 serve 启动时读 -- 改完要走 [u>8] 重启 8080 才生效 (一级[1] 见 8080 活着会直接复用, 不重载)'
    if (-not (Test-Path $CFG)) { Note ('!! 配置不在位: ' + $CFG); return }
    $j = $null
    try { $j = Get-Content $CFG -Raw | ConvertFrom-Json } catch { Note '!! 配置 JSON 读不出 -- 中止'; return }
    if (-not $j.env) { $j | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{}) }
    $all = @(); foreach ($k in $SAFE.Keys) { $all += $k }; foreach ($k in $TUNE.Keys) { $all += $k }
    $cur = @($j.env.PSObject.Properties | ForEach-Object { $_.Name + '=' + $_.Value })
    Note ('   现行 env: ' + ($cur -join '   '))
    Note '   ---- 无损组 (逐位一致, 推荐先开这组) ----'
    foreach ($k in $SAFE.Keys) {
        $st = if ($j.env.PSObject.Properties.Name -contains $k) { '已开' } else { '未开' }
        Note ('     ' + $k + ' [' + $st + ']  ' + $SAFE[$k])
    }
    Note '   ---- 提速组 (更快, 但答案会有差异) ----'
    foreach ($k in $TUNE.Keys) {
        $st = if ($j.env.PSObject.Properties.Name -contains $k) { '已开' } else { '未开' }
        Note ('     ' + $k + ' [' + $st + ']  ' + $TUNE[$k])
    }
    $ans = Ask '   [1] 开无损组   [2] 无损组+提速组全开   [3] 全部关掉   (q=取消)'
    $ac = "$ans".Trim()
    if ($ac.ToLower() -eq 'q' -or $ac -eq '') { Note '   已取消'; return }
    if ($ac -notin @('1','2','3')) { Note '!! 不是 1/2/3 -- 取消'; return }
    $on = @(); $off = @()
    if ($ac -eq '1') { $on = @($SAFE.Keys); $off = @($TUNE.Keys) }
    elseif ($ac -eq '2') { $on = @($all) }
    else { $off = @($all) }
    foreach ($k in $on)  { Set-JsonEnvKey $j.env $k 1 }
    foreach ($k in $off) { if ($j.env.PSObject.Properties.Name -contains $k) { $j.env.PSObject.Properties.Remove($k) | Out-Null } }
    $bak = $CFG + '.bak_' + (Get-Date -Format 'yyMMdd_HHmm') + '_v100tune'
    Copy-Item $CFG $bak -Force
    try {
        [IO.File]::WriteAllText($CFG, ($j | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
    } catch { Note ('!! 写入失败, 原样未动 (备份名 ' + (Split-Path $bak -Leaf) + ')'); return }
    $now = @($j.env.PSObject.Properties | ForEach-Object { $_.Name + '=' + $_.Value })
    Note ('   已写入 (备份 ' + (Split-Path $bak -Leaf) + ')  新 env: ' + ($now -join '   '))
    Note '   生效: 走 [u>8] 重启 Strata 8080 (重载判据=health 的 max_context/env 对账); 没重启前在跑引擎照旧, 随时可用 [3] 退回'
    Write-EngineReceipt -what 'v100_tuning' -data @{ kind='v100_tuning'; choice=$ac; switched_on=($on -join ',')
        switched_off=($off -join ','); env_now=($now -join ','); config_backup=(Split-Path $bak -Leaf) } | Out-Null
}

# ---- [u>8] restart the live Strata 8080 in place (added by the 261120 audit). strata-iq3_s.json
#      args/env edits (u>4 switches, context-size changes) only load at serve startup, and main-menu
#      [1] deliberately REUSES a live 8080 -- so "re-switch" was never a restart. 261120 proven trap:
#      schtasks /End alone leaves the serve python orphaned, and it respawns the engine with the OLD
#      in-memory args (json edit silently ignored). Correct chain = stop guard + KillGuard +
#      KillStrata, wait until procs AND 8080 are really dead, relaunch, verify max_context.
function RestartStrataService {
    $S_DIR = 'E:\DSDeployMaster\Strata'
    Note '=================== Strata 8080 原地重启 (重载 serve 配置) ==================='
    Note '   断线提示: 引擎冷加载 262K 约100s / 512K 实测约9分钟, 期间 8080 拒连属预期'
    $busy = (PortPid 8080) -or @(Get-Process -Name 'strata','strata-vision' -ErrorAction SilentlyContinue)
    if (-not $busy) { Note '   当前没有 Strata 实例在跑 -- 直接走一级 [1] 拉起即可'; return }
    TaskStop $TASK_S
    KillGuard 'ysk_serve_strata|ysk_task_strata'
    KillStrata
    # wait for the real death of BOTH engine procs and the 8080 listener: corpses drain 1-3 min
    #   (2026-10-22 handoff lesson) and a lingering listener masks whether the new args landed
    $dead = $false
    for ($i = 0; $i -lt 36; $i++) {
        Start-Sleep -Seconds 5
        if (-not @(Get-Process -Name 'strata','strata-vision' -ErrorAction SilentlyContinue) -and -not (PortPid 8080)) { $dead = $true; break }
    }
    if (-not $dead) { Note '   !! 180 秒未断气 -- 不强拉 (防双实例抢显存); 再按一次 u>8 或走 m>3 清干净'; return }
    Note '   旧实例已断气, 重挂守护 (serve 将按磁盘上的最新 json 参数加载)'
    TaskRun $TASK_S
    $ok = Wait-StrataHealth -rounds 60
    $mx = ''
    try { $mx = ((& curl.exe -s --noproxy '*' --max-time 5 http://127.0.0.1:8080/health) | ConvertFrom-Json).max_context } catch { }
    Write-EngineReceipt -what 'strata_service_restart' -data @{ kind='strata_service_restart'; health=$(if ($ok) { 'ok' } else { 'not_ready_15min' }); max_context=$mx; config='strata-iq3_s.json' } | Out-Null
    if ($ok) {
        Note ('=================== 重启完成: 8080 healthy, max_context=' + $mx + ' ===================')
        Note '   max_context 与 json 期望一致 = 配置确已重载 (261120 判症三件套之首)'
    } else {
        Note '=================== 15 分钟未就绪 -- 查 ysk_serve_console.log / strata-iq3_s.log ==========='
        Note '   多为 json 参数被现役 exe 拒 (exit 2); json 旁有 u>4 的 bak, 可手退换回后再 u>8'
    }
}

# ---- [u>1] Strata engine upgrade: rank git mirrors -> fetch -> checkout tag -> generic build (0216 layout V100 recipe template)
#      -> evict KVMem/ComfyUI -> swap exe -> guard relaunch -> health polling (+ auto-rollback kit).
#      NEVER auto-switch provider at the end (10-26 iron rule).
function StrataUpgrade {
    param([switch]$Auto)
    $S_DIR = "E:\DSDeployMaster\Strata"
    $official = "https://github.com/Niko1221/Strata.git"
    $CLOG = "$S_DIR\ysk_console_upgrade.log"
    KillProxyResidue
    Note "=================== Strata 镜像升级 (git 镜像测速择优) ==================="
    Note "提醒: 编译 engine 约5分钟 + vision 约8分钟 (10-26 实测), swap 短停 Strata 约2分钟;"
    Note "      会话若在 Strata 上跑, swap 后当前对话会短断属预期 (编译期间 Strata 照常服务)。"
    Note "      脱网关进程树全自动: pwsh -File 本文件 -StrataDirect"
    $verNow = (& git -C $S_DIR describe --tags 2>&1) | Select-Object -First 1
    $runVer = StrataEngineVer -dir $S_DIR
    Note ("   在役引擎 (exe --version 实测): " + $runVer)
    Note ("   仓库代码 (git describe): " + $verNow)
    $codeEng = StrataTagEngineVer -tag (("$verNow" -split '-')[0]) -dir $S_DIR
    if ($codeEng -and ($codeEng -ne $runVer)) {
        Note ("   代码对应的引擎版本是 " + $codeEng + ", 在役 exe 只有 " + $runVer + " -- 代码新于引擎, 重编即可补上")
    }
    Note "--- 测速选 git 镜像 (并行探测, 排名落盘 ysk_upgrade_mirror.log) ---"
    $S_SSH = "git@github.com:Niko1221/Strata.git"   # 261112 final: SSH tunnel fallback (~/.ssh/config ssh.github.com:443); the only survivor when GFW kills https
    $best = Show-MirrorRanking2 -GitRepo "Niko1221/Strata.git"
    if (-not $best.git) { Note "!! git 通道全灭 -- SSH隧道兜底, 再试官方直连"; $ranked = @($S_SSH, $official) }
    else { $ranked = @($best.gitRanked); if ($ranked -notcontains $official) { $ranked += $official }; $ranked += $S_SSH }
    # fetch: try ranked mirrors until the new tag appears (gitclone-style caches can lag; on miss go next)
    $newest = $null
    try {
        foreach ($u in $ranked) {
            $nm = @(($UPGIT_TPL | ForEach-Object { , @($_[0], ($_[1] -f "Niko1221/Strata.git")) }) | Where-Object { $_[1] -eq $u })[0][0]
            if ($u -eq $S_SSH) { $nm = "ssh-443" }
            Note ("   fetch via " + $(if ($nm) { $nm } else { "official" }))
            git -C $S_DIR remote set-url origin $u 2>&1 | Out-Null
            & git -C $S_DIR fetch --tags origin 2>&1 | Select-Object -Last 2 | ForEach-Object { Note ("   " + $_) }
            # criterion redesigned 261112: do NOT compare git describe (on main it always says 'already latest');
            # compare 'engine version of that tag' vs 'live exe --version'
            $cand = (& git -C $S_DIR tag --sort=-v:refname 2>&1 | Select-Object -First 1)
            if (-not $cand) { continue }
            $candEng = StrataTagEngineVer -tag "$cand" -dir $S_DIR
            if ($candEng) {
                if ((VerKey $candEng) -gt (VerKey $runVer)) { $newest = $cand; break }
                Note ("   " + $cand + " 的引擎版本 " + $candEng + " 不比在役 " + $runVer + " 新 -- 换下一个通道再找")
            } elseif ($verNow -notlike "$cand*") { $newest = $cand; break }
        }
    } finally {
        git -C $S_DIR remote set-url origin $S_SSH 2>&1 | Out-Null
        Note "   origin 已定版 SSH 隧道 (git@github.com -> ssh.github.com:443, GFW免疫)"
    }
    if (-not $newest) {
        Note "=================== 各通道都没找到「引擎版本高于在役 exe」的 tag ==================="
        Note ("   在役 exe " + $runVer + " | 仓库代码 " + $verNow + " | 网络若是全灭, 换个时段(夜里)再跑")
        $man = Ask "   手动输入 tag 照样编译安装 (回车=取消)"
        if ("$man".Trim() -eq '') { Note "   已取消"; return }
        $newest = "$man".Trim()
    }
    $tgtEng = StrataTagEngineVer -tag $newest -dir $S_DIR
    Note ("   目标 tag: " + $newest + "  (其引擎版本 " + $(if ($tgtEng) { $tgtEng } else { '读不出' }) + " | 在役 exe " + $runVer + ")")
    $sel = $newest
    if (-not $Auto) {
        $ans = Ask "   回车升级至 $newest, 或输入指定 tag, q=取消"
        if ("$ans".Trim().ToLower() -eq 'q') { Note "   已取消"; return }
        if ("$ans".Trim() -ne "") { $sel = "$ans".Trim() }
    }
    $freeE = (Get-PSDrive E -ErrorAction SilentlyContinue).Free
    if ($freeE) {
        $fg = [math]::Round($freeE / 1GB, 1)
        if ($freeE / 1GB -lt 6) { Note ("!! E 盘只剩 " + $fg + " GB (<6G), engine+vision 两个 build 目录放不下 -- 先清盘再升"); return }
        Note ("   E 盘余量 " + $fg + " GB (编译要两个 build 目录)")
    }
    Note ("--- checkout " + $sel + " (untracked 构建bat/配置/显存守护不动) ---")
    $headBefore = ("$(git -C $S_DIR rev-parse HEAD 2>&1 | Select-Object -First 1)").Trim()
    & git -C $S_DIR checkout -f $sel 2>&1 | Select-Object -Last 2 | ForEach-Object { Note ("   " + $_) }
    if ($LASTEXITCODE -ne 0) { Note "!! checkout 失败 -- 中止"; return }
    # 261120 layout-cutover lesson: the live serve bat (since the 0.2.16 cutover) does 'cd terminal'
    #   + terminal\.venv\Scripts\python.exe. Tags before 0.2.16 have no terminal\serve\server.py, so
    #   a cross-layout checkout would burn ~13 build minutes and then leave 8080 unrestarable, AND
    #   strip the guardian chain's revival ability. Abort BEFORE compiling and restore the previous
    #   code position so the guardian keeps working exactly as it was.
    if (-not (Test-Path "$S_DIR\terminal\serve\server.py")) {
        Note "!! 目标 tag 早于 0.2.16 (旧顶层布局) -- 在役守护 bat 按新布局写死, u>1 不跨布局换代, 已中止"
        if ($headBefore) {
            git -C $S_DIR checkout -f $headBefore 2>&1 | Out-Null
            if (Test-Path "$S_DIR\terminal\serve\server.py") { Note ("   代码已退回升级前位置 " + $headBefore.Substring(0, [Math]::Min(10, $headBefore.Length)) + " (守护链复活能力已恢复)") }
            else { Note "   !! 退回后 terminal\serve 仍不在位 -- 需人工核查" }
        }
        return
    }
    # build: prefer the repo's existing build-<slug>-ysk.bat; else template from build-v0216-ysk.bat
    # (measured V100 recipe in the 0.2.16 NEW layout: engine lives in engine\, vision in terminal\tools\vision),
    #   only swap -B dir. Old top-level-layout templates were retired at the 261120 cutover.
    # 261120 lesson #2: the venv moved into terminal\ at that cutover, and pip's cmake console-shim
    #   in Scripts\ still carries the OLD absolute python path -- it now dies with rc=1 and ZERO
    #   output (the failed [u>1] 'path not found' burn). Always normalize bat tool paths to the
    #   probed runnable ones: real cmake under site-packages\cmake\data\bin, ninja is a plain
    #   binary in Scripts (survives relocation), and probe both venv locations.
    $venvScr = if (Test-Path "$S_DIR\terminal\.venv\Scripts\ninja.exe") { "$S_DIR\terminal\.venv\Scripts" } else { "$S_DIR\.venv\Scripts" }
    $cmkReal = (Split-Path $venvScr -Parent) + "\Lib\site-packages\cmake\data\bin\cmake.exe"
    if (-not (Test-Path $cmkReal)) { $cmkReal = "$venvScr\cmake.exe" }
    function Normalize-BuildBat([string]$path) {
        # rewrite every cmake.exe / CMAKE_MAKE_PROGRAM ninja.exe absolute path to the probed live tools
        $t = [IO.File]::ReadAllText($path, [Text.Encoding]::GetEncoding(28591))
        $t2 = $t -replace '[A-Za-z]:\\[^\s"]*?\\cmake\.exe', $cmkReal
        $t2 = $t2 -replace '(-DCMAKE_MAKE_PROGRAM=)[A-Za-z]:\\[^\s"]*?\\ninja\.exe', ('$1' + "$venvScr\ninja.exe")
        if ($t2 -ne $t) { [IO.File]::WriteAllText($path, $t2, [Text.Encoding]::GetEncoding(28591)); Note "   已校正构建配方工具路径 (cmake=$cmkReal)" }
    }
    $slug = $sel -replace '[^0-9A-Za-z]', ''
    $bEng = "build-" + $slug; $bVis = "build-vision-" + $slug
    $tplEng = "$S_DIR\build-v0216-ysk.bat"; $tplVis = "$S_DIR\build-vision-v0216-ysk.bat"
    $raw = ""
    if (Test-Path "$S_DIR\build-$slug-ysk.bat") { $engBat = "$S_DIR\build-$slug-ysk.bat" }
    elseif (Test-Path $tplEng) {
        $engBat = "$S_DIR\build-$slug-ysk.bat"
        $raw = [IO.File]::ReadAllText($tplEng, [Text.Encoding]::GetEncoding(28591))
        [IO.File]::WriteAllText($engBat, ($raw -replace 'build-v0216', $bEng), [Text.Encoding]::GetEncoding(28591))
        Note "   已按 0216 新布局 V100 配方生成 $bEng-ysk.bat"
    } else { Note "!! 无构建配方模板 (build-v0216-ysk.bat 不在位) -- 手动处理"; return }
    if (Test-Path "$S_DIR\build-vision-$slug-ysk.bat") { $visBat = "$S_DIR\build-vision-$slug-ysk.bat" }
    elseif (Test-Path $tplVis) {
        $visBat = "$S_DIR\build-vision-$slug-ysk.bat"
        $raw = [IO.File]::ReadAllText($tplVis, [Text.Encoding]::GetEncoding(28591))
        [IO.File]::WriteAllText($visBat, ($raw -replace 'build-vision-v0216', $bVis), [Text.Encoding]::GetEncoding(28591))
        Note "   已生成 build-vision-$slug-ysk.bat"
    } else { $visBat = $null }
    Normalize-BuildBat $engBat
    if ($visBat) { Normalize-BuildBat $visBat }
    # ggml source check (261112 fix: $raw only had a value in the 'generate bat from template' branch,
    #   staying empty when a repo bat already exists -> always fell back to the 3cf03257 old tree; but since
    #   0.2.13 the official repo vendors ggml under third_party\strata-ggml -- forcing the old pin tree compiles a new engine against old ggml)
    try { $raw = [IO.File]::ReadAllText($engBat, [Text.Encoding]::GetEncoding(28591)) } catch { $raw = "" }
    # 0.2.16 new layout vendors ggml under engine\third_party\strata-ggml; pre-0.2.16 tags used the top level.
    $vendored = (Test-Path "$S_DIR\engine\third_party\strata-ggml") -or (Test-Path "$S_DIR\third_party\strata-ggml")
    if ($vendored) {
        $raw2 = ($raw -replace '-DSTRATA_GGML_DIR=("[^"]*"|[^\s"]+)', '') -replace '  +', ' '
        if ($raw2 -ne $raw) {
            [IO.File]::WriteAllText($engBat, $raw2, [Text.Encoding]::GetEncoding(28591))
            Note "   ggml 已 vendored (engine\third_party\strata-ggml 或顶层) -> 已从配方剔除 -DSTRATA_GGML_DIR, 不拿旧 pin 树编新引擎"
        } else { Note "   ggml 已 vendored (engine\third_party\strata-ggml 或顶层) -- 直接用仓库自带源码" }
        $ggml = ""
    } else {
        $ggml = [regex]::Match($raw, '-DSTRATA_GGML_DIR=(\S+)').Groups[1].Value
        if (-not $ggml) { $ggml = "E:\\DSDeployMaster\\Strata\\third_party\\llama.cpp-3cf03257f219afbe7334045ff7c6a06ac68c627d" }
        if (-not (Test-Path $ggml)) { Note ("!! ggml pinned 树不在位: " + $ggml + " -- 中止 (别装, 编译会联网拉或报缺)"); return }
    }
    Note ("--- 编译 engine (" + $bEng + ", 约5分钟, 日志 " + $CLOG + ") ---")
    & cmd /c "`"$engBat`" >> `"$CLOG`" 2>&1"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$S_DIR\$bEng\strata.exe")) { Note "!! engine 编译失败 -- 看 $CLOG; 中止 (Strata 未受打扰)"; return }
    Note "   engine OK"
    if ($visBat) {
        Note ("--- 编译 vision (" + $bVis + ", 约8分钟) ---")
        & cmd /c "`"$visBat`" >> `"$CLOG`" 2>&1"
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$S_DIR\$bVis\bin\strata-vision.exe")) { Note "!! vision 编译失败 -- 看 $CLOG; 中止"; return }
        Note "   vision OK"
    }
    Note "--- swap: 请走 KVMem/ComfyUI, 腾双卡 (Strata 双卡独占) ---"
    if (PortPid 8188) { KillService "ComfyUI" 8188 | Out-Null }
    if (PortPid 18200) { TaskStop $TASK_K; KillService "KVMem快通道 18200" 18200 | Out-Null }
    TaskStop $TASK_S
    KillGuard 'serve_strata|task_strata'
    KillStrata
    Start-Sleep -Seconds 12
    # backup name uses the exe-measured version (261112 fix: it used to read BUILD.json, and once that
    #   drifted, 0.1.58 got stored as strata-0.1.56.bak.exe, overwriting the true 0.1.56 backup and lying to the rollback chain)
    $oldV = $runVer
    if ($oldV -notmatch '^\d') { $oldV = "unknown-" + (Get-Date -Format 'yyMMdd_HHmm') }
    Note ("   备份旧引擎 (版本 " + $oldV + ") 并装新 exe (撞锁自动重试30轮)")
    if (-not (CopyWithRetry "$S_DIR\engine\strata.exe" "$S_DIR\engine\strata-$oldV.bak.exe" 30)) { Note "!! 备份旧 strata.exe 失败 (锁未释放?) -- 中止, 守护未开"; return }
    if (-not (CopyWithRetry "$S_DIR\$bEng\strata.exe" "$S_DIR\engine\strata.exe" 30)) { Note "!! 安装新 strata.exe 失败 -- 中止"; return }
    if ($visBat) {
        CopyWithRetry "$S_DIR\engine\strata-vision.exe" "$S_DIR\engine\strata-vision-$oldV.bak.exe" 10 | Out-Null
        if (-not (CopyWithRetry "$S_DIR\$bVis\bin\strata-vision.exe" "$S_DIR\engine\strata-vision.exe" 30)) { Note "!! 安装新 vision 失败 (引擎已换, 继续)"; }
    }
    $newExeVer = StrataEngineVer -dir $S_DIR
    if (Test-Path "$S_DIR\$bEng\BUILD.json") { Copy-Item "$S_DIR\$bEng\BUILD.json" "$S_DIR\engine\BUILD.json" -Force }
    else { Note "   (新 build 无 BUILD.json 元数据 -> 按 exe 实测版本自己写一份)" }
    if ($newExeVer -match '^\d') {
        $bjNow = ''
        try { $bjNow = (Get-Content "$S_DIR\engine\BUILD.json" -Raw | ConvertFrom-Json).version } catch { }
        if ($bjNow -ne $newExeVer) {
            Write-StrataBuildJson -version $newExeVer -src ("$sel + ggml " + $(if ($vendored) { 'vendored(仓库自带)' } else { $ggml })) -recipe ("$bEng-ysk.bat + " + $bVis + "-ysk.bat") -note "console [u>1] 升级; version 以 exe --version 实测为准"
        } else { Note ("   engine\BUILD.json 登记与 exe 实测一致: " + $newExeVer) }
    } else { Note "   !! 读不出新 exe 版本, engine\BUILD.json 保持原样" }
    Note "--- 重挂守护并拉起, health 轮询最多 12 分钟 ---"
    # TaskRun, not bare /ENABLE+/Run: zombie-state /End retry (11-13) + ACL-safe enable (11-17)
    TaskRun $TASK_S
    $ok = Wait-StrataHealth
    # auto-rollback = defense #3 of the 261112 triple-guard; the helper existed but its CALL SITE was
    #   lost (261120 audit) -- a failed health wait used to leave 8080 dead until a human reinstalled
    #   the bak. Re-welded: put the just-swapped-out old exe back automatically and record it.
    if (-not $ok) {
        $bakE = "$S_DIR\engine\strata-$oldV.bak.exe"
        $bakV = "$S_DIR\engine\strata-vision-$oldV.bak.exe"
        if (Test-Path $bakE) {
            $triedVer = $newExeVer
            $ok = Restore-StrataEngineFromBak -bakExe $bakE -bakVis $(if (Test-Path $bakV) { $bakV } else { '' }) -label ("u>1 升级后未就绪 -- 自动装回 " + $oldV)
            $newExeVer = StrataEngineVer -dir $S_DIR
            Write-EngineReceipt -what 'strata_auto_rollback' -data @{ kind='strata_auto_rollback'; upgrade_tag=$sel; tried_ver=$triedVer; back_to=$oldV; health=$(if ($ok) { 'ok' } else { 'not_ready' }) } | Out-Null
        }
    }
    $sha = ''
    try { $sha = (Get-FileHash -Algorithm SHA256 "$S_DIR\engine\strata.exe").Hash.ToLower() } catch { }
    Write-EngineReceipt -what 'strata_upgrade' -data @{ kind='strata_upgrade'; tag=$sel; engine_before=$oldV; engine_after=$newExeVer
        code=(StrataRepoVer -dir $S_DIR); recipe=("$bEng-ysk.bat + " + $bVis + "-ysk.bat")
        ggml=$(if ($vendored) { 'vendored' } else { $ggml }); health=$(if ($ok) { 'ok' } else { 'not_ready_12min' })
        exe_sha256=$sha; rollback_backup=("engine\strata-$oldV.bak.exe"); build_log=$CLOG } | Out-Null
    if ($ok) {
        $newVer = (& git -C $S_DIR describe --tags 2>&1) | Select-Object -First 1
        Note ("=================== STRATA 升级完成: exe " + $newExeVer + " (代码 " + $newVer + ", 8080 healthy) ===================")
        Note "   按 10-26 铁律: 收尾不自动切 provider -- 请主人关 Hermes 后用一级 [1] 切 Strata"
        Note ("   回退物: engine\strata-$oldV.bak.exe / strata-vision-$oldV.bak.exe (也可走 [u>2] 回滚)")
    } else {
        Note "=================== 未就绪且自动回退也未救活 -- 查 ysk_serve_console.log; 手动走 [u>2] ==================="
    }
}

# ---- [u>3] KVMem upgrade: api release check -> rank download lanes -> resumable download -> sha256 verify
#      -> extract flattened into engines\kvmem-v<new>-unified (old engine kept intact for rollback) -> serve bat cd line swap.
function KvmemUpgrade {
    param([switch]$Auto)
    $ENGINES = "E:\DSDeployMaster\engines"; $DL_DIR = "$ENGINES\kvmem_dl"
    $SERVE   = "E:\DSDeployMaster\ysk_autostart\ysk_serve_kvmem.bat"
    KillProxyResidue
    Note "=================== KVMem 引擎升级 (release 下载通道测速择优) ==================="
    Note "提醒: release 约1.1GB, 实测好通道 2~4MB/s 要 5~10 分钟; 脱网关进程树: pwsh -File 本文件 -KvmemDirect"
    $j = (& curl.exe -s --noproxy '*' --max-time 25 "https://api.github.com/repos/kvmem/kvmem/releases/latest") | ConvertFrom-Json
    if (-not $j.tag_name) { Note "!! 取不到 release 信息 (api 不通?) -- 中止"; return }
    $newTag = $j.tag_name
    $asset = @($j.assets | Where-Object { $_.name -like "*windows-x64-nvidia-v100-unified.zip" }) | Select-Object -First 1
    if (-not $asset) { Note "!! 该 release 没有 v100-unified 包 -- 中止"; return }
    $curV = "未知"; $curVer = "none"
    if (Test-Path $SERVE) {
        $sc = [IO.File]::ReadAllText($SERVE, [Text.Encoding]::GetEncoding(28591))
        $m = [regex]::Match($sc, 'kvmem-v([0-9.]+)-unified')
        if ($m.Success) { $curVer = "v" + $m.Groups[1].Value; $curV = $curVer }
    }
    Note ("   现役引擎: " + $curV + " | 最新 release: " + $newTag + " | 包 " + [math]::Round($asset.size/1MB) + "MB")
    if ($curVer -eq $newTag) { Note "=================== 已是最新, 无需升级 ==================="; return }
    if (-not $Auto) {
        $ans = Ask "   回车确认升级到 $newTag, q=取消"
        if ("$ans".Trim().ToLower() -eq 'q') { Note "   已取消"; return }
    }
    Note "--- 测速选下载通道 (release range 采样, 排名落盘 ysk_upgrade_mirror.log) ---"
    $best = Show-MirrorRanking2 -DlUrl $asset.browser_download_url
    if (-not $best.dl) { Note "!! 下载通道全灭 -- 退回直连试 (可能被掐, 失败可重跑续传)"; $prefix = "" } else { $prefix = $best.dl }
    $dn = @($UPDL_TPL | Where-Object { $_[1] -eq $prefix })[0][0]; if (-not $dn) { $dn = "direct-github" }
    Note ("   下载通道择优: " + $dn)
    if (-not (Test-Path $DL_DIR)) { New-Item -ItemType Directory -Path $DL_DIR -Force | Out-Null }
    # probe real 8MB throughput before committing (261112: lane ranking only samples 512KB ranges, which
    #   may not represent big-file endpoints like objects.githubusercontent; measure first, else hang an hour and fail)
    $tp = "$DL_DIR\.probe-" + (Get-Date -Format 'HHmmss') + ".part"
    $t0 = Get-Date
    & curl.exe -s --noproxy '*' -L -r 0-8388607 -o $tp ($prefix + $asset.browser_download_url) 2>&1 | Out-Null
    $pbs = (Get-Item $tp -ErrorAction SilentlyContinue).Length
    if (Test-Path $tp) { Remove-Item -Force $tp }
    $ps = [math]::Max(((Get-Date) - $t0).TotalSeconds, 0.5)
    if ($pbs -gt 1MB) {
        $mbps = [math]::Round($pbs / 1MB / $ps, 2)
        $eta = [math]::Round(($asset.size / 1MB) / [math]::Max($mbps, 0.01) / 60, 1)
        Note ("   预检吞吐 " + $mbps + " MB/s (实拉 " + [math]::Round($pbs / 1MB, 1) + "MB) -> 全包预估 " + $eta + " 分钟")
        if ($mbps -lt 0.5) {
            Note "   !! 这条道太慢 (GFW 检测期白天常见) -- 夜里 22:30 后实测最好; 本机会话赶时间的话建议取消改时段"
            if (-not $Auto) {
                $go = Ask "   照此速度继续下载? (回车=继续, q=取消)"
                if ("$go".Trim().ToLower() -eq 'q') { Note "   已取消 (zip 未落盘, 不占地方)"; return }
            }
        }
    } else { Note "   预检没拉到东西 (通道可能拒 range 请求) -- 直接开下, 失败可重跑续传" }
    # fetch sha256 + validation small files first (same lane)
    foreach ($sfx in @(".sha256", ".validation.json")) {
        $out = Join-Path $DL_DIR ($asset.name + $sfx)
        & curl.exe -sL --noproxy '*' --max-time 60 -o $out ($prefix + $asset.browser_download_url + $sfx)
    }
    $zip = Join-Path $DL_DIR $asset.name
    Note ("--- 下载 " + $asset.name + " (单连接断点续传, 大文件勿开多线程分段) ---")
    $t0 = Get-Date
    & curl.exe -s --noproxy '*' -L -C - --retry 6 --retry-delay 8 --max-time 5400 -o $zip ($prefix + $asset.browser_download_url)
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    if (-not (Test-Path $zip)) { Note "!! 下载失败 -- 重跑本功能会断点续传"; return }
    $local = [math]::Round((Get-Item $zip).Length/1MB)
    if ((Get-Item $zip).Length -lt $asset.size) { Note ("!! 下载不完整 (" + $local + "/" + [math]::Round($asset.size/1MB) + "MB) -- 重跑续传"); return }
    Note ("   下载完成 " + $local + "MB, 用时 " + $mins + " 分钟")
    # sha256 verify
    $exp = (Get-Content ($zip + ".sha256") -Raw).Trim() -split '\s+' | Select-Object -First 1
    $got = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
    if ($exp -and ($exp.ToLower() -ne $got)) { Note ("!! SHA256 不对账! 期望 " + $exp + " 实得 " + $got + " -- zip 保留, 请人工核对"); return }
    Note ("   SHA256 对账 MATCH (" + $got.Substring(0, 12) + "...)")
    # extract + flatten
    $tmp = "$ENGINES\.kvmem-unpack-" + $newTag
    $dstDir = "$ENGINES\kvmem-" + $newTag + "-unified"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    if (Test-Path $dstDir) { Remove-Item -Recurse -Force $dstDir }   # on rerun clear the incomplete new dir (the live old engine is never touched)
    # 261120 audit: Move-Item with a wildcard into a MISSING directory renames the first item instead
    #   of merging -- pre-create the target so the flatten branch behaves the same in both layouts.
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    & "C:\Program Files\7-Zip\7z.exe" x -y "-o$tmp" $zip | Select-Object -Last 2 | ForEach-Object { Note ("   " + $_) }
    if ($LASTEXITCODE -ne 0) { Note "!! 7z 解压失败 -- 中止"; return }
    $top = @(Get-ChildItem $tmp)
    $flat = $tmp
    if ($top.Count -eq 1 -and $top[0].PSIsContainer) {
        $inner = $top[0].FullName
        if (@(Get-ChildItem $inner -Filter *.exe | Select-Object -First 1).Count) { $flat = $inner }
        elseif (@(Get-ChildItem $inner -Directory | Select-Object -First 1).Count) {
            $top2 = @(Get-ChildItem $inner)
            if ($top2.Count -eq 1 -and $top2[0].PSIsContainer -and @(Get-ChildItem $top2[0].FullName -Filter *.exe).Count) { $flat = $top2[0].FullName }
        }
    }
    if ($flat -ne $tmp) { Move-Item -Path (Join-Path $flat '*') -Destination $dstDir -Force; Remove-Item -Recurse -Force $tmp }
    else { Move-Item $tmp $dstDir }
    if (-not @(Get-ChildItem $dstDir -Filter "ninfer-kvmem-server.exe").Count) { Note ("!! 落位后没找到 ninfer-kvmem-server.exe -- 结构反常, 人工看 " + $dstDir); return }
    # swap the cd line in the serve bat (GBK bytes kept lossless, backup taken first)
    if (Test-Path $SERVE) {
        $sc = [IO.File]::ReadAllText($SERVE, [Text.Encoding]::GetEncoding(28591))
        $bak = $SERVE + ".bak_" + (Get-Date -Format "yyMMdd_HHmm") + "_kvmemupg"
        [IO.File]::WriteAllText($bak, $sc, [Text.Encoding]::GetEncoding(28591))
        $sc2 = $sc -replace ('kvmem-v[0-9.]+-unified'), ("kvmem-" + $newTag + "-unified")
        [IO.File]::WriteAllText($SERVE, $sc2, [Text.Encoding]::GetEncoding(28591))
        $chk = [regex]::Match($sc2, 'cd /d .*').Value
        Note ("   serve bat cd 行已换 (备份 " + (Split-Path $bak -Leaf) + "): " + $chk)
    } else { Note ("!! serve bat 不在位: " + $SERVE + " -- 手动换 cd 行") }
    Write-EngineReceipt -what 'kvmem_upgrade' -data @{ kind='kvmem_upgrade'; tag=$newTag; engine_before=$curVer; engine_after=$newTag
        asset=$asset.name; size_mb=[math]::Round($asset.size / 1MB); sha256=$got; minutes=$mins; channel=$dn
        new_dir=$dstDir; serve_backup=(Split-Path $bak -Leaf) } | Out-Null
    Note "=================== KVMEM 升级落位完成 ==================="
    Note ("   新引擎: " + $dstDir + " | 旧引擎 " + $curV + " 原样留作回退")
    Note "   启用: 主人停 Strata 后经操作台一级 [2] 拉 KVMem; 真机冒烟由主人做 (官方未在 V100 实测推理)"
    Note ("   冒烟通过后: 旧引擎目录挪进统一历史仓 F:\WorkStation\ysk_work\history\engines\ 等归档, 别手删")
}

# [c>7] revive vision router 18207 (zero-VRAM CPU daemon; if it dies every scene goes vision-blind; [1]/[2] auto-start it, this is the manual fallback)
function ReviveVisionRouter {
    Note "=================== 视觉分流网关 18207 ==================="
    if (PortPid 18207) {
        $r = Http "GET" "http://127.0.0.1:18207/v1/models" $null 5
        Note ("   18207 已在线 OK (http=" + $r + ") -- 无需救护")
        return
    }
    $vbs = "E:\DSDeployMaster\ysk_autostart\ysk_task_vision_router.vbs"
    if (-not (Test-Path $vbs)) { Note ("   !! 缺启动 vbs: " + $vbs); return }
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
    Note "--- vbs 拉起 18207 (最多等3分钟) ---"
    $ok = $false
    for ($i=0; $i -lt 36; $i++) { Start-Sleep -Seconds 5; if (PortPid 18207) { $ok=$true; break } }
    if (-not $ok) {
        Note "!! 没起来 -- 查 ysk_autostart 里 vision_router 日志看死因, 再重试"
        return
    }
    TaskRun $TASK_R
    Note "--- 18207 已在线; 守护任务已启用 (常驻服务不会被腰斩) ---"
    Note "=================== 救护完成 ==================="
}

# [c>8] revive zero-VRAM trio (dispatcher 18202 / embed 18303 / rerank 18304, CPU-resident; dead = approval & memory recall blind)
function ReviveCpuTrio {
    Note "=================== 零显存三模型救护 ==================="
    $revived = @()
    if (-not (PortPid 18202)) { TaskRun $TASK_B;   $revived += "调度官@18202" }
    if (-not (PortPid 18303)) { TaskRun $TASK_VLE; $revived += "嵌入@18303" }
    if (-not (PortPid 18304)) { TaskRun $TASK_VLR; $revived += "重排@18304" }
    if ($revived.Count -eq 0) { Note "   三模型全在线, 无需救护 OK"; return }
    for ($i = 0; $i -lt 2; $i++) {
        Start-Sleep -Seconds 20
        if ((PortPid 18202) -and (PortPid 18303) -and (PortPid 18304)) { break }
    }
    $still = @()
    if (-not (PortPid 18202)) { $still += "调度官@18202" }
    if (-not (PortPid 18303)) { $still += "嵌入@18303" }
    if (-not (PortPid 18304)) { $still += "重排@18304" }
    Note ("   本次拉起: " + ($revived -join ', '))
    if ($still.Count -gt 0) { Note ("   !! 仍未在线: " + ($still -join ', ') + " -- 查对应 serve bat 日志") } else { Note "   三模型全部在线 OK" }
    Note "   (smart_dispatch 智能巡检 2026-10-27 主人定退休, 不自动复活; 要复活走计划任务提权 Enable)"
    Note "=================== 救护完成 ==================="
}

# [c>4] launch Blender (2026-10-26 master's call: 3D polish/animation, ComfyUI bridge ports 53119-53124)
function StartBlender {
    Note "=================== 起 Blender ==================="
    if (Get-Process -Name "blender" -ErrorAction SilentlyContinue) {
        Note "   Blender 已在跑 -- 复用 (多实例会抢桥接, 不重复起)"
        return
    }
    $vbs = "D:\ProgramFiles\ysk_tools\blender\启动Blender.vbs"
    if (-not (Test-Path $vbs)) { Note ("   !! 缺启动 vbs: " + $vbs); return }
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
    Note "   Blender 5.2.2 起飞 (本体D盘/用户配置D盘/缓存temp E盘, vbs 经启动Blender.bat 保证环境变量)"
    if (PortPid 8188) { Note "   ComfyUI 在线 -- Blender 里 ComfyUI 节点端可直接用 (桥接 53119~53124)" } else { Note "   ComfyUI 没在线 -- Blender 里要 AI 生成需c>1先起 GPU 版; Strata 占双卡期用c>3起 CPU 版" }
}

# [c>3] ComfyUI CPU mode (2026-10-26: usable even while Strata holds both cards -- ~1-2 min/image, bridge works, zero VRAM)
function StartComfyCpu {
    Note "=================== 起 ComfyUI-CPU 版 ==================="
    if (PortPid 8188) {
        $free0 = 0
        try { $free0 = [int](nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | Select-Object -First 1) } catch { }
        Note ("   ComfyUI 已在线 (8188, 当前GPU0空闲 " + [math]::Round($free0/1GB,1) + "GB) -- 复用, 不重复起")
        return
    }
    $vbs = "E:\DSDeployMaster\ysk_autostart\ysk_task_comfy_cpu.vbs"
    if (-not (Test-Path $vbs)) { Note ("   !! 缺: " + $vbs); return }
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
    Note "--- CPU 版起飞 (模型装载慢, 最多等8分钟; 日志 %TEMP%\comfyui_cpu.log) ---"
    $ok = $false
    for ($i=0; $i -lt 96; $i++) { Start-Sleep -Seconds 5; if (PortPid 8188) { $ok=$true; break } }
    if ($ok) {
        Note "   ComfyUI-CPU 就绪 OK -- Strata 占双卡期也能出图/视觉桥接"
        Note "   提醒: CPU 版很慢 (z-image 约1-2分钟/张), 轻量出图与桥接够用, 视频/3D 别跑"
    } else {
        Note "!! 8分钟未就绪 -- 查 %TEMP%\comfyui_cpu.log (GPU版 ComfyUI 守护被显存预检拒起属正常, Strata 在跑时就这样)"
    }
}

# ---------------------------------------------------------------------------
# two-level menu (2026-10-20 redesign: main = hot items + engine/VRAM status strip, sub[s] = rare maintenance;
#   every action returns to the menu, q exits; piping stdin auto-exits on EOF, old test harness still works)
# ---------------------------------------------------------------------------
# ===========================================================================
# menu (2026-11-12 grouped redesign final):
#   main = 4 hot keys + 4 group entries + [x] map; groups use their own 1..n numbering, q returns to main.
#   before: '9 main + 24 flat sub items' -- every addition lengthened one long screen and mis-clicks grew;
#   now grouped by intent, and each group header shows the status lines relevant to it (engine / VRAM / ports).
#   full numbering table: file header above + [x] (Show-MenuMap generated from the menu table, labels can never drift)
# ===========================================================================
function GpuMemLine {
    try {
        $rows = @(nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits 2>$null |
                  Where-Object { "$_".Trim() -match '^\s*\d+\s*,\s*\d+' })
        if ($rows.Count) {
            Write-Host ("    " + (($rows | ForEach-Object { $p = $_ -split ","; "GPU{0} 余{1}G" -f $p[0].Trim(), [math]::Round([int]$p[1].Trim() / 1024, 1) }) -join " | ")) -ForegroundColor DarkGray
        }
    } catch { }
}
function StatusLine {
    $sOn = [bool](PortPid 8080); $kOn = [bool](PortPid 18200)
    $eng = if ($sOn -and $kOn)   { '双引擎并行 (Strata主力+KVMem常驻备胎, 显存满座·GPU套件全互斥)' }
            elseif ($sOn)        { '仅 Strata (双卡常驻, GPU套件互斥)' }
            elseif ($kOn)        { '仅 KVMem (创作协同态, GPU0 整卡留给套件)' }
            else                 { '无引擎在役' }
    Write-Host ("    当前主力: {0}   引擎: {1}" -f (HermesMain), $eng) -ForegroundColor Cyan
    GpuMemLine
}
function CreateStatusLine {
    $p = ""
    # 261120 audit: this used to be 'foreach ($kv in [ordered]@{...})' -- in PS7 that binds the WHOLE
    #   dictionary to $kv (not the entries), so $kv.Value was null and PortPid threw a parameter-
    #   binding error every group entry: Show-Group's try swallowed it and the c-group header line
    #   silently vanished. Iterate .Keys like FullHealth does.
    $cSvcs = [ordered]@{ 'ComfyUI 8188' = 8188; 'whisper 9003' = 9003; '视觉网关 18207' = 18207;
                         'TeleOCR 18205' = 18205; '调度官 18202' = 18202; '嵌入 18303' = 18303; '重排 18304' = 18304 }
    foreach ($ck in $cSvcs.Keys) {
        $p += ("{0}:{1}  " -f $ck, $(if (PortPid $cSvcs[$ck]) { 'OK' } else { '--' }))
    }
    Write-Host ("    服务: " + $p) -ForegroundColor Cyan
    GpuMemLine
}
function SystemStatusLine {
    Write-Host ("    主力={0}   Strata 8080={1}   KVMem 18200={2}   VPN 10808={3}" -f (HermesMain),
                $(if (PortPid 8080) { '活' } else { '停' }), $(if (PortPid 18200) { '活' } else { '停' }),
                $(if (PortPid 10808) { '活' } else { '停' })) -ForegroundColor Cyan
}

# r = risk level for the GUI confirm dialog (danger | confirm | none); p = dialog spec
# (text:... | radio:v=label|... | bak = dynamic rollback list via -ListBak); w = impact line.
$MENU_B = [ordered]@{
    '1' = @{ t = '一键装配 + 启动 Strata (勾选=在岗上卡, 不勾全退; 守护集中一次UAC)'; r = 'confirm'; w = '按门槛顺序落座(GPU1大件->GPU0->零显存), ComfyUI勾选则本轮不拉Strata; 全部守护改动集中在最后一次提权处理(弹一次UAC, 提权助手跑完自退)'; a = { AssembleBlocks } }
    '2' = @{ t = '积木现状快照 (在岗/模式/守护 一览)';                                a = { Show-BlocksState } }
    'q' = @{ t = '返回一级' }
}
$MENU_M = [ordered]@{
    # display order = 装配优先度 (261120 master: most-likely-used first); keys/meaning unchanged
    'a' = @{ t = '缘狐声线 上 GPU (9210 实时朗读提速; 需GPU0空闲≥8G)';      r = 'confirm'; w = '走服务自带 /gpu/load, 首次加载约1~3分钟; 不启用计划任务守护; 空闲超时会自动卸回 CPU'; a = { ArmTtsGpu } }
    'b' = @{ t = '缘狐声线 下 GPU (让位显存, CPU端点仍常驻可读)';           a = { StanddownTtsGpu } }
    '9' = @{ t = '小米OCR 18201 载入 GPU0 (GPU版 4~5s/页, 需GPU0空闲≥2300MB)'; r = 'confirm'; w = '会短停 18201 约1分钟重起为 GPU 版; GPU0 空隙不足会被 bat 自动转 CPU 版'; a = { ArmOcrGpu } }
    '0' = @{ t = '小米OCR 18201 退出 (停守护+请走, 释放 GPU0 显存)';        r = 'confirm'; w = '退出后 OCR 只剩 18205 TeleOCR 或 VL 头兜底, 逐字转录精度会降'; a = { StanddownOcr } }
    '8' = @{ t = 'KVMem 常驻点火·不动 Strata (双引擎并行, 守护常开)';      r = 'confirm'; a = { ArmKvmemResident } }
    '4' = @{ t = 'KVMem 清洁退出 (只停 18200, 不动 Strata)';               r = 'confirm'; a = { CleanupKvmem } }
    'c' = @{ t = 'TeleOCR 18205 上岗 (GPU1, 需空闲≥2048MB; 3~5s/页)';      r = 'confirm'; w = 'vbs 直起 serve_teleocr.bat, 不启用计划任务守护; 18207 网关会自动优先用它'; a = { ArmTeleocrGpu } }
    'd' = @{ t = 'TeleOCR 18205 收回 (释放 GPU1)';                         r = 'confirm'; w = '先杀 serve 宿主防 30s 自愈回魂, 再请走实例'; a = { StanddownTeleocr } }
    '1' = @{ t = '创作工作站一键起 (KVMem+TeleOCR+ComfyUI@GPU0 全配套)';  r = 'confirm'; a = { CreativeWorkspace } }
    '2' = @{ t = '工作站拆除 (停 ComfyUI+18201+TeleOCR, 再 KVMem 退出)';   r = 'confirm'; a = { CleanupWorkspace } }
    '3' = @{ t = 'Strata 清洁退出 (停 8080 进程树与守护)';                 r = 'confirm'; a = { CleanupStrata } }
    '6' = @{ t = 'TeleCPU 应急拉起 (18205慢速应急, 主力仍是18201小米)';    a = { StartOcrCpu } }
    '7' = @{ t = 'TeleCPU 应急收回 (单独态勿按, 会误杀TeleGPU主力)';       r = 'confirm'; a = { StopOcrCpu } }
    '5' = @{ t = 'Ollama 卸载 (keep_alive=0 释放显存)';                    a = { FreeOllama } }
    'q' = @{ t = '返回一级' }
}
$MENU_U = [ordered]@{
    '1' = @{ t = 'Strata 引擎升级 (git 择优->build->swap; engine≈5min + vision≈8min)'; r = 'danger'; p = 'text:目标 tag (留空=自动找最新)'; w = '编译期引擎照常服务, 仅 swap 段短停 8080 (断线数分钟属预期); 三防: args 兼容预检+失败自动回退'; a = { StrataUpgrade } }
    '2' = @{ t = 'Strata 引擎回滚 (从 engine\*.bak.exe 挑一件装回)';                   r = 'danger'; p = 'bak'; w = '会停 Strata 与守护, 请走 KVMem/ComfyUI, 8080 短躺几分钟属预期'; a = { StrataRollback } }
    '3' = @{ t = 'KVMem 引擎升级 (择优->8MB 吞吐预检->sha256 对账->换 cd 行)';         r = 'danger'; w = '下载约1.1GB (5~10分钟); 装新引擎+换 cd 行, 不碰在跑服务, 启用仍由一级[2]'; a = { KvmemUpgrade } }
    '4' = @{ t = 'Strata V100(sm_70) 提速开关 (写 serve 配置 env, 重启 8080 才生效)';  p = 'radio:1=开无损组 (逐位一致)|2=无损+提速全开 (答案会有差异)|3=全部关掉'; a = { StrataV100Tuning } }
    '5' = @{ t = 'Hermes 升级 (git+PyPI 镜像自动测速择优)';                            r = 'danger'; w = '收尾会重启网关 (本会话短断), 桌面壳可能要重建; 建议主人手动关 Hermes 后更稳'; a = { HermesUpgrade } }
    '6' = @{ t = 'Hermes 备份 (hermes backup)';                                        a = { HermesBackup } }
    '7' = @{ t = '最近升级回执 (引擎回执目录 + Hermes update_receipts)';               a = { Show-UpgradeHistory } }
    '8' = @{ t = '重启 Strata 8080 (json args/env 改完就地重载; 断线约2~9分钟)';       r = 'danger'; w = 'TaskStop+KillGuard 后重拉, 512K 冷加载实测约8.6分钟, 期间对话断开'; a = { RestartStrataService } }
    'q' = @{ t = '返回一级' }
}
$MENU_C = [ordered]@{
    '1' = @{ t = 'ComfyUI 启动';                              r = 'confirm'; a = { StartComfyUI } }
    '2' = @{ t = 'ComfyUI 关闭';                              a = { StopComfyUI } }
    '3' = @{ t = '起 ComfyUI-CPU (Strata 占双卡期也能出图/桥接)'; a = { StartComfyCpu } }
    '4' = @{ t = '起 Blender (5.2.2 + 桥接)';                  a = { StartBlender } }
    '5' = @{ t = 'whisper ASR 启动';                          r = 'confirm'; a = { StartWhisper } }
    '6' = @{ t = 'whisper ASR 关闭';                          a = { StopWhisper } }
    '7' = @{ t = '视觉分流网关 18207 救护 (一死全场景视觉瞎)';  a = { ReviveVisionRouter } }
    '8' = @{ t = '零显存三模型救护 (调度官/嵌入/重排)';         a = { ReviveCpuTrio } }
    'q' = @{ t = '返回一级' }
}
$MENU_H = [ordered]@{
    '1' = @{ t = 'Hermes 自检 (status + doctor)';              a = { HermesSelfCheck } }
    '2' = @{ t = 'Hermes 修复 (ACL 补权)';                     r = 'confirm'; a = { HermesRepair } }
    '3' = @{ t = 'Hermes 网关重启 (会短断会话)';                r = 'danger'; w = '缘狐这个会话也会断开重连, 大约几十秒'; a = { RestartGateway } }
    '4' = @{ t = '打开 Hermes pwsh 环境';                      a = { OpenHermesPwsh } }
    '5' = @{ t = 'VPN 状态';                                   a = { VpnStatus } }
    '6' = @{ t = 'VPN 启动';                                   r = 'confirm'; a = { VpnStart } }
    '7' = @{ t = 'VPN 关闭';                                   r = 'confirm'; a = { VpnStop } }
    '8' = @{ t = '计划任务总览 (ysk_* 自启)';                  a = { TaskOverview } }
    '9' = @{ t = '打开常用面板 (4 浏览器页)';                   a = { OpenPanels } }
    '0' = @{ t = '最近切换日志 (main_switch.log 尾部 30 行)';  a = { TailLog } }
    'q' = @{ t = '返回一级' }
}
$MENU_GROUPS = [ordered]@{
    'b' = @{ title = '开工装配';       items = $MENU_B; head = { BlocksStatusLine } }
    'm' = @{ title = '模型与显存';     items = $MENU_M; head = { StatusLine } }
    'u' = @{ title = '引擎与升级';     items = $MENU_U; head = { EngineVerLine } }
    'c' = @{ title = '创作与救护';     items = $MENU_C; head = { CreateStatusLine } }
    'h' = @{ title = 'Hermes 与系统';  items = $MENU_H; head = { SystemStatusLine } }
}
$MENU_MAIN = [ordered]@{
    'b' = @{ t = '开工装配 (积木一键装配: 勾选在岗上卡, 不勾退出, 然后拉 Strata)'; grp = 'b' }
    '1' = @{ t = '切换主力 -> Strata (125B 双卡常驻; 退ComfyUI不误伤KVMem/18201)'; r = 'danger'; w = '会请走 ComfyUI 等 GPU 套件 (KVMem 常驻备胎不动); 小米OCR 18201 一律不清除 (CPU版零显存; GPU版共存实测中, 请走动作已注号停用); Strata 冷加载3~5分钟'; a = { SwitchToStrata } }
    '2' = @{ t = '切换主力 -> KVMem 创作协同 (GPU1 约16G, GPU0 整卡留给出图)'; r = 'danger'; w = 'Strata 将退出 (正在跑的对话会断开), 18201 转 CPU 版, TeleOCR 上岗'; a = { SwitchToKvmem } }
    '3' = @{ t = '一键服务体检 (全端口 + 显存 + 磁盘 + 引擎版本)';           a = { FullHealth } }
    '4' = @{ t = 'GPU 进程明细 (谁在占显存, 排障第一步)';                    a = { GpuProcs } }
    'm' = @{ t = '模型与显存 (工作站 / 清洁退出 / Ollama / TeleCPU应急)';    grp = 'm' }
    'u' = @{ t = '引擎与升级 (Strata / KVMem / Hermes 升级·回滚·调参·回执)'; grp = 'u' }
    'c' = @{ t = '创作与救护 (ComfyUI / whisper / Blender / 视觉网关 / 三模型)'; grp = 'c' }
    'h' = @{ t = 'Hermes 与系统 (自检·修复·网关·VPN·计划任务·面板·日志)';   grp = 'h' }
    'x' = @{ t = '全部选项一览 (组>号 = 名称)';                             a = { Show-MenuMap } }
    'q' = @{ t = '退出' }
}

function Show-MenuMap {
    Note '=================== 全部选项一览 ==================='
    foreach ($k in $MENU_MAIN.Keys) {
        $it = $MENU_MAIN[$k]
        if ($it.grp) {
            Note ('  [' + $k + '] ' + $it.t + '   ->  ' + $k + '> 组内:')
            foreach ($g in $MENU_GROUPS[$k].items.Keys) {
                if ($g -eq 'q') { continue }
                Note ('        ' + $k + '>' + $g + ' = ' + $MENU_GROUPS[$k].items[$g].t)
            }
        } else {
            Note ('  [' + $k + '] ' + $it.t)
        }
    }
}
function Show-MainConsole {
    Write-Host ""
    Write-Host "  ===================================================="
    Write-Host "    本机维护操作台 (2026-11-12 分组版)"
    StatusLine
    Write-Host "    三模型(调度官/嵌入/重排)零显存, 与任何主力共存"
    Write-Host "  ---- 一级 (常用直选 / 分组入口) ----"
    foreach ($k in $MENU_MAIN.Keys) { Write-Host ("    [" + $k + "]  " + $MENU_MAIN[$k].t) }
    Write-Host "  ===================================================="
}
function Show-Group ([string]$gk) {
    $g = $MENU_GROUPS[$gk]
    Write-Host ""
    Write-Host "  ----------------------------------------------------"
    Write-Host ("    " + $gk + "] " + $g.title + " 组")
    try { & $g.head } catch { }
    Write-Host ("  ---- " + $g.title + " (" + $gk + ">) ----")
    foreach ($k in $g.items.Keys) { Write-Host ("    [" + $gk + ">" + $k + "]  " + $g.items[$k].t) }
    Write-Host "  ----------------------------------------------------"
}
function Run-Group ([string]$gk) {
    $g = $MENU_GROUPS[$gk]
    :grpLoop while ($true) {
        Show-Group $gk
        $raw = Read-Host ("  " + $gk + "> 选项 (q=返回一级)")
        if ($null -eq $raw) { break grpLoop }
        $c = "$raw".Trim().ToLower()
        if ($c -eq '' -or $c -eq 'q') { break grpLoop }
        $it = $g.items[$c]
        if (-not $it) { Write-Host ("  无效选项 (" + $gk + ">" + $c + ")。"); continue }
        if ($it.a) { & $it.a }
    }
}
# CLI direct modes (2026-11-03): -ProbeOnly ranks without touching hermes/gateway; -UpdateDirect ranks then upgrades
if ($ProbeOnly)    { Show-MirrorRanking | Out-Null; exit 0 }
if ($UpdateDirect) { HermesUpgrade; exit 0 }
if ($StrataDirect) { StrataUpgrade -Auto; exit $LASTEXITCODE }
if ($KvmemDirect)  { KvmemUpgrade -Auto; exit $LASTEXITCODE }
# diagnostics: rank only the new mirror pools (generic git template pool / release download pool), change nothing
if ($Rank2Git) { Show-MirrorRanking2 -GitRepo $Rank2Git | Out-Null; exit 0 }
if ($Rank2Dl)  { Show-MirrorRanking2 -DlUrl  $Rank2Dl  | Out-Null; exit 0 }
# GUI front-end contract (ysk_maint_console.exe): menu tree as JSON -- labels, risk levels,
# dialog specs and impact lines all live in the $MENU tables above, so the window app can
# never drift from this script (same "single source" philosophy as Show-MenuMap).
if ($DumpMenu) {
    $dm = [ordered]@{ main = @(); groups = [ordered]@{} }
    foreach ($k in $MENU_MAIN.Keys) {
        $e = $MENU_MAIN[$k]
        $o = [ordered]@{ k = $k; t = $e.t }
        if ($e.grp) { $o['grp'] = $e.grp }
        if ($e.r)   { $o['r']   = $e.r }
        if ($e.w)   { $o['w']   = $e.w }
        $dm.main += $o
    }
    foreach ($gk in $MENU_GROUPS.Keys) {
        $items = @()
        foreach ($ik in $MENU_GROUPS[$gk].items.Keys) {
            $e = $MENU_GROUPS[$gk].items[$ik]
            $o = [ordered]@{ k = $ik; t = $e.t }
            if ($e.r) { $o['r'] = $e.r }
            if ($e.p) { $o['p'] = $e.p }
            if ($e.w) { $o['w'] = $e.w }
            $items += $o
        }
        $dm.groups[$gk] = [ordered]@{ title = $MENU_GROUPS[$gk].title; items = $items }
    }
    ConvertTo-Json -InputObject $dm -Depth 6 -Compress
    exit 0
}
if ($ListBak) { ConvertTo-Json -InputObject @(List-StrataBakItems) -Depth 3 -Compress; exit 0 }
# assembly-desk probe for the GUI first tab: one JSON line, no banner noise.
# st: off|cpu|gpu|up | gcur: none|off|armed|missing | display order = $BLOCKS order = assembly priority.
if ($BlocksState) {
    $s = Get-BlockSnapshot
    $o = [ordered]@{
        gpu    = @($s['_gpu'])
        strata = [ordered]@{ alive = [bool]$s['_strata']; http = $(if ($s['_strata']) { 200 } else { 0 }) }
        router = [bool]$s['_router']
        blocks = @(foreach ($id in $BLOCKS.Keys) {
            $b = $BLOCKS[$id]
            [pscustomobject]@{ id = $id; n = $b.n; full = $b.full; port = $b.port
                st = $s[$id].st; zero = [bool]$b.zero; gate = $b.gate
                g = $b.g; gcur = $s[$id].gcur; card = $s[$id].card
                dflt = $b.dflt; cards = $b.cards }
        } )
    }
    ConvertTo-Json -InputObject $o -Depth 4 -Compress
    exit 0
}
# single-shot item run for the GUI: -Run 'u>8' or -Run '3'; args feed the Ask() queue.
if ($Run) {
    $key = "$Run".Trim().ToLower()
    $global:RUN_ARGQ = @("$Arg" -split ',' | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' })
    if ($key -eq 'q') { exit 0 }
    $act = $null
    if ($key -match '^([bmuch])>([0-9a-z]+)$') {
        $gg = $MENU_GROUPS[$Matches[1]]
        if ($gg) { $act = $gg.items[$Matches[2]].a }
    } elseif ($MENU_MAIN[$key]) {
        if ($MENU_MAIN[$key].grp) { Note ("!! group entry -- give an item, e.g. " + $key + ">1"); exit 2 }
        $act = $MENU_MAIN[$key].a
    }
    if (-not $act) { Note ("!! unknown -Run target: " + $Run); exit 2 }
    & $act
    exit 0
}
# when dot-sourcing for function reuse, skip the main menu (261104)
if ($MyInvocation.InvocationName -eq '.') { return }
:mainLoop while ($true) {
    Show-MainConsole
    $raw = Read-Host "  请输入选项"
    if ($null -eq $raw) { break mainLoop }
    $choice = "$raw".Trim().ToLower()
    if ($choice -eq '') { break mainLoop }
    if ($choice -eq 'q') { break mainLoop }
    $it = $MENU_MAIN[$choice]
    if (-not $it) { Write-Host ("  无效选项 (" + $choice + ")。可用 [x] 看全部选项。"); continue }
    if ($it.grp) { Run-Group $it.grp; continue }
    if ($it.a) { & $it.a }
}
Write-Host "  已退出。"
