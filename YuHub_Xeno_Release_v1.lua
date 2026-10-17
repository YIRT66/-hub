-- 雨 Hub | Yu Hub Universal v2.5 / Xeno + remote ANUI
-- Universal client-side toolkit. Server authority may reject movement and teleport.
local Players=game:GetService("Players")
local RS=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local TS=game:GetService("TeleportService")
local VU=game:GetService("VirtualUser")
local LP=Players.LocalPlayer
assert(LP,"Client-only script")
local env=(type(getgenv)=="function" and getgenv()) or _G
if env.NexusUniversalHub and env.NexusUniversalHub.Destroy then
    pcall(env.NexusUniversalHub.Destroy)
end
local State={
 speedEnabled=false,speed=24,jumpEnabled=false,jump=65,infiniteJump=false,
 fly=false,flySpeed=65,noclip=false,antiFling=false,antiAfk=false,
 antiFlingMode="智能",antiFlingRadius=45,antiFlingEnemySpeed=60,
 antiFlingEnemySpin=35,antiFlingSelfSpeed=105,antiFlingSelfSpin=50,
 antiFlingRollback=true,antiFlingAlert=true,antiFlingVehicleSkip=true,
 antiVoid=false,antiVoidHeight=-100,performance=false,
 followOffset=5,teleX=0,teleY=0,teleZ=0,
 sprintEnabled=false,sprintSpeed=40,sprinting=false,
 gravityEnabled=false,gravity=workspace.Gravity,hipEnabled=false,hipHeight=2,
 esp=true,highlight=true,names=true,health=true,distance=true,
 boxes=false,tracers=false,teamFilter=false,espRange=2500,
 espColor=Color3.fromRGB(65,202,255),
 fullbright=false,noFog=false,xray=false,xrayAlpha=0.6,
 follow=false,target="",clickTP=false,respawnTP=false,
 fov=70,lastPos=nil,up=false,down=false,
 uiMode="精简",sidebarGrouped=false,musicVisible=false,hudEnabled=true,hudCompact=false,hudShowPing=true,hudShowHealth=true,
 hudFeatures=true,hudAimTarget=true,hudScale=1,hudOpacity=0.07,hudAccent=Color3.fromRGB(65,202,255),hudX=-1,hudY=-1,
 aim=false,aimHold=true,aimRadius=170,aimSmooth=11,aimPart="头部",
 aimCenterMode="跟随鼠标",aimLockRing=true,aimLockRadius=28,aimSticky=false,
 aimTeamCheck=true,aimWallCheck=true,aimAliveOnly=true,
 aimShowRadius=true,aimShowTarget=true,aimMaxDistance=1500,
 projectileTrace=false,projectileLifetime=0.4,projectileColor=Color3.fromRGB(88,208,255),
 selfTag=true,showMarkedTags=true,tagScale=1,clickToolSpeed=0,aimScanInterval=0.09,
 antiAim=false,antiAimStyle="微摆",antiAimAngle=8,antiAimSpeed=2,
 selfSpin=false,selfSpinSpeed=360,
 blackHole=false,blackHoleRadius=0,blackHoleStrength=180,blackHoleOrbitSpeed=10,blackHoleOffset=5,
 blackHoleMode="角色周围",blackHoleHeight=2,blackHoleMaxMass=1000000,
 blackHoleMaxParts=260,blackHoleVisual=true,
 touchKill=false,touchKillCount=0,fling=false,flingSpeed=1800,flingDuration=1.3,
 flingApproach=false,flingCooldown=5,flingLast=0,
 hotkeyHints=true,
 grabEnabled=false,grabRange=60,grabDistance=13,grabStrength=75,grabMaxMass=400,
 perfMode="均衡",perfEspInterval=0.14,perfAimInterval=0.1,perfProjectileScan=4,
 perfAutoAdjust=true,perfEffectsLimit=2500
}
local App={Version="2.6",Running=true,State=State,connections={},esp={},noclipParts={},flingParts={},xrayParts={}}
env.NexusUniversalHub=App
 env.YuHub=App
-- Remote ANUI (no embedded library; source fetched at startup).
-- Xeno / generic-executor compatibility layer (no elevated executor APIs required).
do
 local compat={Name="Unknown",Version="",IsXeno=false,Issues={},HttpSource="",GuiSource="",InstalledShim=nil}
 local environment=env
 local ok,api=pcall(function()return shared and shared.Xeno end)
 if ok and type(api)=="table" then
  local about=rawget(api,"about")
  if type(about)=="table" and tostring(about._name or ""):lower():find("xeno",1,true)then
   compat.IsXeno=true
   compat.Name="Xeno"
   compat.Version=tostring(about._version or "")
   compat.API=api
  end
 end
 for _,fn in ipairs({identifyexecutor,getexecutorname})do
  if type(fn)=="function"then
   local worked,name,version=pcall(fn)
   if worked and type(name)=="string" and #name>0 then
    compat.Name=name
    if type(version)=="string" then compat.Version=version end
    if name:lower():find("xeno",1,true)then compat.IsXeno=true end
    break
   end
  end
 end
 if compat.IsXeno and type(gethui)~="function" and type(environment.gethui)~="function" then
  -- ANUI can accept a PlayerGui-based gethui substitute on Xeno builds
  -- that do not expose a hidden UI container.
  compat.InstalledShim=function() return LP:WaitForChild("PlayerGui",10) end
  environment.gethui=compat.InstalledShim
 end
 function compat.UIParent()
  local playerGui=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",10)
  if playerGui then
   compat.GuiSource="PlayerGui"
   return playerGui
  end
  local success,core=pcall(function()return game:GetService("CoreGui")end)
  if success and core then
   compat.GuiSource="CoreGui"
   return core
  end
  error("[雨 Hub] 没有可用的 ScreenGui 容器")
 end
 -- Xeno HTTP providers can return a string, Response.Body, Response.body,
 -- or a response-table wrapped in Data/Response. Normalize without trusting
 -- a 200-looking status when there is no actual source text.
 function compat.ExtractBody(reply)
  local visited={}
  local function walk(value,depth)
   if type(value)=="string"then return value end
   if type(value)~="table" or depth>5 or visited[value]then return nil end
   visited[value]=true
   local status=tonumber(value.StatusCode or value.Status or value.status_code or value.statusCode)
   if status and (status<200 or status>=400)then return nil end
   for _,name in ipairs({"Body","body","ResponseBody","responseBody","Content","content",
    "Text","text","Data","data","Response","response","Result","result"})do
    local body=walk(value[name],depth+1)
    if type(body)=="string" and #body>0 then return body end
   end
   return nil
  end
  return walk(reply,0)
 end
 local cachePath="RainHub/anui-dist-cache.lua"
 local function validAnuiSource(body)
  if type(body)~="string" or #body<2000 or body:match("^%s*<")then return false end
  if type(loadstring)~="function"then return false end
  local ok,compiled=pcall(loadstring,body)
  return ok and type(compiled)=="function"
 end
 local function cacheSource(body)
  environment.RainHub_ANUI_StableCache=body
  if type(writefile)~="function"then return end
  pcall(function()
   if type(makefolder)=="function"then
    if type(isfolder)~="function" or not isfolder("RainHub")then makefolder("RainHub")end
   end
   writefile(cachePath,body)
  end)
 end
 local function fromCache()
  local inMemory=environment.RainHub_ANUI_StableCache
  if validAnuiSource(inMemory)then
   compat.HttpSource="内存缓存"
   return inMemory
  end
  if type(isfile)=="function" and type(readfile)=="function"then
   local ok,contents=pcall(function()
    return isfile(cachePath) and readfile(cachePath) or nil
   end)
   if ok and validAnuiSource(contents)then
    environment.RainHub_ANUI_StableCache=contents
    compat.HttpSource="本地缓存"
    return contents
   end
  end
  return nil
 end
 function compat.Fetch(url)
  if type(url)~="string" or not url:match("^https://raw%.githubusercontent%.com/ANHub%-Script/ANUI/")then
   error("Blocked untrusted ANUI source URL")
  end
  local mirrors={
   url,
   "https://cdn.jsdelivr.net/gh/ANHub-Script/ANUI@main/dist/main.lua",
   "https://fastly.jsdelivr.net/gh/ANHub-Script/ANUI@main/dist/main.lua"
  }
  local providers={
   {"game:HttpGet",function(target) return game:HttpGet(target)end},
   {"game:HttpGetAsync",function(target)return game:HttpGetAsync(target)end}
  }
  local function addRequest(label,fn)
   if type(fn)=="function"then
    providers[#providers+1]={label,function(target)
     return fn({Url=target,Method="GET",Headers={["Accept"]="text/plain"}})
    end}
   end
  end
  addRequest("http_request",http_request)
  addRequest("request",request)
  if type(syn)=="table" then addRequest("syn.request",syn.request)end
  if type(http)=="table" then addRequest("http.request",http.request)end
  if compat.API and type(compat.API.HttpGet)=="function"then
   providers[#providers+1]={"Xeno.HttpGet",function(target)
    return compat.API.HttpGet(target)
   end}
  end
  local diagnostics={}
  for _,target in ipairs(mirrors)do
   for _,provider in ipairs(providers)do
    local ok,reply=pcall(provider[2],target)
    local body=ok and compat.ExtractBody(reply) or nil
    if validAnuiSource(body)then
     compat.HttpSource=provider[1]..(target==url and "" or " (CDN)")
     cacheSource(body)
     return body
    end
    if #diagnostics<10 then
     local reason
     if not ok then reason=tostring(reply):sub(1,90)
     elseif type(reply)=="table"then
      reason="返回表缺少有效 Lua 源码，HTTP状态 "..tostring(reply.StatusCode or reply.Status or "?")
     else reason="无有效源码 ("..type(reply)..")"end
     diagnostics[#diagnostics+1]=provider[1].."="..reason
    end
   end
  end
  compat.Issues=diagnostics
  local cached=fromCache()
  if cached then return cached end
  error("[RainHub/Xeno] ANUI 获取失败：已尝试 GitHub、CDN 和本地缓存；请检查网络。")
 end
 function compat.Report()
  local flags={
   {"loadstring",type(loadstring)=="function"},
   {"HttpGet/request",compat.HttpSource~=""},
   {"readfile",type(readfile)=="function"},
   {"writefile",type(writefile)=="function"},
   {"isfile",type(isfile)=="function"},
   {"makefolder",type(makefolder)=="function"},
   {"setclipboard/toclipboard",type(setclipboard)=="function" or type(toclipboard)=="function"},
   {"getcustomasset",type(getcustomasset)=="function" or type(getsynasset)=="function"}
  }
  local available=0
  local missing={}
  for _,e in ipairs(flags)do
   if e[2]then available+=1
   else missing[#missing+1]=e[1]end
  end
  return "执行器："..compat.Name..(compat.Version~="" and " "..compat.Version or "")..
   "\n模式："..(compat.IsXeno and "Xeno 兼容" or "通用")..
   " · 加载方式："..(compat.HttpSource~="" and compat.HttpSource or "待加载")..
   "\nGUI："..(compat.GuiSource~="" and compat.GuiSource or "待创建")..
   " · 可用接口："..available.."/"..#flags..
   "\n可选接口缺失："..(#missing==0 and "无" or table.concat(missing,", "))
 end
 App.Compat=compat
end

local ANUI,Window,overlay,flyVelocity,flyGyro,flyPart
local aimCircle,aimTargetLabel
local currentAimTarget
local ownedTools,markedTags,projectileTrails,trackedCount={},{},{},0
App.OwnedTools=ownedTools
App.Tags=markedTags
local hudGui,hudPanel,hudScale,hudAccentLine,hudHeading,hudMetric,hudDetails
local combatEffects={
 antiAimClock=0,antiAimPrevious=nil,antiAimAutoRotate=nil,
 selfSpinClock=0,selfSpinAutoRotate=nil,
 holeTargets={},holeSeen=setmetatable({},{__mode="k"}),holeQueue=nil,holeCursor=1,holeTargetCursor=1,holeLastScan=-100,holeClock=0,
 holePart=nil,holeGlow=nil,holeTick=0,holeScans=0,
 touchCons={},touchModels={},touchCharacter=nil,
 flingForce=nil,flingEnd=0,flingOrigin=nil,flingActive=false
}
App.CombatEffects=combatEffects
App.HotkeyActions={"fly","noclip","antiFling","aim","antiAim","selfSpin","blackHole","touchKill","fling","clickTP","emergency"}
App.HotkeyDefaults={fly="F6",noclip="F7",antiFling="F8",aim="F9",antiAim="F10",selfSpin="End",blackHole="F11",touchKill="F12",fling="G",clickTP="Insert",emergency="Home"}
App.HotkeyLabels={fly="飞行",noclip="穿墙",antiFling="防甩飞",aim="自瞄",antiAim="反自瞄",selfSpin="自我旋转",blackHole="黑洞",touchKill="触碰死亡",fling="甩飞",clickTP="点击传送",emergency="一键紧急停用"}
App.HotkeyFile="RainHub/hotkeys-v1.json"
App.Hotkeys={}
for k,v in pairs(App.HotkeyDefaults)do App.Hotkeys[k]=v end
function App.KeyName(raw)
 local s=tostring(raw or ""):gsub("^Enum.KeyCode%.",""):gsub("^KeyCode%.","")
 if s=="Unknown" or s=="None" or s=="" then return nil end
 local ok,key=pcall(function()return Enum.KeyCode[s]end)
 return ok and key and key~=Enum.KeyCode.Unknown and s or nil
end
function App.SaveHotkeys()
 if type(writefile)~="function"then return false,"当前执行器无法写入本地文件"end
 return pcall(function()
  if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder("RainHub"))then makefolder("RainHub")end
  writefile(App.HotkeyFile,game:GetService("HttpService"):JSONEncode(App.Hotkeys))
 end)
end
function App.LoadHotkeys()
 if type(isfile)~="function" or type(readfile)~="function"then return false end
 local ok,data=pcall(function()
  if not isfile(App.HotkeyFile)then return nil end
  return game:GetService("HttpService"):JSONDecode(readfile(App.HotkeyFile))
 end)
 if ok and type(data)=="table"then
  for _,action in ipairs(App.HotkeyActions)do
   if type(data[action])=="string" and App.KeyName(data[action])then App.Hotkeys[action]=data[action] end
  end
  return true
 end
 return false
end
App.LoadHotkeys()
local hudDrag={active=false,start=nil,origin=nil,pointer=nil}
local HUD_POSITION_PATH="NexusUniversalHUD/position.json"
local function loadHUDPosition()
 if type(isfile)~="function" or type(readfile)~="function" then return end
 pcall(function()
  if not isfile(HUD_POSITION_PATH)then return end
  local obj=game:GetService("HttpService"):JSONDecode(readfile(HUD_POSITION_PATH))
  if type(obj)=="table" and type(obj.x)=="number" and type(obj.y)=="number"then
   if obj.x>=0 and obj.y>=0 then State.hudX=obj.x;State.hudY=obj.y end
  end
 end)
end
local function saveHUDPosition()
 if type(writefile)~="function" then return end
 pcall(function()
  if type(makefolder)=="function" then
   if type(isfolder)~="function" or not isfolder("NexusUniversalHUD")then
    makefolder("NexusUniversalHUD")
   end
  end
  writefile(HUD_POSITION_PATH,game:GetService("HttpService"):JSONEncode({
   x=State.hudX,y=State.hudY
  }))
 end)
end
loadHUDPosition()
-- Display preferences are private to the executor's local file system.
local displayPath="RainHub/display-v3.json"
local customPageDefaults={
 Movement=true,Defense=true,ESP=true,PlayerUI=true,Travel=true,
 World=true,Aim=true,Combat=true,Hotkeys=true,Music=false,Performance=true,Utilities=true
}
State.customPages={}
State.customHiddenControls={}
State.customShowExtras=true
local function loadDisplaySettings()
 if type(isfile)~="function" or type(readfile)~="function"then return false end
 local ok,data=pcall(function()
  if not isfile(displayPath)then return nil end
  return game:GetService("HttpService"):JSONDecode(readfile(displayPath))
 end)
 if not ok or type(data)~="table" then return false end
 if tonumber(data.version or 0)>=5 and (data.mode=="精简" or data.mode=="高级" or data.mode=="自定义")then State.uiMode=data.mode end
 if type(data.sidebarGrouped)=="boolean" and tonumber(data.version or 0)>=5 then State.sidebarGrouped=data.sidebarGrouped end
 if type(data.musicVisible)=="boolean"then State.musicVisible=data.musicVisible end
 if type(data.pages)=="table"then
  for key in pairs(customPageDefaults)do
   if type(data.pages[key])=="boolean"then State.customPages[key]=data.pages[key] end
  end
 end
 if type(data.hidden)=="table" then
  for key,value in pairs(data.hidden)do
   if type(key)=="string" and #key<=150 and value==true then
    State.customHiddenControls[key]=true
   end
  end
 end
 return true
end
local function saveDisplaySettings()
 if type(writefile)~="function"then return false,"执行器不支持 writefile" end
 return pcall(function()
  if type(makefolder)=="function"then
   if type(isfolder)~="function" or not isfolder("RainHub")then makefolder("RainHub")end
  end
  local json=game:GetService("HttpService"):JSONEncode({
   version=5,mode=State.uiMode,sidebarGrouped=State.sidebarGrouped,musicVisible=State.musicVisible,pages=State.customPages,hidden=State.customHiddenControls
  })
  writefile(displayPath,json)
 end)
end
loadDisplaySettings()
App.SaveDisplaySettings=saveDisplaySettings
App.LoadDisplaySettings=loadDisplaySettings

local function executorInfo()
 if App.Compat and App.Compat.Name~="Unknown"then return App.Compat.Name,App.Compat.Version end
 local n="未知 / 未开放接口";local version=""
 if type(identifyexecutor)=="function" then
  local ok,x,y=pcall(identifyexecutor)
  if ok then n=tostring(x or n);version=tostring(y or "")end
 elseif type(getexecutorname)=="function" then
  local ok,x=pcall(getexecutorname);if ok then n=tostring(x or n)end
 end
 return n,version
end
local function maskedHardwareID()
 if type(gethwid)~="function"then return "当前环境不支持" end
 local ok,v=pcall(gethwid)
 if not ok or type(v)~="string"or #v<4 then return "无可用标识"end
 return string.rep("●",6).." "..v:sub(-4)
end
local function localPing()
 local ok,n=pcall(function()return LP:GetNetworkPing()end)
 return ok and math.floor(n*1000+.5) or nil
end
local startLight={brightness=Lighting.Brightness,ambient=Lighting.Ambient,
 outdoor=Lighting.OutdoorAmbient,shadows=Lighting.GlobalShadows,
 fogEnd=Lighting.FogEnd,fogStart=Lighting.FogStart}
local startFOV=workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local startSpeed,startJump,startHeight,startHip
local startGravity=workspace.Gravity
local markerSlot=1
local bookmarks={}
local followTarget=""
local guard={safeCFrame=nil,lastSafe=0,lastRecover=0,recoveries=0,threat="",threatNearby=false,disableUntil=0}
App.Guard=guard
local perfSaved=setmetatable({}, {__mode="k"})
local spectated=""
local espClock=0
local physicsClock=0
local frames=0
local fps=60
local lastFps=os.clock()
local function connect(signal,callback)
 local con=signal:Connect(callback)
 table.insert(App.connections,con)
 return con
end
local function char(p) return (p or LP).Character end
local function humanoid(p)
 local c=char(p)
 return c and c:FindFirstChildOfClass("Humanoid")
end
local function hrp(p)
 local c=char(p)
 return c and c:FindFirstChild("HumanoidRootPart")
end
local function alive(p)
 local h=humanoid(p)
 return h and h.Health>0
end
local function toast(title,body,icon)
 if ANUI then
  pcall(function()ANUI:Notify({Title=tostring(title),Content=tostring(body),Icon=icon or "info",Duration=3})end)
 else print("[NEXUS]",title,body)end
end
local function copy(value)
 local fn=(type(setclipboard)=="function" and setclipboard) or (type(toclipboard)=="function" and toclipboard)
 if type(fn)=="function"then
  local ok=pcall(fn,tostring(value))
  if ok then toast("已复制",value,"check")return end
 end
 toast("功能不可用","当前执行器未开放剪贴板接口","alert-circle")
end
local function otherPlayers()
 local result={}
 for _,p in ipairs(Players:GetPlayers())do
  if p~=LP then table.insert(result,p)end
 end
 return result
end
local function lookup(value)
 value=tostring(value or ""):lower():match("^%s*(.-)%s*$")
 if value=="" then return nil end
 for _,p in ipairs(otherPlayers())do
  if p.Name:lower()==value or p.DisplayName:lower()==value then return p end
 end
 for _,p in ipairs(otherPlayers())do
  if p.Name:lower():sub(1,#value)==value or p.DisplayName:lower():sub(1,#value)==value then return p end
 end
 return nil
end
local function rememberMovement()
 local h=humanoid()
 if h then startSpeed=h.WalkSpeed;startJump=h.JumpPower;startHeight=h.JumpHeight;startHip=h.HipHeight end
end
local function applyMovement()
 local h=humanoid()
 if not h then return end
 if State.sprintEnabled and State.sprinting then
  pcall(function()h.WalkSpeed=State.sprintSpeed end)
 elseif State.speedEnabled then
  pcall(function()h.WalkSpeed=State.speed end)
 elseif State.sprintEnabled then
  pcall(function()h.WalkSpeed=startSpeed or 16 end)
 end
 if State.hipEnabled then pcall(function()h.HipHeight=State.hipHeight end)end
 if State.jumpEnabled then
  if h.UseJumpPower then pcall(function()h.JumpPower=State.jump end)
  else pcall(function()h.JumpHeight=State.jump/7 end)end
 end
end
local function restoreMovement()
 local h=humanoid()
 if not h then return end
 if startSpeed then h.WalkSpeed=startSpeed end
 if startJump then h.JumpPower=startJump end
 if startHeight then h.JumpHeight=startHeight end
 if startHip then h.HipHeight=startHip end
end
local function jumpReset()
 local h=humanoid()
 if h then
  if startJump then h.JumpPower=startJump end
  if startHeight then h.JumpHeight=startHeight end
 end
end
local function teleport(cframe)
 local r=hrp()
 if not r then toast("传送失败","角色还没生成","alert-circle")return false end
 if typeof(cframe)~="CFrame" then return false end
 State.lastPos=r.CFrame
 guard.disableUntil=os.clock()+2
 r.CFrame=cframe
 r.AssemblyLinearVelocity=Vector3.zero
 return true
end
local function stopFly()
 if flyVelocity then pcall(function()flyVelocity:Destroy()end)end
 if flyGyro then pcall(function()flyGyro:Destroy()end)end
 flyVelocity=nil;flyGyro=nil;flyPart=nil
 local h=humanoid()
 if h then h.PlatformStand=false;pcall(function()h:ChangeState(Enum.HumanoidStateType.GettingUp)end)end
end
local function startFly()
 stopFly()
 local r,h=hrp(),humanoid()
 if not r or not h then return end
 flyPart=r
 flyVelocity=Instance.new("BodyVelocity")
 flyVelocity.Name="NexusFlight"
 flyVelocity.MaxForce=Vector3.new(1e8,1e8,1e8)
 flyVelocity.P=10000
 flyVelocity.Parent=r
 flyGyro=Instance.new("BodyGyro")
 flyGyro.Name="NexusFlightDirection"
 flyGyro.MaxTorque=Vector3.new(1e8,1e8,1e8)
 flyGyro.P=11000
 flyGyro.D=500
 flyGyro.Parent=r
 h.PlatformStand=true
end
local function restoreParts(map,prop)
 for part,old in pairs(map)do
  if part.Parent then pcall(function()part[prop]=old end)end
  map[part]=nil
 end
end
local function setLighting()
 if State.fullbright then
  Lighting.Brightness=3
  Lighting.Ambient=Color3.fromRGB(185,185,185)
  Lighting.OutdoorAmbient=Color3.fromRGB(185,185,185)
  Lighting.GlobalShadows=false
 else
  Lighting.Brightness=startLight.brightness
  Lighting.Ambient=startLight.ambient
  Lighting.OutdoorAmbient=startLight.outdoor
  Lighting.GlobalShadows=startLight.shadows
 end
end
local function setFog()
 Lighting.FogEnd=State.noFog and 1000000 or startLight.fogEnd
 if not State.noFog then Lighting.FogStart=startLight.fogStart end
end
local function refreshXray()
 restoreParts(App.xrayParts,"LocalTransparencyModifier")
 if not State.xray then return end
 local count=0
 for _,part in ipairs(workspace:GetDescendants())do
  if part:IsA("BasePart") and part.CanCollide and not (char() and part:IsDescendantOf(char()))then
   App.xrayParts[part]=part.LocalTransparencyModifier
   part.LocalTransparencyModifier=State.xrayAlpha
   count+=1
   if count>=2500 then break end
  end
 end
end
local function makeOverlay()
 local parent=App.Compat.UIParent()
 local old=parent:FindFirstChild("NexusESP")
 if old then old:Destroy()end
 overlay=Instance.new("ScreenGui")
 overlay.Name="NexusESP"
 overlay.ResetOnSpawn=false
 overlay.IgnoreGuiInset=true
 local worked=pcall(function()overlay.Parent=parent end)
 if not worked or overlay.Parent~=parent then
  local alt=LP:WaitForChild("PlayerGui",10)
  assert(alt,"没有可用的 GUI 父容器")
  overlay.Parent=alt
  App.Compat.GuiSource="PlayerGui (fallback)"
 end
end
local function newLine(name)
 local f=Instance.new("Frame")
 f.Name=name
 f.BorderSizePixel=0
 f.AnchorPoint=Vector2.new(0.5,0.5)
 f.BackgroundColor3=State.espColor
 f.Visible=false
 f.Parent=overlay
 return f
end
local function drawLine(frame,x1,y1,x2,y2)
 local dx,dy=x2-x1,y2-y1
 frame.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2)
 frame.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),2)
 frame.Rotation=math.deg(math.atan2(dy,dx))
 frame.BackgroundColor3=State.espColor
 frame.Visible=true
end
local function clearESP(p)
 local e=App.esp[p]
 if not e then return end
 for _,v in ipairs(e.objects)do pcall(function()v:Destroy()end)end
 App.esp[p]=nil
end
local function makeESP(p)
 clearESP(p)
 local c=char(p)
 local head=c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
 if not c or not head then return end
 local e={model=c,objects={}}
 local function own(inst)table.insert(e.objects,inst)return inst end
 e.highlight=own(Instance.new("Highlight"))
 e.highlight.Name="NexusPlayerESP"
 e.highlight.Adornee=c
 e.highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
 e.highlight.FillTransparency=0.75
 e.highlight.OutlineTransparency=0.1
 e.highlight.Parent=overlay
 e.bill=own(Instance.new("BillboardGui"))
 e.bill.Name="NexusNameTag"
 e.bill.Adornee=head
 e.bill.Size=UDim2.fromOffset(250,75)
 e.bill.StudsOffsetWorldSpace=Vector3.new(0,3,0)
 e.bill.AlwaysOnTop=true
 e.bill.Parent=overlay
 e.text=Instance.new("TextLabel")
 e.text.BackgroundTransparency=1
 e.text.Size=UDim2.fromScale(1,1)
 e.text.Font=Enum.Font.GothamBold
 e.text.TextSize=14
 e.text.TextStrokeTransparency=0.2
 e.text.TextWrapped=true
 e.text.Parent=e.bill
 e.tracer=own(newLine("Tracer"))
 e.box={}
 for i=1,4 do table.insert(e.box,own(newLine("Box"..i)))end
 App.esp[p]=e
end
local function updateESP()
 if not State.esp then
  for p in pairs(App.esp)do clearESP(p)end
  return
 end
 local camera=workspace.CurrentCamera
 if not camera then return end
 local seen={}
 for _,p in ipairs(otherPlayers())do
  local c,r=char(p),hrp(p)
  local my=hrp()
  local dist=(r and my) and (r.Position-my.Position).Magnitude or math.huge
  local sameTeam=LP.Team~=nil and p.Team==LP.Team
  if c and r and alive(p) and dist<State.espRange and (not State.teamFilter or not sameTeam) then
   seen[p]=true
   local e=App.esp[p]
   if not e or e.model~=c then makeESP(p);e=App.esp[p]end
   if e then
    e.highlight.Enabled=State.highlight
    e.highlight.FillColor=State.espColor
    e.highlight.OutlineColor=Color3.new(1,1,1)
    e.bill.Enabled=State.names or State.health or State.distance
    e.bill.MaxDistance=State.espRange
    local lines={}
    if State.names then table.insert(lines,p.DisplayName.." (@"..p.Name..")")end
    local h=humanoid(p)
    if State.health and h then table.insert(lines,"HP: "..math.floor(h.Health).."/"..math.floor(h.MaxHealth))end
    if State.distance then table.insert(lines,math.floor(dist).." studs")end
    e.text.Text=table.concat(lines,"\n")
    e.text.TextColor3=State.espColor
    local pt,visible=camera:WorldToViewportPoint(r.Position)
    local show=visible and pt.Z>0
    e.tracer.Visible=false
    for _,f in ipairs(e.box)do f.Visible=false end
    if show and State.tracers then
     drawLine(e.tracer,camera.ViewportSize.X/2,camera.ViewportSize.Y,pt.X,pt.Y)
    end
    if show and State.boxes then
     local hsize=math.clamp(900*c:GetExtentsSize().Y/pt.Z,16,600)
     local wsize=hsize*.55
     local x1,x2=pt.X-wsize/2,pt.X+wsize/2
     local y1,y2=pt.Y-hsize/2,pt.Y+hsize/2
     drawLine(e.box[1],x1,y1,x2,y1)
     drawLine(e.box[2],x2,y1,x2,y2)
     drawLine(e.box[3],x2,y2,x1,y2)
     drawLine(e.box[4],x1,y2,x1,y1)
    end
   end
  end
 end
 for p in pairs(App.esp)do if not seen[p]then clearESP(p)end end
end
App.UpdateESP=updateESP
local function spectate(p)
 local cam=workspace.CurrentCamera
 if not cam then return end
 local h=humanoid(p)
 if p and not h then toast("观战失败","目标角色未加载","alert-circle")return end
 cam.CameraType=Enum.CameraType.Custom
 cam.CameraSubject=h or humanoid()
 spectated=p and p.Name or ""
end
-- Multilayer local anti-fling: pre-physics collision filtering + post-physics recovery.
local function antiFlingTick()
 local r,h=hrp(),humanoid()
 if not r or not h or h.Health<=0 then return end
 local flagged={}
 local nearest=""
 local nearestDist=math.huge
 local radius=State.antiFlingRadius
 local aggressive=State.antiFlingMode=="强力"
 for _,p in ipairs(otherPlayers())do
  local pr=hrp(p)
  if pr then
   local dist=(pr.Position-r.Position).Magnitude
   if dist<radius then
    local hostile=aggressive or pr.AssemblyLinearVelocity.Magnitude>State.antiFlingEnemySpeed
       or pr.AssemblyAngularVelocity.Magnitude>State.antiFlingEnemySpin
    if hostile then
     if dist<nearestDist then nearest=p.Name;nearestDist=dist end
     local c=char(p)
     if c then
      for _,part in ipairs(c:GetDescendants())do
       if part:IsA("BasePart")then
        flagged[part]=true
        if App.flingParts[part]==nil then App.flingParts[part]=part.CanCollide end
        part.CanCollide=false
       end
      end
     end
    end
   end
  end
 end
 for part,old in pairs(App.flingParts)do
  if not flagged[part]then
   if part.Parent then pcall(function()part.CanCollide=old end)end
   App.flingParts[part]=nil
  end
 end
 guard.threatNearby=nearest~=""
 guard.threat=nearest
end
local function recoverFlingTick()
 local r,h=hrp(),humanoid()
 if not r or not h or h.Health<=0 then return end
 local now=os.clock()
 if State.fly or State.noclip or now<guard.disableUntil then return end
 if State.antiFlingVehicleSkip and (h.SeatPart~=nil or h.Sit) then return end
 local v=r.AssemblyLinearVelocity
 local horizontal=Vector3.new(v.X,0,v.Z).Magnitude
 local spin=r.AssemblyAngularVelocity.Magnitude
 local abnormal=State.antiFling and (horizontal>State.antiFlingSelfSpeed or spin>State.antiFlingSelfSpin)
 local incoming=State.antiFling and guard.threatNearby and (horizontal>State.antiFlingSelfSpeed*0.55 or spin>State.antiFlingSelfSpin*0.55)
 if not abnormal and not incoming and h.FloorMaterial~=Enum.Material.Air and horizontal<math.min(60,State.antiFlingSelfSpeed*.6) and spin<12 then
  if now-guard.lastSafe>.18 then
   guard.safeCFrame=r.CFrame
   guard.lastSafe=now
  end
 end
 local fallen=State.antiVoid and r.Position.Y<State.antiVoidHeight
 if (abnormal or incoming or fallen) and (now-guard.lastRecover>.55)then
  guard.lastRecover=now
  guard.recoveries+=1
  r.AssemblyAngularVelocity=Vector3.zero
  r.AssemblyLinearVelocity=Vector3.zero
  if (State.antiFlingRollback or fallen) and guard.safeCFrame and now-guard.lastSafe<40 then
   r.CFrame=guard.safeCFrame+Vector3.new(0,3,0)
  end
  if State.antiFlingAlert and guard.recoveries<=3 then
   toast("防护已触发","异常速度已阻断 · 累计 "..guard.recoveries.." 次","shield-check")
  end
 end
end
local function setPerformance(enabled)
 if enabled then
  local count=0
  for _,obj in ipairs(workspace:GetDescendants())do
   if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
      or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
    if perfSaved[obj]==nil then perfSaved[obj]={property="Enabled",value=obj.Enabled} end
    obj.Enabled=false
    count+=1
   elseif obj:IsA("BasePart") and obj.CastShadow then
    if perfSaved[obj]==nil then perfSaved[obj]={property="CastShadow",value=obj.CastShadow} end
    obj.CastShadow=false
    count+=1
   end
   if count>=math.clamp(State.perfEffectsLimit,200,7000) then break end
  end
 else
  for obj,original in pairs(perfSaved)do
   if obj.Parent then pcall(function()obj[original.property]=original.value end)end
   perfSaved[obj]=nil
  end
 end
end

-- Compact horizontal one-line overlay with vertical separators
local hudContentWidth=230
local hudHeight=32
local function makeHud()
 if not overlay or not overlay.Parent then return end
 local parent=overlay.Parent
 local previous=parent:FindFirstChild("NexusInfoHUD")
 if previous then previous:Destroy()end
 hudGui=Instance.new("ScreenGui")
 hudGui.Name="NexusInfoHUD"
 hudGui.IgnoreGuiInset=true
 hudGui.ResetOnSpawn=false
 hudGui.DisplayOrder=150
 hudGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 hudGui.Parent=parent
 hudPanel=Instance.new("Frame")
 hudPanel.Name="DraggableStatus"
 hudPanel.Active=true
 hudPanel.BorderSizePixel=0
 hudPanel.BackgroundColor3=Color3.fromRGB(17,22,32)
 hudPanel.BackgroundTransparency=State.hudOpacity
 hudPanel.Size=UDim2.fromOffset(hudContentWidth,hudHeight)
 local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
 if State.hudX<0 then State.hudX=math.max(8,viewport.X-hudContentWidth*State.hudScale-18)end
 if State.hudY<0 then State.hudY=57 end
 State.hudX=math.clamp(State.hudX,0,math.max(0,viewport.X-hudContentWidth*State.hudScale))
 State.hudY=math.clamp(State.hudY,0,math.max(0,viewport.Y-hudHeight*State.hudScale))
 hudPanel.Position=UDim2.fromOffset(State.hudX,State.hudY)
 hudPanel.Parent=hudGui
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,10)
 corner.Parent=hudPanel
 local stroke=Instance.new("UIStroke")
 stroke.Name="SoftBorder"
 stroke.Color=Color3.fromRGB(71,87,112)
 stroke.Thickness=1
 stroke.Transparency=0.62
 stroke.Parent=hudPanel
 hudScale=Instance.new("UIScale")
 hudScale.Scale=State.hudScale
 hudScale.Parent=hudPanel
 hudAccentLine=Instance.new("Frame")
 hudAccentLine.Name="Accent"
 hudAccentLine.AnchorPoint=Vector2.new(0,0.5)
 hudAccentLine.Position=UDim2.new(0,10,0.5,0)
 hudAccentLine.Size=UDim2.fromOffset(3,12)
 hudAccentLine.BorderSizePixel=0
 hudAccentLine.BackgroundColor3=State.hudAccent
 hudAccentLine.Parent=hudPanel
 local rounded=Instance.new("UICorner")
 rounded.CornerRadius=UDim.new(1,0)
 rounded.Parent=hudAccentLine
 hudMetric=Instance.new("TextLabel")
 hudMetric.Name="Metrics"
 hudMetric.BackgroundTransparency=1
 hudMetric.Position=UDim2.fromOffset(22,0)
 hudMetric.Size=UDim2.new(1,-33,1,0)
 hudMetric.Font=Enum.Font.GothamMedium
 hudMetric.TextSize=12
 hudMetric.TextColor3=Color3.fromRGB(238,243,252)
 hudMetric.TextXAlignment=Enum.TextXAlignment.Left
 hudMetric.TextYAlignment=Enum.TextYAlignment.Center
 hudMetric.TextWrapped=false
 hudMetric.TextTruncate=Enum.TextTruncate.AtEnd
 hudMetric.Text="FPS -- │ 玩家 --"
 hudMetric.Parent=hudPanel
 hudHeading=nil
 hudDetails=nil
 connect(hudPanel.InputBegan,function(input)
  if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
  hudDrag.active=true;hudDrag.start=input.Position;hudDrag.pointer=input
  hudDrag.origin=hudPanel.Position
 end)
 connect(UIS.InputChanged,function(input)
  if not hudDrag.active or not hudPanel or not hudPanel.Parent then return end
  if input~=hudDrag.pointer and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
  local delta=input.Position-hudDrag.start
  local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
  local x=math.clamp(hudDrag.origin.X.Offset+delta.X,0,math.max(0,vp.X-hudContentWidth*State.hudScale))
  local y=math.clamp(hudDrag.origin.Y.Offset+delta.Y,0,math.max(0,vp.Y-hudHeight*State.hudScale))
  hudPanel.Position=UDim2.fromOffset(x,y)
  State.hudX=x;State.hudY=y
 end)
 connect(UIS.InputEnded,function(input)
  if input==hudDrag.pointer or (hudDrag.active and input.UserInputType==Enum.UserInputType.MouseButton1)then
   hudDrag.active=false;hudDrag.pointer=nil
   saveHUDPosition()
  end
 end)
end
local function refreshHud()
 if not hudPanel then return end
 hudPanel.Visible=State.hudEnabled
 if not State.hudEnabled then return end
 if hudScale then hudScale.Scale=State.hudScale end
 if hudAccentLine then hudAccentLine.BackgroundColor3=State.hudAccent end
 hudPanel.BackgroundTransparency=State.hudOpacity
 local items={"FPS "..tostring(fps),"玩家 "..tostring(#Players:GetPlayers()).."/"..tostring(Players.MaxPlayers)}
 if not State.hudCompact then
  if State.hudShowPing then
   local ping=localPing()
   table.insert(items,ping and (ping.."ms") or "--ms")
  end
  if State.hudShowHealth then
   local h=humanoid()
   table.insert(items,"HP "..(h and tostring(math.floor(h.Health)) or "--"))
  end
  if State.hudFeatures then
   if App.Music and App.Music.Sound and App.Music.Sound.IsPlaying then
    local song=App.Music.Current()
    if song then table.insert(items,"音乐 "..song.title:sub(1,12))end
   end
   if State.antiAim then table.insert(items,"反自瞄")end
   if State.blackHole then table.insert(items,"黑洞 "..combatEffects.holeScans)end
   if State.touchKill then table.insert(items,"触碰模式")end
   if State.fling then table.insert(items,"甩飞")end
   if State.aim then
    local targetName=currentAimTarget and currentAimTarget.Parent and currentAimTarget.Name or nil
    if targetName and State.hudAimTarget then
     targetName=targetName:sub(1,15)
     table.insert(items,"自瞄 @"..targetName)
    else
     table.insert(items,"自瞄 搜索中")
    end
   end
   if State.fly then table.insert(items,"飞行")end
   if State.noclip then table.insert(items,"穿墙")end
   if State.antiFling then table.insert(items,"防甩飞")end
   if State.projectileTrace then table.insert(items,"弹道")end
   if State.clickTP then table.insert(items,"点击传送")end
  end
 end
 local line=table.concat(items,"  │  ")
 hudMetric.Text=line
 local bounds=game:GetService("TextService"):GetTextSize(line,12,Enum.Font.GothamMedium,Vector2.new(1000,30))
 local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
 hudContentWidth=math.min(math.ceil(bounds.X)+36,math.max(125,vp.X/State.hudScale-16))
 hudPanel.Size=UDim2.fromOffset(hudContentWidth,hudHeight)
 if not hudDrag.active then
  local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
  local x=math.clamp(hudPanel.Position.X.Offset,0,math.max(0,vp.X-hudContentWidth*State.hudScale))
  local y=math.clamp(hudPanel.Position.Y.Offset,0,math.max(0,vp.Y-hudHeight*State.hudScale))
  hudPanel.Position=UDim2.fromOffset(x,y)
  State.hudX=x;State.hudY=y
 end
end


App.RefreshHUD=refreshHud
-- ============= RAIN HUB: AIM / PROJECTILE VISUALIZATION =============
local aimAccum=0
currentAimTarget=nil
local function aimPart(p)
 local c=char(p)
 if not c then return nil end
 if State.aimPart=="躯干" then
  return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or hrp(p)
 elseif State.aimPart=="根部" then return hrp(p)
 end
 return c:FindFirstChild("Head") or hrp(p)
end
local function aimVisible(camera,p,part)
 if not State.aimWallCheck then return true end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local exclusions={}
 if char() then table.insert(exclusions,char())end
 params.FilterDescendantsInstances=exclusions
 params.IgnoreWater=true
 local diff=part.Position-camera.CFrame.Position
 if diff.Magnitude<.1 then return true end
 local hit=workspace:Raycast(camera.CFrame.Position,diff,params)
 return not hit or (char(p) and hit.Instance:IsDescendantOf(char(p)))
end
local function chooseAimTarget()
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local cursor
 if State.aimCenterMode=="屏幕中央"then
  cursor=camera.ViewportSize/2
 else
  cursor=UIS:GetMouseLocation()
 end
 local best,bestDist=nil,State.aimRadius
 local from=hrp()
 for _,p in ipairs(otherPlayers())do
  local part=aimPart(p)
  local h=humanoid(p)
  if part and (not State.aimAliveOnly or (h and h.Health>0))
     and (not State.aimTeamCheck or LP.Team==nil or p.Team~=LP.Team)then
   local dist=from and (part.Position-from.Position).Magnitude or math.huge
   if dist<=State.aimMaxDistance then
    local point,onScreen=camera:WorldToViewportPoint(part.Position)
    if onScreen and point.Z>0 then
     local screenDist=(Vector2.new(point.X,point.Y)-cursor).Magnitude
     if screenDist<bestDist and aimVisible(camera,p,part)then
      bestDist=screenDist
      best=p
     end
    end
   end
  end
 end
 return best
end
local function makeAimOverlay()
 if not overlay then return end
 aimCircle=Instance.new("Frame")
 aimCircle.Name="RainHub_AimRadius"
 aimCircle.AnchorPoint=Vector2.new(.5,.5)
 aimCircle.Size=UDim2.fromOffset(State.aimRadius*2,State.aimRadius*2)
 aimCircle.BackgroundTransparency=1
 aimCircle.BorderSizePixel=0
 aimCircle.Visible=false
 aimCircle.Parent=overlay
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(1,0)
 corner.Parent=aimCircle
 local edge=Instance.new("UIStroke")
 edge.Thickness=1.5
 edge.Color=Color3.fromRGB(75,180,255)
 edge.Transparency=.3
 edge.Parent=aimCircle
 aimTargetLabel=Instance.new("TextLabel")
 aimTargetLabel.Name="RainHub_AimStatus"
 aimTargetLabel.BackgroundColor3=Color3.fromRGB(15,25,37)
 aimTargetLabel.BackgroundTransparency=.25
 aimTargetLabel.Size=UDim2.fromOffset(180,22)
 aimTargetLabel.AnchorPoint=Vector2.new(.5,0)
 aimTargetLabel.Font=Enum.Font.GothamMedium
 aimTargetLabel.TextSize=11
 aimTargetLabel.TextColor3=Color3.fromRGB(203,232,255)
 aimTargetLabel.Visible=false
 aimTargetLabel.Parent=overlay
 local c=Instance.new("UICorner")
 c.CornerRadius=UDim.new(0,7);c.Parent=aimTargetLabel
 App.AimLockCircle=Instance.new("Frame")
 App.AimLockCircle.Name="RainHub_TargetLockRing"
 App.AimLockCircle.AnchorPoint=Vector2.new(.5,.5)
 App.AimLockCircle.Size=UDim2.fromOffset(56,56)
 App.AimLockCircle.BackgroundTransparency=1
 App.AimLockCircle.Visible=false
 App.AimLockCircle.ZIndex=8
 App.AimLockCircle.Parent=overlay
 local lockCorner=Instance.new("UICorner")
 lockCorner.CornerRadius=UDim.new(1,0);lockCorner.Parent=App.AimLockCircle
 local lockStroke=Instance.new("UIStroke")
 lockStroke.Color=Color3.fromRGB(97,245,188)
 lockStroke.Transparency=.05
 lockStroke.Thickness=2.5
 lockStroke.Parent=App.AimLockCircle
end
local function aimFrame(dt)
 local camera=workspace.CurrentCamera
 if not camera or not aimCircle then return end
 local mouse=State.aimCenterMode=="屏幕中央" and camera.ViewportSize/2 or UIS:GetMouseLocation()
 aimCircle.Position=UDim2.fromOffset(mouse.X,mouse.Y)
 aimCircle.Size=UDim2.fromOffset(State.aimRadius*2,State.aimRadius*2)
 aimCircle.Visible=State.aim and State.aimShowRadius
 aimTargetLabel.Position=UDim2.fromOffset(mouse.X,mouse.Y+State.aimRadius+8)
 aimTargetLabel.Visible=State.aim and State.aimShowTarget
 if not State.aim then
  currentAimTarget=nil
  if App.AimLockCircle then App.AimLockCircle.Visible=false end
  return
 end
 aimAccum+=dt
 local scanInterval=math.max(0.04,tonumber(State.perfAimInterval) or 0.10)
 if State.perfAutoAdjust and fps<45 then scanInterval*=1.6 end
 if aimAccum>=scanInterval then
  aimAccum=0
  local nextTarget=chooseAimTarget()
  if State.aimSticky and currentAimTarget and currentAimTarget.Parent then
   local oldPart=aimPart(currentAimTarget)
   if oldPart then
    local point,onScreen=camera:WorldToViewportPoint(oldPart.Position)
    if onScreen and point.Z>0 and (Vector2.new(point.X,point.Y)-mouse).Magnitude<=State.aimRadius
      and aimVisible(camera,currentAimTarget,oldPart)then nextTarget=currentAimTarget end
   end
  end
  currentAimTarget=nextTarget
 end
 aimTargetLabel.Text=currentAimTarget and ("锁定候选 | @"..currentAimTarget.Name) or "范围内无可用目标"
 if App.AimLockCircle then
  App.AimLockCircle.Visible=false
  if State.aimLockRing and currentAimTarget then
   local targetPart=aimPart(currentAimTarget)
   if targetPart then
    local point,onScreen=camera:WorldToViewportPoint(targetPart.Position)
    if onScreen and point.Z>0 then
     App.AimLockCircle.Visible=true
     App.AimLockCircle.Position=UDim2.fromOffset(point.X,point.Y)
     local px=math.clamp(State.aimLockRadius,9,95)*2
     App.AimLockCircle.Size=UDim2.fromOffset(px,px)
    end
   end
  end
 end
 local active=(not State.aimHold) or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
 if active and currentAimTarget then
  local part=aimPart(currentAimTarget)
  if part then
   local targetCF=CFrame.lookAt(camera.CFrame.Position,part.Position)
   local alpha=math.clamp(dt*State.aimSmooth,0,1)
   camera.CFrame=camera.CFrame:Lerp(targetCF,alpha)
  end
 end
end
local BULLET_KEYS={"bullet","projectile","arrow","rocket","missile","laser","shot","bolt","shell","子弹","飞弹","炮弹"}
local function clearProjectiles()
 for part,item in pairs(projectileTrails)do
  for _,instance in ipairs(item)do
   pcall(function()instance:Destroy()end)
  end
  projectileTrails[part]=nil
 end
 trackedCount=0
end
local function maybeTraceProjectile(part)
 if not State.projectileTrace or not part:IsA("BasePart") or part.Anchored
    or projectileTrails[part] or trackedCount>=26 then return end
 for _,p in ipairs(Players:GetPlayers())do
  local model=char(p)
  if model and part:IsDescendantOf(model) then return end
 end
 local name=part.Name:lower()
 local named=false
 for _,word in ipairs(BULLET_KEYS)do
  if name:find(word,1,true) then named=true;break end
 end
 local size=part.Size
 local speed=part.AssemblyLinearVelocity.Magnitude
 if not named and not (speed>120 and size.Magnitude<5) then return end
 local me=hrp()
 if me and (part.Position-me.Position).Magnitude>1100 then return end
 local a=Instance.new("Attachment");a.Name="RainTraceA";a.Position=Vector3.new(0,.1,0)
 local b=Instance.new("Attachment");b.Name="RainTraceB";b.Position=Vector3.new(0,-.1,0)
 local trail=Instance.new("Trail")
 trail.Name="RainHub_BulletTracer"
 trail.Attachment0=a;trail.Attachment1=b
 trail.FaceCamera=true
 trail.Color=ColorSequence.new(State.projectileColor)
 trail.Lifetime=State.projectileLifetime
 trail.LightEmission=.85
 trail.MinLength=.1
 trail.Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,.03),
  NumberSequenceKeypoint.new(1,1)
 })
 a.Parent=part;b.Parent=part;trail.Parent=part
 projectileTrails[part]={trail,a,b}
 trackedCount+=1
end
local function scanProjectiles()
 if not State.projectileTrace then return end
 local count=0
 for _,v in ipairs(workspace:GetDescendants())do
  if v:IsA("BasePart") then maybeTraceProjectile(v) end
  count+=1
  if count>3800 or trackedCount>=26 then break end
 end
end
local function updateProjectiles()
 for part,objects in pairs(projectileTrails)do
  if not State.projectileTrace or not part.Parent then
   for _,v in ipairs(objects)do pcall(function()v:Destroy()end)end
   projectileTrails[part]=nil
   trackedCount=math.max(0,trackedCount-1)
  else
   local t=objects[1]
   if t then
    t.Lifetime=State.projectileLifetime
    t.Color=ColorSequence.new(State.projectileColor)
   end
  end
 end
end


-- ============= RAIN HUB: PLAYER BADGES / LOCAL TOOLS =============
local RAIN_BADGE_SELF="雨🌧️脚本用户"
local markedPlayers={}
local function removeBadge(p)
 local old=markedTags[p]
 if old then pcall(function()old:Destroy()end)end
 markedTags[p]=nil
end
local function makeBadge(p,own)
 removeBadge(p)
 local playerGui=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",8)
 if not playerGui then return end
 local model=char(p)
 local head=model and (model:FindFirstChild("Head") or hrp(p))
 if not head then return end
 local billboard=Instance.new("BillboardGui")
 billboard.Name="RainHubUserBadge"
 billboard.Adornee=head
 billboard.AlwaysOnTop=true
 billboard.ResetOnSpawn=false
 billboard.Enabled=true
 billboard.LightInfluence=0
 billboard.MaxDistance=0
 billboard.Size=UDim2.fromOffset(176,35)
 billboard.StudsOffsetWorldSpace=Vector3.new(0,2.7,0)
 billboard.Parent=playerGui
 local frame=Instance.new("Frame")
 frame.BackgroundColor3=Color3.fromRGB(18,24,39)
 frame.BackgroundTransparency=.08
 frame.Size=UDim2.fromScale(1,1)
 frame.BorderSizePixel=0
 frame.Parent=billboard
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,10)
 corner.Parent=frame
 local stroke=Instance.new("UIStroke")
 stroke.Thickness=1.4
 stroke.Color=Color3.fromRGB(95,195,255)
 stroke.Transparency=.18
 stroke.Parent=frame
 local gradient=Instance.new("UIGradient")
 gradient.Color=ColorSequence.new({
  ColorSequenceKeypoint.new(0,Color3.fromRGB(26,51,83)),
  ColorSequenceKeypoint.new(1,Color3.fromRGB(41,31,70))
 })
 gradient.Rotation=20
 gradient.Parent=frame
 local text=Instance.new("TextLabel")
 text.BackgroundTransparency=1
 text.Size=UDim2.fromScale(1,1)
 text.Text=own and RAIN_BADGE_SELF or "雨 Hub • 本地标记"
 text.Font=Enum.Font.GothamBold
 text.TextScaled=true
 text.TextColor3=Color3.fromRGB(225,243,255)
 text.TextStrokeTransparency=.65
 text.Parent=frame
 local padding=Instance.new("UIPadding")
 padding.PaddingLeft=UDim.new(0,8)
 padding.PaddingRight=UDim.new(0,8)
 padding.PaddingTop=UDim.new(0,7)
 padding.PaddingBottom=UDim.new(0,7)
 padding.Parent=frame
 local scale=Instance.new("UIScale")
 scale.Scale=State.tagScale
 scale.Parent=frame
 markedTags[p]=billboard
end
local function rebuildBadges()
 for p in pairs(markedTags)do removeBadge(p)end
 if State.selfTag then makeBadge(LP,true)end
 if State.showMarkedTags then
  for p in pairs(markedPlayers)do
   if p.Parent and p~=LP then makeBadge(p,false)end
  end
 end
end
-- Keep the local badge attached after respawn / delayed character assembly.
local badgeWatchClock=0
connect(RS.Heartbeat,function(dt)
 if not App.Running then return end
 badgeWatchClock+=dt
 if badgeWatchClock<1.5 then return end
 badgeWatchClock=0
 local ownGui=LP:FindFirstChildOfClass("PlayerGui")
 local ownChar=char()
 local ownHead=ownChar and (ownChar:FindFirstChild("Head") or ownChar:FindFirstChild("HumanoidRootPart"))
 local shown=markedTags[LP]
 if State.selfTag and ownGui and ownHead then
  if not shown or not shown.Parent or shown.Parent~=ownGui or shown.Adornee~=ownHead or not shown.Enabled then
   makeBadge(LP,true)
  end
 elseif not State.selfTag and shown then
  removeBadge(LP)
 end
end)

local function makeTool(name,tip,handler)
 local bp=LP:FindFirstChildOfClass("Backpack") or LP:WaitForChild("Backpack",5)
 if not bp then toast("道具失败","未找到 Roblox 背包","alert-circle")return nil end
 if #ownedTools>=32 then toast("道具数量过多","请先清理雨 Hub 创建的道具","alert-circle")return nil end
 local tool=Instance.new("Tool")
 tool.Name=name
 tool.ToolTip=tip
 tool.RequiresHandle=false
 tool.CanBeDropped=false
 tool:SetAttribute("RainHubLocalTool",true)
 tool.Parent=bp
 table.insert(ownedTools,tool)
 connect(tool.Activated,function()
  if not App.Running then return end
  local ok,err=pcall(handler,tool)
  if not ok then toast("道具执行失败",tostring(err),"alert-circle")end
 end)
 return tool
end
local toolReturnPosition=nil
local function giveClickTeleport()
 local tool=makeTool("雨 Hub 🌧️ | 点击传送","装备后点击地面进行客户端传送",function()
  local mouse=LP:GetMouse()
  local target=mouse and mouse.Hit
  if target then
   teleport(target+Vector3.new(0,3.5,0))
  else toast("传送未执行","请瞄准可点击的地面","alert-circle")end
 end)
 if tool then toast("道具已发放","装备「点击传送」，点击地面使用","map-pin")end
end
local function givePositionTool()
 local tool=makeTool("雨 Hub 🌧️ | 记录/回程","第一次点击记录位置，之后点击返回，再次记录请重新领取",function()
  if not toolReturnPosition then
   local root=hrp()
   if root then toolReturnPosition=root.CFrame;toast("位置记录","已记住当前位置","bookmark")end
  else
   teleport(toolReturnPosition)
   toast("回程工具","已尝试返回记录地点","map-pin")
  end
 end)
 if tool then toast("道具已发放","先点击记录位置，再次点击返回","bookmark")end
end
local function giveWallTool()
 local tool=makeTool("雨 Hub 🌧️ | 穿墙切换","装备后点击切换本地无碰撞",function()
  State.noclip=not State.noclip
  if not State.noclip then restoreParts(App.noclipParts,"CanCollide")end
  toast("穿墙模式",State.noclip and "已开启" or "已关闭","layers")
 end)
 if tool then toast("道具已发放","装备后点击切换穿墙","layers")end
end
local function giveFlyTool()
 local tool=makeTool("雨 Hub 🌧️ | 飞行切换","装备后点击切换客户端飞行",function()
  State.fly=not State.fly
  if State.fly then startFly()else stopFly()end
  toast("飞行模式",State.fly and "已开启" or "已关闭","wind")
 end)
 if tool then toast("道具已发放","装备后点击切换飞行","wind")end
end
local function duplicateHeldTool(selectedName)
 local bag=LP:FindFirstChildOfClass("Backpack")
 local c=char()
 local source=nil
 if selectedName and selectedName~="" then
  for _,container in ipairs({bag,c})do
   if container then
    for _,obj in ipairs(container:GetChildren())do
     if obj:IsA("Tool") and obj.Name==selectedName and not obj:GetAttribute("RainHubLocalTool") then source=obj;break end
    end
   end
   if source then break end
  end
 end
 if not source and c then
  for _,obj in ipairs(c:GetChildren())do
   if obj:IsA("Tool") and not obj:GetAttribute("RainHubLocalTool")then source=obj;break end
  end
 end
 if not source and bag then
  for _,obj in ipairs(bag:GetChildren())do
   if obj:IsA("Tool") and not obj:GetAttribute("RainHubLocalTool")then source=obj;break end
  end
 end
 if not source or not bag then toast("本地复制失败","请装备或携带一个工具物品","alert-circle")return end
 local success,replica=pcall(function()return source:Clone()end)
 if not success or not replica then toast("无法复制","该物品禁止克隆或不可访问","alert-circle")return end
 -- Prevent duplicated unknown scripts from executing; replica is visual/client-only.
 for _,obj in ipairs(replica:GetDescendants())do
  if obj:IsA("LuaSourceContainer")then obj:Destroy()end
 end
 replica.Name=source.Name.." · 雨 Hub 本地副本"
 replica:SetAttribute("RainHubLocalTool",true)
 replica.CanBeDropped=false
 replica.Parent=bag
 table.insert(ownedTools,replica)
 toast("本地复制完成","仅复制本地模型；服务器不会授予额外物品或道具能力","copy")
end
local function removeOwnedTools()
 for i=#ownedTools,1,-1 do
  local tool=ownedTools[i]
  if tool then pcall(function()tool:Destroy()end)end
  ownedTools[i]=nil
 end
 toolReturnPosition=nil
end

do
-- Rain Hub v2.2: client-side rotation and local loose-part gravity
local function stopAntiAim()
 State.antiAim=false
 local h=humanoid()
 if h and combatEffects.antiAimAutoRotate~=nil then pcall(function()h.AutoRotate=combatEffects.antiAimAutoRotate end)end
 combatEffects.antiAimAutoRotate=nil
 combatEffects.antiAimClock=0
end
local function setAntiAim(v)
 if not v then stopAntiAim();return end
 if State.selfSpin then State.selfSpin=false;local h=humanoid();if h and combatEffects.selfSpinAutoRotate~=nil then h.AutoRotate=combatEffects.selfSpinAutoRotate end;combatEffects.selfSpinAutoRotate=nil end
 State.antiAim=true
 local h=humanoid()
 if h and combatEffects.antiAimAutoRotate==nil then combatEffects.antiAimAutoRotate=h.AutoRotate end
end
local function stopBlackHole()
 State.blackHole=false
 combatEffects.holeTargets={};combatEffects.holeQueue=nil;combatEffects.holeSeen=setmetatable({},{__mode="k"})
 if combatEffects.holePart then pcall(function()combatEffects.holePart:Destroy()end)end
 combatEffects.holePart=nil;combatEffects.holeGlow=nil
 combatEffects.holeScans=0
end
local function startBlackHole()
 stopBlackHole()
 State.blackHole=true
 local orb=Instance.new("Part")
 orb.Name="RainHub_LocalBlackHole"
 orb.Shape=Enum.PartType.Ball
 orb.Size=Vector3.new(5,5,5)
 orb.Anchored=true;orb.CanCollide=false;orb.CanTouch=false
 orb.CanQuery=false;orb.Material=Enum.Material.Neon
 orb.Color=Color3.fromRGB(39,26,83);orb.Transparency=.15
 orb.CastShadow=false;orb.Parent=workspace
 local light=Instance.new("PointLight")
 light.Color=Color3.fromRGB(145,85,255)
 light.Range=20;light.Brightness=2;light.Parent=orb
 local p=Instance.new("ParticleEmitter")
 p.Name="RainHubBlackHoleAura"
 p.Color=ColorSequence.new(Color3.fromRGB(135,85,245))
 p.Texture="rbxasset://textures/particles/sparkles_main.dds"
 p.Speed=NumberRange.new(.5,2)
 p.Rate=30;p.Lifetime=NumberRange.new(.3,1.2)
 p.LightEmission=.7
 p.Parent=orb
 combatEffects.holePart=orb;combatEffects.holeGlow=p
 combatEffects.holeLastScan=-100;combatEffects.holeClock=0
 toast("全场物品漩涡","分批扫描已加载的未锚定物体并吸附环绕；服务器权限可能限制效果","orbit")
end
local function blackHoleStep(dt)
 local fx=combatEffects
 local orb=fx.holePart
 local root=hrp()
 if not State.blackHole or not orb or not orb.Parent or not root then return end
 local center=root.Position+Vector3.new(0,State.blackHoleHeight,0)
 if State.blackHoleMode=="角色前方"then center+=root.CFrame.LookVector*State.blackHoleOffset
 elseif State.blackHoleMode=="鼠标指向"then
  local mouse=LP:GetMouse()
  if mouse and mouse.Hit then center=mouse.Hit.Position end
 end
 orb.Position=center
 orb.Transparency=State.blackHoleVisual and .15 or 1
 if fx.holeGlow then fx.holeGlow.Enabled=State.blackHoleVisual end
 fx.holeClock+=dt
 -- Snapshot the loaded world at a low frequency, then scan only a bounded batch each frame.
 if not fx.holeQueue and os.clock()-fx.holeLastScan>8 then
  fx.holeQueue=workspace:GetDescendants()
  fx.holeCursor=1
  fx.holeLastScan=os.clock()
 end
 local function eligible(part)
  if not part or not part.Parent or not part:IsA("BasePart") or part.Anchored
    or part==orb or part.AssemblyMass>State.blackHoleMaxMass then return false end
  if State.blackHoleRadius>0 and (part.Position-center).Magnitude>State.blackHoleRadius then return false end
  local model=part:FindFirstAncestorOfClass("Model")
  if model and model:FindFirstChildOfClass("Humanoid")then return false end
  if part:FindFirstAncestorOfClass("Tool") then return false end
  return true
 end
 local scanBudget=math.clamp(math.floor(State.blackHoleMaxParts),20,700)
 local endIndex=math.min(#fx.holeQueue,fx.holeCursor+scanBudget-1)
 for i=fx.holeCursor,endIndex do
  local part=fx.holeQueue[i]
  if eligible(part) and not fx.holeSeen[part]then
   fx.holeSeen[part]=true
   if #fx.holeTargets<12000 then table.insert(fx.holeTargets,part)end
  end
 end
 fx.holeCursor=endIndex+1
 if fx.holeCursor>#fx.holeQueue then fx.holeQueue=nil end
 if #fx.holeTargets==0 then fx.holeScans=0;return end
 -- Continuously pull loose assemblies into separate slots on concentric orbit rings.
 local processed=0
 local orbit=fx.holeClock*math.clamp(State.blackHoleOrbitSpeed,0,50)
 local maxActive=math.clamp(math.floor(State.blackHoleMaxParts),10,700)
 for _=1,math.min(maxActive,#fx.holeTargets) do
  if fx.holeTargetCursor>#fx.holeTargets then fx.holeTargetCursor=1 end
  local index=fx.holeTargetCursor
  local part=fx.holeTargets[index]
  if not eligible(part)then
   fx.holeSeen[part]=nil
   table.remove(fx.holeTargets,index)
  else
   fx.holeTargetCursor+=1
   local phase=index*2.3999632297+orbit
   local ring=3+math.floor((index-1)/18)*1.15
   local height=math.sin(index*1.7+orbit*.4)*2
   local target=center+Vector3.new(math.cos(phase)*ring,height,math.sin(phase)*ring)
   local offset=target-part.Position
   local force=math.clamp(State.blackHoleStrength,20,600)
   local velocity=offset*math.min(force/9,55)
   if velocity.Magnitude>force then velocity=velocity.Unit*force end
   pcall(function()
    part.AssemblyLinearVelocity=velocity
    part.AssemblyAngularVelocity=Vector3.new(0,math.clamp(State.blackHoleOrbitSpeed,0,50),0)
   end)
   processed+=1
  end
 end
 fx.holeScans=processed
end
-- Touch effect: local Humanoid health only; the server may ignore it.
local function disconnectTouchKill()
 for _,con in ipairs(combatEffects.touchCons)do pcall(function()con:Disconnect()end)end
 table.clear(combatEffects.touchCons)
 combatEffects.touchCharacter=nil
end
local function attachTouchKill()
 disconnectTouchKill()
 local c=char()
 if not c or not State.touchKill then return end
 combatEffects.touchCharacter=c
 local lastTouch={}
 for _,part in ipairs(c:GetDescendants())do
  if part:IsA("BasePart")then
   local con=part.Touched:Connect(function(hit)
    if not State.touchKill or not hit or not hit.Parent then return end
    local model=hit:FindFirstAncestorOfClass("Model")
    if not model or model==char()then return end
    local h=model:FindFirstChildOfClass("Humanoid")
    if not h or h.Health<=0 or os.clock()-(lastTouch[h] or 0)<1 then return end
    lastTouch[h]=os.clock()
    State.touchKillCount+=1
    pcall(function()h.Health=0 end)
    if State.touchKillCount<=4 then
     toast("本地触碰效果","触碰到 "..model.Name.."；服务器伤害结果可能不同","alert-circle")
    end
   end)
   table.insert(combatEffects.touchCons,con)
  end
 end
end
local function setTouchKill(v)
 State.touchKill=v
 if v then attachTouchKill()else disconnectTouchKill()end
end
-- Short-duration character spin for local physics interaction.
local function stopFling()
 State.fling=false
 combatEffects.flingActive=false
 combatEffects.flingEnd=0
 if combatEffects.flingForce then pcall(function()combatEffects.flingForce:Destroy()end)end
 combatEffects.flingForce=nil
 local root=hrp()
 if root then pcall(function()root.AssemblyAngularVelocity=Vector3.zero end)end
end
local function startFling()
 local root,h=hrp(),humanoid()
 if not root or not h or h.Health<=0 then return false,"角色未就绪"end
 if State.fly then return false,"飞行状态下无法启动物理旋转"end
 if combatEffects.flingActive then return false,"物理旋转正在执行"end
 if os.clock()-State.flingLast<math.max(1,State.flingCooldown)then return false,"正在冷却"end
 State.antiFling=false
 restoreParts(App.flingParts,"CanCollide")
 State.flingLast=os.clock()
 State.fling=true
 combatEffects.flingActive=true
 combatEffects.flingEnd=os.clock()+math.clamp(State.flingDuration,.2,6)
 local spin=Instance.new("BodyAngularVelocity")
 spin.Name="RainHub_PhysicsSpin"
 spin.MaxTorque=Vector3.new(0,1e9,0)
 spin.P=15000
 spin.AngularVelocity=Vector3.new(0,State.flingSpeed,0)
 spin.Parent=root
 combatEffects.flingForce=spin
 toast("物理甩飞","已开始短时旋转，是否影响其他角色取决于服务器物理规则","rotate-cw")
 return true
end

local function setSelfSpin(enabled)
 State.selfSpin=enabled==true
 local h=humanoid()
 if State.selfSpin then
  stopAntiAim()
  if h and combatEffects.selfSpinAutoRotate==nil then combatEffects.selfSpinAutoRotate=h.AutoRotate end
 elseif h and combatEffects.selfSpinAutoRotate~=nil then
  pcall(function()h.AutoRotate=combatEffects.selfSpinAutoRotate end)
  combatEffects.selfSpinAutoRotate=nil
 end
end
local function physicsCombatStep(dt)
 if State.selfSpin and not State.fly and not State.fling then
  local h,r=humanoid(),hrp()
  if h and r and h.Health>0 then
   if combatEffects.selfSpinAutoRotate==nil then combatEffects.selfSpinAutoRotate=h.AutoRotate end
   h.AutoRotate=false
   local radians=math.rad(math.clamp(State.selfSpinSpeed,-100000,100000))*math.min(dt,.08)
   pcall(function()r.CFrame=r.CFrame*CFrame.Angles(0,radians,0)end)
  end
 end
 if not App.Running then return end
 if State.antiAim and not State.fling and not State.fly then
  local h,r=humanoid(),hrp()
  if h and r and h.Health>0 then
   if combatEffects.antiAimAutoRotate==nil then combatEffects.antiAimAutoRotate=h.AutoRotate end
   h.AutoRotate=false
   combatEffects.antiAimClock+=dt
   local angle
   if State.antiAimStyle=="旋转"then
    angle=combatEffects.antiAimClock*math.rad(math.clamp(State.antiAimSpeed,0,100)*50)
   else
    angle=math.rad(math.clamp(State.antiAimAngle,0,25))*math.sin(combatEffects.antiAimClock*math.max(.1,State.antiAimSpeed)*2)
   end
   local direction=workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or r.CFrame.LookVector
   local flat=Vector3.new(direction.X,0,direction.Z)
   if flat.Magnitude>.01 then
    pcall(function()r.CFrame=CFrame.lookAt(r.Position,r.Position+flat)*CFrame.Angles(0,angle,0)end)
   end
  end
 end
 if State.blackHole then blackHoleStep(dt)end
 if combatEffects.flingActive then
  local root=hrp()
  if not root or os.clock()>=combatEffects.flingEnd then stopFling()
  elseif combatEffects.flingForce then
   combatEffects.flingForce.AngularVelocity=Vector3.new(0,State.flingSpeed,0)
   if State.flingApproach then
    local p=lookup(State.target)
    local trg=p and hrp(p)
    if trg then
     local diff=trg.Position-root.Position
     if diff.Magnitude>3 and diff.Magnitude<70 then
      pcall(function()root.AssemblyLinearVelocity=diff.Unit*math.min(90,diff.Magnitude*5)end)
     end
    end
   end
  end
 end
end
local function combatEmergency()
 setSelfSpin(false);setAntiAim(false);stopBlackHole();setTouchKill(false);stopFling()
 State.noclip=false;restoreParts(App.noclipParts,"CanCollide")
 State.fly=false;stopFly()
 State.aim=false;State.clickTP=false
 toast("紧急停止","物理类和对抗类功能已停用","shield-check")
end
App.CombatStop=combatEmergency

local function triggerAction(action)
 if action=="fly"then
  State.fly=not State.fly
  if State.fly then startFly()else stopFly()end
 elseif action=="noclip"then
  State.noclip=not State.noclip
  if not State.noclip then restoreParts(App.noclipParts,"CanCollide")end
 elseif action=="antiFling"then
  State.antiFling=not State.antiFling
  if not State.antiFling then restoreParts(App.flingParts,"CanCollide")end
 elseif action=="aim"then State.aim=not State.aim
 elseif action=="antiAim"then setAntiAim(not State.antiAim)
 elseif action=="selfSpin"then setSelfSpin(not State.selfSpin)
 elseif action=="blackHole"then
  if State.blackHole then stopBlackHole()else startBlackHole()end
 elseif action=="touchKill"then setTouchKill(not State.touchKill)
 elseif action=="fling"then
  local ok,msg=startFling()
  if not ok then toast("甩飞不可用",msg,"alert-circle")end
 elseif action=="clickTP"then State.clickTP=not State.clickTP
 elseif action=="emergency"then combatEmergency()
 else return false end
 if State.hotkeyHints and action~="emergency" then
  local active=action=="fling" and combatEffects.flingActive or State[action]
  toast("快捷键 · "..(App.HotkeyLabels[action] or action),active and "开启" or "关闭","keyboard")
 end
 if App.RefreshHUD then App.RefreshHUD()end
 return true
end
App.TriggerAction=triggerAction
local function setHotkey(action,raw)
 if not App.HotkeyDefaults[action]then return false,"未知功能"end
 local key=App.KeyName(raw)
 if not key then return false,"无法识别的按键"end
 if ({RightShift=true,LeftShift=true,LeftControl=true,E=true,Q=true,T=true,Escape=true})[key]then
  return false,"该键已被菜单或移动控制占用"
 end
 for name,bind in pairs(App.Hotkeys)do
  if bind==key and name~=action then App.Hotkeys[name]=nil end
 end
 App.Hotkeys[action]=key
 local saved=App.SaveHotkeys()
 toast("快捷键已绑定",App.HotkeyLabels[action].." → "..key..(saved and "（已保存）" or "（仅本次）"),"keyboard")
 return true
end
App.SetHotkey=setHotkey
App.Combat={
 StopAntiAim=stopAntiAim,SetAntiAim=setAntiAim,SetSelfSpin=setSelfSpin,
 StopBlackHole=stopBlackHole,StartBlackHole=startBlackHole,
 SetTouch=setTouchKill,AttachTouch=attachTouchKill,
 StopFling=stopFling,StartFling=startFling,
 Tick=physicsCombatStep,Emergency=combatEmergency,
 Trigger=triggerAction,SetHotkey=setHotkey
}
end

-- ============== RAIN HUB AUDIO / MUSIC LIBRARY ==============
do
 local service=game:GetService("SoundService")
 local musicPath="RainHub/music-v1.json"
 local localMusicPath="RainHub/music/default.mp3"
 local favoriteTitle="东南苦山行"
 local favoriteArtist="殷正洋"
 local playlist={{title=favoriteTitle,artist=favoriteArtist,provider="roblox",neteaseId="",robloxId="126433682497062"}}
 local index=1
 local volume=.5
 local speed=1
 local looping=false
 local autoplay=false
 local shuffle=false
 local status="准备中"
 local lastError=""
 local stopped=false
 local playSerial=0
 local openedSongId=""
 local oldSound=service:FindFirstChild("RainHub_MusicPlayer")
 if oldSound and oldSound:IsA("Sound")then oldSound:Destroy()end
 local sound=Instance.new("Sound")
 sound.Name="RainHub_MusicPlayer"
 sound.SoundId=""
 sound.Volume=volume
 sound.PlaybackSpeed=speed
 sound.Looped=looping
 sound.Parent=service
 local function current()
  return playlist[index] or playlist[1]
 end
 local function getId(value)
  local t=tostring(value or "")
  local number=t:match("rbxassetid://(%d+)") or t:match("(%d+)")
  if number and #number<21 and tonumber(number) and tonumber(number)>0 then return number end
  return nil
 end
 local function neteaseId(raw)
  local t=tostring(raw or "")
  local id=t:match("[?&]id=(%d+)") or t:match("/song/(%d+)") or t:match("^%s*(%d+)%s*$")
  return id and #id<21 and id or nil
 end
 local function save()
  if type(writefile)~="function"then return false,"执行器无本地文件写入权限"end
  return pcall(function()
   if type(makefolder)=="function"then
    if type(isfolder)~="function" or not isfolder("RainHub")then makefolder("RainHub")end
   end
   local json=game:GetService("HttpService"):JSONEncode({
    version=2,index=index,volume=volume,speed=speed,autoplay=autoplay,
    loop=looping,shuffle=shuffle,playlist=playlist
   })
   writefile(musicPath,json)
  end)
 end
 local function load()
  if type(readfile)~="function"or type(isfile)~="function"then return false end
  local ok,data=pcall(function()
   if not isfile(musicPath)then return nil end
   return game:GetService("HttpService"):JSONDecode(readfile(musicPath))
  end)
  if not ok or type(data)~="table"then return false end
  if type(data.volume)=="number"then volume=math.clamp(data.volume,0,2)end
  if type(data.speed)=="number"then speed=math.clamp(data.speed,.4,2)end
  if tonumber(data.version or 0)>=2 and type(data.autoplay)=="boolean"then autoplay=data.autoplay end
  if type(data.loop)=="boolean"then looping=data.loop end
  if type(data.shuffle)=="boolean"then shuffle=data.shuffle end
  if type(data.playlist)=="table"then
   local sanitized={}
   for _,item in ipairs(data.playlist)do
    if #sanitized>=70 then break end
    if type(item)=="table" and type(item.title)=="string" and #item.title>0 then
     local rb=getId(item.robloxId or "")
     local nid=neteaseId(item.neteaseId or "")
     table.insert(sanitized,{
      title=item.title:sub(1,90),
      artist=tostring(item.artist or "未知"):sub(1,50),
      provider=item.provider=="netease" and "netease" or "roblox",
      robloxId=rb or "",neteaseId=nid or ""
     })
    end
   end
   if #sanitized>0 then playlist=sanitized end
  end
  -- Migrate the old source-less built-in track without overwriting user-selected music.
  for _,track in ipairs(playlist)do
   if track.title==favoriteTitle and track.artist==favoriteArtist and track.robloxId=="" then
    track.robloxId="126433682497062"
   end
  end
  index=math.clamp(tonumber(data.index)or 1,1,#playlist)
  sound.Volume=volume;sound.PlaybackSpeed=speed;sound.Looped=looping
  return true
 end
 local function localAsset()
  if type(isfile)~="function"then return nil end
  local hasFile,exists=pcall(isfile,localMusicPath)
  if not hasFile or not exists then return nil end
  local f=(type(getcustomasset)=="function" and getcustomasset)
     or (type(getsynasset)=="function" and getsynasset)
  if not f then return nil end
  local ok,id=pcall(f,localMusicPath)
  if ok and type(id)=="string" and id~=""then return id end
  return nil
 end
 local function playableId(song)
  if not song then return nil end
  if song.robloxId~=""then return "rbxassetid://"..song.robloxId end
  if song.title==favoriteTitle and song.artist==favoriteArtist then return localAsset()end
  return nil
 end
 local function play(i)
  if stopped then return false,"播放器已卸载"end
  index=math.clamp(tonumber(i)or index,1,#playlist)
  local song=current()
  local id=playableId(song)
  if not id then
   playSerial+=1
   sound:Stop()
   sound.SoundId=""
   status="等待配置音源"
   lastError="曲目「"..song.title.."」尚无当前游戏允许播放的 Roblox 音频ID或授权本地文件"
   return false,lastError
  end
  playSerial+=1
  local serial=playSerial
  sound:Stop()
  sound.SoundId=id
  sound.Volume=volume
  sound.PlaybackSpeed=speed
  sound.Looped=looping
  status="正在加载"
  lastError=""
  local ok,err=pcall(function()sound:Play()end)
  if not ok then status="播放失败";lastError=tostring(err);return false,lastError end
  task.delay(7,function()
   if stopped or serial~=playSerial then return end
   if sound.IsPlaying and sound.IsLoaded then
    status="播放中"
   elseif not sound.IsLoaded then
    status="音源不可用"
    lastError="无法加载此音频：可能是资源不存在，或当前游戏无播放权限"
   else
    status=sound.IsPlaying and "播放中" or "已停止"
   end
  end)
  save()
  return true,"音源已交给 Roblox Sound 加载"
 end
 local function pause()
  if sound.IsPlaying then sound:Pause();status="已暂停";return end
  if sound.SoundId~=""then
   local ok=pcall(function()sound:Resume()end)
   if ok then status="播放中"else play(index)end
  else play(index)end
 end
 local function stop()
  playSerial+=1;sound:Stop()
  lastError=""
  status="已停止"
 end
 local function step(delta)
  if #playlist==0 then return false end
  if shuffle and #playlist>1 then
   local nextIndex=index
   while nextIndex==index do nextIndex=math.random(1,#playlist)end
   return play(nextIndex)
  end
  return play((index-1+delta)%#playlist+1)
 end
 local function addRoblox(title,raw)
  local id=getId(raw)
  if not id then return false,"请填写有效的 Roblox 音频数字 ID"end
  if #playlist>=70 then return false,"播放列表最多 70 首"end
  table.insert(playlist,{
   title=(tostring(title or "")~=""and tostring(title) or "Roblox Audio "..id):sub(1,90),
   artist="Roblox 音频",provider="roblox",neteaseId="",robloxId=id
  })
  index=#playlist;save()
  return true,"已加入 Roblox 播放列表"
 end
 local function addNetease(title,raw)
  local id=neteaseId(raw)
  if not id then return false,"请输入网易云歌曲 ID 或 song?id= 的完整链接"end
  if #playlist>=70 then return false,"播放列表最多 70 首"end
  table.insert(playlist,{
   title=(tostring(title or "")~=""and tostring(title)or"网易云歌曲 "..id):sub(1,90),
   artist="网易云曲目",provider="netease",neteaseId=id,robloxId=""
  })
  index=#playlist;save()
  return true,"已保存网易云曲目信息；要在游戏内播放仍需关联授权 Roblox 音频"
 end
 local function bindRoblox(raw)
  local id=getId(raw)
  if not id then return false,"请输入 Roblox 音频数字 ID"end
  current().robloxId=id
  save()
  return true,"已关联 Roblox 音频；可以尝试播放"
 end
 local function remove()
  if #playlist<=1 then return false,"需要至少保留一首歌"end
  table.remove(playlist,index)
  index=math.clamp(index,1,#playlist)
  stop();save()
  return true,"已删除"
 end
 local function setVolume(v)
  volume=math.clamp(tonumber(v)or volume,0,2)
  sound.Volume=volume;save()
 end
 local function setSpeed(v)
  speed=math.clamp(tonumber(v)or speed,.4,2)
  sound.PlaybackSpeed=speed;save()
 end
 local function seek(seconds)
  if sound.IsLoaded and sound.TimeLength>0 then
   sound.TimePosition=math.clamp(tonumber(seconds)or 0,0,math.max(0,sound.TimeLength-.05))
   return true
  end
  return false
 end
 local function tick()
  if stopped then return end
  if sound.IsPlaying and sound.IsLoaded and status=="正在加载"then status="播放中"end
 end
 local function destroy()
  if stopped then return end
  stopped=true
  playSerial+=1
  save()
  pcall(function()sound:Stop()end)
  pcall(function()sound:Destroy()end)
 end
 local api={
  Sound=sound,Playlist=function()return playlist end,
  Current=current,Play=play,Pause=pause,Stop=stop,Next=function()return step(1)end,
  Prev=function()return step(-1)end,Select=function(i)index=math.clamp(i,1,#playlist);save();return current()end,
  AddRoblox=addRoblox,AddNetease=addNetease,BindRoblox=bindRoblox,
  Remove=remove,SetVolume=setVolume,SetSpeed=setSpeed,Seek=seek,
  Save=save,Load=load,Tick=tick,Destroy=destroy,
  SetLoop=function(v)looping=v;sound.Looped=v;save()end,
  SetShuffle=function(v)shuffle=v;save()end,
  SetAutoPlay=function(v)autoplay=v;save()end,
  GetStatus=function()return status,lastError end,
  GetVolume=function()return volume end,
  GetSpeed=function()return speed end,
  IsAutoplay=function()return autoplay end,
  IsLoop=function()return looping end,
  IsShuffle=function()return shuffle end,
  GetIndex=function()return index end,
  GetSource=function()return playableId(current())end,
  GetNeteaseLink=function()
   local track=current()
   return track and track.neteaseId~="" and ("https://music.163.com/#/song?id="..track.neteaseId) or ""
  end,
  FormatTime=function(sec)
   sec=math.floor(math.max(0,sec or 0))
   return string.format("%02d:%02d",math.floor(sec/60),sec%60)
  end
 }
 App.Music=api
 connect(sound.Ended,function()
  if stopped then return end
  if not sound.Looped then
   status="播放结束"
   if #playlist>1 then task.defer(function()if App.Running then step(1)end end)end
  end
 end)
 load()
 sound.Volume=volume;sound.PlaybackSpeed=speed;sound.Looped=looping
 if autoplay then
  task.defer(function()
   if not App.Running or stopped then return end
   local safe,ok,err=pcall(play,index)
   if not safe then
    status="音源检查失败"
    lastError=tostring(ok)
    warn("[Rain Music] "..lastError)
   elseif not ok then
    toast("默认音乐待配置",err,"music-2")
   end
  end)
 else status="自动播放已关闭"end
end

-- Mouse / touch gesture grabber (locally owned loose parts).
do
 local held,activeInput,lastPos,marker=nil,nil,nil,nil
 local distance=13
 local accumulator=0
 local function release()
  if marker then pcall(function()marker:Destroy()end)end
  marker=nil;held=nil;activeInput=nil;lastPos=nil
 end
 local function eligible(part)
  if not part or not part:IsA("BasePart") or part.Anchored or part.AssemblyMass>State.grabMaxMass then return false end
  for _,player in ipairs(Players:GetPlayers())do
   local model=char(player)
   if model and part:IsDescendantOf(model)then return false end
  end
  return true
 end
 local function begin(pos,input)
  if not State.grabEnabled or not workspace.CurrentCamera then return false end
  local ray=workspace.CurrentCamera:ViewportPointToRay(pos.X,pos.Y)
  local params=RaycastParams.new()
  params.FilterType=Enum.RaycastFilterType.Exclude
  local exclude={}
  if char()then table.insert(exclude,char())end
  if combatEffects.holePart then table.insert(exclude,combatEffects.holePart)end
  params.FilterDescendantsInstances=exclude
  local hit=workspace:Raycast(ray.Origin,ray.Direction*math.clamp(State.grabRange,5,180),params)
  if not hit or not eligible(hit.Instance)then return false end
  release()
  held=hit.Instance;activeInput=input;lastPos=pos
  distance=math.clamp((hit.Position-ray.Origin).Magnitude,3,State.grabRange)
  marker=Instance.new("Highlight")
  marker.Name="RainHub_GrabMarker"
  marker.Adornee=held;marker.FillTransparency=.7
  marker.FillColor=Color3.fromRGB(68,172,255)
  marker.Parent=held
  return true
 end
 local function tick(dt)
  if not State.grabEnabled or not held then return end
  if not held.Parent or not eligible(held)then release();return end
  local me=hrp()
  if not me or (held.Position-me.Position).Magnitude>200 then release();return end
  accumulator+=dt
  if accumulator<1/30 then return end
  local elapsed=math.min(.1,accumulator);accumulator=0
  local cam=workspace.CurrentCamera
  if not cam or not lastPos then return end
  local ray=cam:ViewportPointToRay(lastPos.X,lastPos.Y)
  local target=ray.Origin+ray.Direction*distance
  local velocity=(target-held.Position)*math.clamp(State.grabStrength,5,240)*elapsed*6
  if velocity.Magnitude>95 then velocity=velocity.Unit*95 end
  pcall(function()held.AssemblyLinearVelocity=velocity end)
 end
 App.Grab={
  Begin=begin,Release=release,Step=tick,
  Held=function()return held end,
  SetDistance=function(x)distance=math.clamp(tonumber(x)or distance,3,State.grabRange)end,
  Spin=function()
   if held then pcall(function()held.AssemblyAngularVelocity=Vector3.new(0,7,0)end)end
  end
 }
 connect(UIS.InputBegan,function(input,processed)
  if not App.Running or not State.grabEnabled or processed or UIS:GetFocusedTextBox()then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 and
    (UIS:IsKeyDown(Enum.KeyCode.LeftAlt) or UIS:IsKeyDown(Enum.KeyCode.RightAlt))then
   if begin(UIS:GetMouseLocation(),input)then toast("物品已吸附","移动鼠标、滚轮调整距离，R 旋转","hand")end
  elseif input.UserInputType==Enum.UserInputType.Touch then
   begin(Vector2.new(input.Position.X,input.Position.Y),input)
  elseif input.KeyCode==Enum.KeyCode.F then release()
  elseif input.KeyCode==Enum.KeyCode.R then App.Grab.Spin()end
 end)
 connect(UIS.InputChanged,function(input)
  if not held then return end
  if input.UserInputType==Enum.UserInputType.MouseWheel then
   distance=math.clamp(distance-input.Position.Z*2,3,State.grabRange)
  elseif input.UserInputType==Enum.UserInputType.MouseMovement and activeInput and
    activeInput.UserInputType==Enum.UserInputType.MouseButton1 then
   lastPos=UIS:GetMouseLocation()
  elseif input.UserInputType==Enum.UserInputType.Touch and input==activeInput then
   lastPos=Vector2.new(input.Position.X,input.Position.Y)
  end
 end)
 connect(UIS.InputEnded,function(input)
  if input==activeInput then release()end
 end)
end

local function destroy()
 if not App.Running then return end
 App.Running=false
 State.fly=false;State.noclip=false;State.esp=false;State.antiFling=false;State.antiVoid=false;State.aim=false;State.projectileTrace=false
 State.sprintEnabled=false;State.sprinting=false
 App.Combat.StopAntiAim();App.Combat.StopBlackHole();App.Combat.SetTouch(false);App.Combat.StopFling()
 if App.Music then App.Music.Destroy()end
 if App.Grab then App.Grab.Release()end
 workspace.Gravity=startGravity
 stopFly()
 restoreMovement()
 restoreParts(App.noclipParts,"CanCollide")
 restoreParts(App.flingParts,"CanCollide")
 restoreParts(App.xrayParts,"LocalTransparencyModifier")
 setPerformance(false)
 clearProjectiles()
 removeOwnedTools()
 for p in pairs(markedTags)do removeBadge(p)end
 State.fullbright=false;State.noFog=false
 pcall(setLighting);pcall(setFog)
 if workspace.CurrentCamera then
  workspace.CurrentCamera.FieldOfView=startFOV
  pcall(function()spectate(nil)end)
 end
 for p in pairs(App.esp)do clearESP(p)end
 for _,c in ipairs(App.connections)do pcall(function()c:Disconnect()end)end
 table.clear(App.connections)
 if overlay then pcall(function()overlay:Destroy()end)end
 if hudGui then pcall(function()hudGui:Destroy()end);hudGui=nil;hudPanel=nil end
 if Window then
  local w=Window
  Window=nil
  pcall(function()w:StopAllLoops()end)
  pcall(function()w:Destroy()end)
 end
 if env.NexusUniversalHub==App then env.NexusUniversalHub=nil end
 if env.YuHub==App then env.YuHub=nil end
 if App.Compat and App.Compat.InstalledShim and env.gethui==App.Compat.InstalledShim then env.gethui=nil end
end
App.Destroy=destroy
rememberMovement()
makeOverlay()
makeHud()
makeAimOverlay()
rebuildBadges()

connect(LP.CharacterAdded,function(c)
 task.defer(function()
  if not App.Running then return end
  c:WaitForChild("Humanoid",12)
  c:WaitForChild("HumanoidRootPart",12)
  rememberMovement()
  task.wait(0.35)
  if State.touchKill then App.Combat.AttachTouch()end
  if State.antiAim then combatEffects.antiAimAutoRotate=nil end
  rebuildBadges()
  if not App.Running then return end
  applyMovement()
  if State.fly then startFly()end
  if State.respawnTP and State.lastPos then
   local r=hrp()
   if r then r.CFrame=State.lastPos end
  end
 end)
end)
connect(Players.PlayerRemoving,function(p)
 clearESP(p)
 markedPlayers[p]=nil
 removeBadge(p)
 if p.Name==spectated then spectate(nil)end
 if p.Name==followTarget then State.follow=false;followTarget=""end
end)
connect(UIS.InputBegan,function(input,processed)
 if processed or UIS:GetFocusedTextBox()then return end
 for _,action in ipairs(App.HotkeyActions)do
  if App.Hotkeys[action] and input.KeyCode.Name==App.Hotkeys[action]then
   App.Combat.Trigger(action)
   return
  end
 end
 if input.KeyCode==Enum.KeyCode.LeftShift then State.sprinting=true;applyMovement()end
 if input.KeyCode==Enum.KeyCode.E then State.up=true end
 if input.KeyCode==Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.LeftControl then State.down=true end
 if input.KeyCode==Enum.KeyCode.T and State.clickTP then
  local m=LP:GetMouse()
  if m and m.Hit then teleport(m.Hit+CFrame.new(0,4,0))end
 end
end)
connect(UIS.InputEnded,function(input)
 if input.KeyCode==Enum.KeyCode.LeftShift then State.sprinting=false;applyMovement()end
 if input.KeyCode==Enum.KeyCode.E then State.up=false end
 if input.KeyCode==Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.LeftControl then State.down=false end
end)
connect(UIS.JumpRequest,function()
 if State.infiniteJump then
  local h=humanoid()
  if h then h:ChangeState(Enum.HumanoidStateType.Jumping)end
 end
end)
connect(LP.Idled,function()
 if State.antiAfk then
  pcall(function()VU:CaptureController();VU:ClickButton2(Vector2.zero)end)
 end
end)
connect(RS.PreSimulation,function()
 if App.Running and State.antiFling then antiFlingTick()end
end)
connect(RS.Stepped,function()
 if not App.Running or not State.noclip then return end
 local c=char()
 if not c then return end
 for _,part in ipairs(c:GetDescendants())do
  if part:IsA("BasePart")then
   if App.noclipParts[part]==nil then App.noclipParts[part]=part.CanCollide end
   part.CanCollide=false
  end
 end
end)
connect(RS.Heartbeat,function(dt)
 if not App.Running then return end
 App.Combat.Tick(dt)
 if App.Grab then App.Grab.Step(dt)end
 physicsClock+=dt
 if State.antiFling or State.antiVoid then recoverFlingTick()end
 if State.fly then
  local r,h=hrp(),humanoid()
  if r and h then
   if not flyVelocity or flyPart~=r then startFly()end
   local camera=workspace.CurrentCamera
   if flyVelocity and flyGyro and camera then
    local v=h.MoveDirection+Vector3.new(0,(State.up and 1 or 0)-(State.down and 1 or 0),0)
    if v.Magnitude>1 then v=v.Unit end
    flyVelocity.Velocity=v*State.flySpeed
    flyGyro.CFrame=CFrame.lookAt(r.Position,r.Position+camera.CFrame.LookVector)
    h.PlatformStand=true
   end
  end
 end
 if physicsClock>=0.25 then
  physicsClock=0
  if State.speedEnabled or State.jumpEnabled or State.sprintEnabled or State.hipEnabled then applyMovement()end
  if State.fullbright then setLighting()end
  if State.noFog then setFog()end
  if spectated~=""then
   local p=lookup(spectated)
   if p and humanoid(p) and workspace.CurrentCamera then workspace.CurrentCamera.CameraSubject=humanoid(p)end
  end
  if State.follow then
   local p=lookup(followTarget)
   local r,targetR=hrp(),p and hrp(p)
   if r and targetR then
    r.CFrame=targetR.CFrame*CFrame.new(0,0,State.followOffset)
    r.AssemblyLinearVelocity=Vector3.zero
   end
  end
 end
end)
connect(RS.RenderStepped,function(dt)
 if not App.Running then return end
 aimFrame(dt)
 frames+=1
 if os.clock()-lastFps>=1 then
  fps=math.floor(frames/(os.clock()-lastFps)+0.5)
  frames=0;lastFps=os.clock()
  refreshHud()
 end
 espClock+=dt
 local espBudget=math.max(.06,State.perfEspInterval)
 if State.perfAutoAdjust and fps<45 then espBudget*=1.8 end
 if espClock>=espBudget then espClock=0;updateESP()end
 if State.aim and math.floor(os.clock()*5)~=math.floor((os.clock()-dt)*5)then refreshHud()end
end)

-- Detect dynamically spawned projectile parts. No server remotes used.
connect(workspace.DescendantAdded,function(instance)
 if not App.Running or not State.projectileTrace then return end
 if instance:IsA("BasePart") then
  task.defer(function()
   if App.Running then pcall(maybeTraceProjectile,instance)end
  end)
 end
end)
local projectileTick=0
connect(RS.Heartbeat,function(dt)
 if not App.Running then return end
 projectileTick+=dt
 if projectileTick>math.max(1,State.perfProjectileScan)then
  projectileTick=0
  updateProjectiles()
  if State.projectileTrace then scanProjectiles() end
 end
end)
-- ANUI official distribution
local ok,loaded=pcall(function()
 assert(type(loadstring)=="function","loadstring is unavailable")
 local source=App.Compat.Fetch("https://raw.githubusercontent.com/ANHub-Script/ANUI/refs/heads/main/dist/main.lua")
 local compiled,reason=loadstring(source)
 assert(type(compiled)=="function","ANUI 无法编译: "..tostring(reason))
 return compiled()
end)
if not ok or not loaded then
 warn("[雨 Hub Xeno] ANUI load failed: "..tostring(loaded))
 destroy()
 return
end
ANUI=loaded
local created,window=pcall(function()
 return ANUI:CreateWindow({
  Title="雨 Hub 🌧️ | Universal",Author="朱翎 · 雨 Hub v"..App.Version,
  Icon="rbxassetid://84366761557806",IconSize=25,
  Folder="NexusUniversal",Theme="TokyoNight",Acrylic=true,
  ToggleKey=Enum.KeyCode.RightShift,
  OpenButton={
   Title="雨🌧️",Enabled=true,Draggable=true,OnlyMobile=false,
   CornerRadius=UDim.new(1,0),StrokeThickness=2,
   Color=ColorSequence.new(Color3.fromHex("#32caff"),Color3.fromHex("#a073ff"))
  }
 })
end)
if not created or not window then
 warn("[NEXUS] Window load failed: "..tostring(window))
 destroy()
 return
end
Window=window
pcall(function()Window:Tag({Title="v"..App.Version,Icon="globe"})end)
local Config=Window.ConfigManager
if Config then pcall(function()Window.CurrentConfig=Config:Config("default")end)end

App.NavRole=Window:Section({Title="🌧️ 概览与角色",Opened=true})
App.NavCombat=Window:Section({Title="🎯 战斗与物理",Opened=false})
App.NavTools=Window:Section({Title="🛠️ 视觉与工具",Opened=false})
App.NavPersonal=Window:Section({Title="⚙️ 个性化",Opened=false})
local Home=App.NavRole:Tab({Title="总览",Icon="layout-dashboard",Desc="会话信息与快捷操作"})
local Movement=App.NavRole:Tab({Title="移动",Icon="person-standing",Desc="角色控制与飞行"})
local Defense=App.NavRole:Tab({Title="防护",Icon="shield-check",Desc="防甩飞与防坠落"})
local PlayerUI=App.NavRole:Tab({Title="玩家",Icon="users",Desc="玩家选择与交互"})
local Travel=App.NavRole:Tab({Title="传送",Icon="map-pin",Desc="位置管理与快捷传送"})
local ESP=App.NavCombat:Tab({Title="ESP 透视",Icon="scan-eye",Desc="高亮与屏幕指示"})
local Aim=App.NavCombat:Tab({Title="自瞄与弹道",Icon="crosshair",Desc="目标辅助 / 弹道可视化"})
App.CombatTab=App.NavCombat:Tab({Title="对抗与物理",Icon="orbit",Desc="反自瞄 / 全场黑洞 / 自我旋转"})
local World=App.NavTools:Tab({Title="画面",Icon="sun",Desc="光照、迷雾与视野"})
local Performance=App.NavTools:Tab({Title="性能",Icon="gauge",Desc="粒子优化、场景减负"})
local Utilities=App.NavTools:Tab({Title="工具",Icon="wrench",Desc="辅助功能"})
App.HotkeyTab=App.NavTools:Tab({Title="快捷键",Icon="keyboard",Desc="功能按键绑定与保存"})
local Settings=App.NavPersonal:Tab({Title="设置",Icon="settings",Desc="界面外观与配置"})
App.CustomizeTab=App.NavPersonal:Tab({Title="自定义",Icon="sliders-horizontal",Desc="自由显示页面与功能"})
App.MusicTab=App.NavPersonal:Tab({Title="音乐播放器",Icon="music-2",Desc="默认隐藏，设置中可以开启"})
App.Tabs={Home=Home,Movement=Movement,Defense=Defense,ESP=ESP,PlayerUI=PlayerUI,Travel=Travel,World=World,Aim=Aim,Combat=App.CombatTab,Hotkeys=App.HotkeyTab,Music=App.MusicTab,Performance=Performance,Utilities=Utilities,Settings=Settings,Customize=App.CustomizeTab}
App.Window=Window

-- Tabs are always constructed inside ANUI sections, but can be presented flat.
-- Reparent existing tab buttons rather than rebuilding pages or duplicate callbacks.
App.NavMap={Home="Role",Movement="Role",Defense="Role",PlayerUI="Role",Travel="Role",
 ESP="Combat",Aim="Combat",Combat="Combat",World="Tools",Performance="Tools",
 Utilities="Tools",Hotkeys="Tools",Settings="Personal",Customize="Personal",Music="Personal"}
App.NavLabels={Role="🌧️ 概览与角色",Combat="🎯 战斗与物理",Tools="🛠️ 视觉与工具",Personal="⚙️ 个性化"}
App.NavFrames={}
App.RefreshSidebarLayout=function()
 local sidebar=Window.UIElements.SideBar.Frame
 for _,frame in ipairs(sidebar:GetChildren())do
  if frame:IsA("Frame") and frame:FindFirstChild("Content")then
   local header=frame:FindFirstChildOfClass("TextButton")
   local heading=header and header:FindFirstChildOfClass("TextLabel")
   if heading then
    for key,title in pairs(App.NavLabels)do
     if heading.Text==title then App.NavFrames[key]=frame end
    end
   end
  end
 end
 for key,tab in pairs(App.Tabs)do
  local group=App.NavFrames[App.NavMap[key]]
  local button=tab.UIElements and tab.UIElements.Main
  if button and group then
   local target=State.sidebarGrouped and group:FindFirstChild("Content") or sidebar
   if target and button.Parent~=target then button.Parent=target end
  end
 end
 for _,frame in pairs(App.NavFrames)do
  frame.Visible=State.sidebarGrouped
 end
end

local platform="未知"
pcall(function()platform=tostring(UIS:GetPlatform()):gsub("Enum.Platform.","")end)
local executorName,executorVersion=executorInfo()
App.HomeOverview=Home:Paragraph({
 Title="<gradient=#37CFFF,#A78BFA>雨 Hub 🌧️ | 总览</gradient> {sparkles}",
 Desc="正在整理游戏和会话信息…"
})
App.HomeAdvanced=Home:Section({Title="详细信息与诊断",Opened=false,Box=true})
App.HomeAdvanced:Paragraph({
 Title="兼容性说明",
 Desc="Roblox 服务器可能拒绝客户端移动或传送；此脚本不会调用未知游戏的 RemoteEvent。"
})
App.HomeAdvanced:Button({Title="输出执行器兼容性报告",Icon="terminal",Callback=function()
 print("[雨 Hub] "..App.Compat.Report())
 toast("执行器兼容性",App.Compat.Report(),"info")
end})
local overDetails=App.HomeAdvanced:Paragraph({Title="详细服务器信息",Desc="高级模式中提供服务器详细标识"})
local overDevice=App.HomeAdvanced:Paragraph({Title="本地设备诊断",Desc="设备标识默认遮盖且不会自动上传"})
local overIP=App.HomeAdvanced:Paragraph({Title="公网出口 IP",Desc="默认不查询；点击下方按钮才请求第三方服务"})
App.HomeAdvanced:Button({Title="复制账户 UserId",Icon="copy",Callback=function()copy(LP.UserId)end})
App.HomeAdvanced:Button({Title="复制游戏 PlaceId",Icon="copy",Callback=function()copy(game.PlaceId)end})
App.HomeAdvanced:Button({Title="复制服务器 JobId",Icon="clipboard",Callback=function()copy(game.JobId)end})
local ipCheck=App.HomeAdvanced:Button({Title="手动查询公网出口 IP",Icon="globe",
 Desc="只有主动点击才访问 api.ipify.org",
 Callback=function()
  overIP:SetDesc("正在请求公网查询服务…")
  task.spawn(function()
   local ok,response=pcall(function()
    local body=game:HttpGet("https://api.ipify.org?format=json")
    return tostring(game:GetService("HttpService"):JSONDecode(body).ip)
   end)
   if not App.Running then return end
   if ok and type(response)=="string" and #response<64 then
    overIP:SetDesc("出口 IP："..response.."（代理环境可能为代理出口）")
   else overIP:SetDesc("查询失败：当前环境可能禁止第三方网络请求")end
  end)
 end
})
App.HomeAdvanced:Button({Title="复制设备标识（仅手动）",Icon="fingerprint",Callback=function()
 if type(gethwid)~="function"then toast("无法读取","执行器未提供设备标识接口","alert-circle");return end
 local ok,id=pcall(gethwid)
 if ok and type(id)=="string" and #id>0 then copy(id)
 else toast("无法读取","设备标识不可用","alert-circle")end
end})
App.HomeAdvanced:Button({Title="重新加入游戏",Icon="refresh-cw",Callback=function()
 local ok,err=pcall(function()TS:Teleport(game.PlaceId,LP)end)
 if not ok then toast("重新加入失败",err,"alert-circle")end
end})

-- Precision inputs accept finite values beyond slider ranges; the engine still sets physical limits.
local function preciseInput(host,title,key,minimum,onChange)
 local control=host:Input({
  Title=title,Value=tostring(State[key]),Placeholder="手动输入任意有限数值",
  Callback=function(raw)
   local n=tonumber(raw)
   if not n or n~=n or n==math.huge or n==-math.huge or (minimum and n<minimum)then
    if tostring(raw or "")~=""then toast("数值无效",title.."：请输入有效数字","alert-circle")end
    return
   end
   State[key]=n
   if onChange then
    local ok,err=pcall(onChange,n)
    if not ok then toast("游戏限制",err,"alert-circle")end
   end
  end
 })
 return control
end
local m1=Movement:Section({Title="角色移动",Opened=false,Box=true})
m1:Toggle({Title="自定义移动速度",Flag="speedToggle",Callback=function(v)
 State.speedEnabled=v
 if v then applyMovement()else local h=humanoid();if h then h.WalkSpeed=startSpeed or 16 end end
end})
m1:Slider({Title="移动速度",Flag="speed",Value={Min=1,Max=250,Default=24},Step=1,
 Callback=function(v)State.speed=tonumber(v)or 24;applyMovement()end})
m1:Toggle({Title="自定义跳跃",Flag="jumpToggle",Callback=function(v)
 State.jumpEnabled=v
 if v then applyMovement()else jumpReset()end
end})
m1:Slider({Title="跳跃力度",Flag="jump",Value={Min=10,Max=250,Default=65},Step=1,
 Callback=function(v)State.jump=tonumber(v)or 65;applyMovement()end})
preciseInput(m1,"精确移速（无滑块上限）","speed",0,function()applyMovement()end)
preciseInput(m1,"精确跳跃力度（无滑块上限）","jump",0,function()applyMovement()end)
local sprint=Movement:Section({Title="冲刺与角色体态",Opened=false,Box=true})
sprint:Toggle({Title="按住左 Shift 冲刺",Desc="按住时使用冲刺速度，松开恢复",Flag="sprintToggle",
 Callback=function(v)State.sprintEnabled=v;if not v then State.sprinting=false end;applyMovement()end})
sprint:Slider({Title="冲刺速度",Flag="sprintSpeed",Value={Min=16,Max=250,Default=40},Step=2,
 Callback=function(v)State.sprintSpeed=tonumber(v)or 40;applyMovement()end})
preciseInput(sprint,"精确冲刺速度","sprintSpeed",0,function()applyMovement()end)
sprint:Toggle({Title="自定义 HipHeight（角色站立高度）",Flag="hipToggle",
 Callback=function(v)
  State.hipEnabled=v
  if v then applyMovement()else local h=humanoid();if h and startHip then h.HipHeight=startHip end end
 end})
preciseInput(sprint,"精确 HipHeight","hipHeight",-100,function()applyMovement()end)
m1:Toggle({Title="无限跳跃",Desc="在空中也可以连续跳跃",Flag="infiniteJump",
 Callback=function(v)State.infiniteJump=v end})
local m2=Movement:Section({Title="飞行与物理",Opened=false,Box=true})
m2:Toggle({Title="自由飞行",Desc="WASD 移动 · E 上升 · Q/Ctrl 下降",Flag="flight",
 Callback=function(v)State.fly=v;if v then startFly()else stopFly()end end})
m2:Slider({Title="飞行速度",Flag="flightSpeed",Value={Min=10,Max=250,Default=65},Step=5,
 Callback=function(v)State.flySpeed=tonumber(v)or 65 end})
preciseInput(m2,"精确飞行速度（无滑块上限）","flySpeed",0)
m2:Toggle({Title="无碰撞 / Noclip",Desc="只操作自身角色本地碰撞",Flag="noclip",
 Callback=function(v)State.noclip=v;if not v then restoreParts(App.noclipParts,"CanCollide")end end})
m2:Paragraph({Title="防甩飞已全面升级",Desc="现在使用物理帧预警与冲击恢复；请在独立的「防护」页面调整模式、距离、阈值及回滚策略。"})
Movement:Button({Title="恢复角色默认移动属性",Icon="rotate-ccw",Callback=function()
 State.speedEnabled=false;State.jumpEnabled=false;State.fly=false;State.noclip=false
 stopFly();restoreMovement();restoreParts(App.noclipParts,"CanCollide")
 toast("移动属性","已还原到本次角色的初始值","check")
end})


Defense:Paragraph({Title="<gradient=#37cfff,#7be4bb>多层防甩飞 2.0</gradient> {shield-check}",
 Desc="预模拟阶段隔离危险角色碰撞，碰撞后检查异常水平速度/角速度；可选择恢复到最近的落地安全点。\n智能：仅处理异常高速的玩家；强力：隔离范围内所有角色碰撞。强力模式可能影响推挤、载具和近战玩法。"})
local d1=Defense:Section({Title="防甩飞",Opened=false,Box=true})
d1:Toggle({Title="开启多层防甩飞",Flag="antiFling",
 Callback=function(v)
  State.antiFling=v
  if not v then restoreParts(App.flingParts,"CanCollide");guard.threatNearby=false;guard.threat="" end
  if v then toast("防甩飞已启用","已启用物理帧实时检测","shield-check")end
 end})
d1:Dropdown({Title="防护策略",Values={"智能","强力"},Value="智能",Flag="antiMode",
 Callback=function(value)
  State.antiFlingMode=value
  toast("防护模式",value=="强力" and "范围内角色默认本地无碰撞" or "只隔离高速异常角色","shield")
 end})
d1:Toggle({Title="异常冲击后恢复安全位置",Value=true,Flag="guardRollback",
 Callback=function(v)State.antiFlingRollback=v end})
d1:Toggle({Title="防护触发通知",Value=true,Flag="guardNotice",
 Callback=function(v)State.antiFlingAlert=v end})
d1:Toggle({Title="坐在载具时暂停位置恢复",Value=true,Flag="guardVehicle",
 Callback=function(v)State.antiFlingVehicleSkip=v end})
local d2=Defense:Section({Title="检测范围与阈值",Opened=false,Box=true})
d2:Slider({Title="附近角色检测距离",Value={Min=10,Max=250,Default=45},Step=5,
 Callback=function(v)State.antiFlingRadius=tonumber(v)or 45 end})
preciseInput(d2,"精确检测半径","antiFlingRadius",1)
preciseInput(d2,"他人线速度阈值（stud/s）","antiFlingEnemySpeed",1)
preciseInput(d2,"他人角速度阈值","antiFlingEnemySpin",1)
preciseInput(d2,"自身水平速度保护阈值","antiFlingSelfSpeed",1)
preciseInput(d2,"自身角速度保护阈值","antiFlingSelfSpin",1)
local d3=Defense:Section({Title="防坠落与应急",Opened=false,Box=true})
d3:Toggle({Title="防坠落 / Anti-Void",Desc="跌落至设定高度以下时回到最近安全点",
 Flag="antiVoid",Callback=function(v)State.antiVoid=v end})
preciseInput(d3,"防坠落触发高度（Y 坐标）","antiVoidHeight",nil)
d3:Button({Title="手动记录当前安全位置",Icon="bookmark-plus",Callback=function()
 local r=hrp()
 if r then guard.safeCFrame=r.CFrame;guard.lastSafe=os.clock();toast("安全点","已记录 "..tostring(r.Position),"check")end
end})
d3:Button({Title="回到最近安全位置",Icon="shield",Callback=function()
 if guard.safeCFrame then teleport(guard.safeCFrame)
 else toast("安全点不存在","先点击手动保存，或正常在地面停留","alert-circle")end
end})
local defenseStatus=Defense:Button({Title="防护触发：0 次",Desc="暂无异常事件",Icon="activity",
 Callback=function()
  toast("防护诊断","检测到异常 "..guard.recoveries.." 次 · 最近威胁 "..(guard.threat~="" and guard.threat or "无"),"shield-check")
 end})
Defense:Paragraph({Title="限制说明",Desc="防甩飞属于客户端减伤措施，无法拦截服务器强制传送或所有物理网络所有权异常。如果游戏自带冲刺、载具、抛射等机制，请提高速度阈值或关闭回滚。"})

local e1=ESP:Section({Title="ESP 显示",Opened=false,Box=true})
e1:Toggle({Title="总开关",Value=true,Flag="esp",Callback=function(v)
 State.esp=v
 if not v then for p in pairs(App.esp)do clearESP(p)end end
end})
e1:Toggle({Title="3D 角色高亮",Value=true,Flag="highlight",Callback=function(v)State.highlight=v end})
e1:Toggle({Title="名称标签",Value=true,Flag="espNames",Callback=function(v)State.names=v end})
e1:Toggle({Title="显示血量",Value=true,Flag="espHealth",Callback=function(v)State.health=v end})
e1:Toggle({Title="显示距离",Value=true,Flag="espDistance",Callback=function(v)State.distance=v end})
e1:Toggle({Title="方框 ESP",Desc="ScreenGui 实现，不依赖 Drawing API",Flag="espBoxes",
 Callback=function(v)State.boxes=v end})
e1:Toggle({Title="玩家射线",Desc="从屏幕底部指向目标",Flag="espTracers",
 Callback=function(v)State.tracers=v end})
local e2=ESP:Section({Title="过滤与样式",Opened=false,Box=true})
e2:Toggle({Title="队伍过滤",Desc="过滤当前队伍玩家",Flag="teamFilter",
 Callback=function(v)State.teamFilter=v end})
e2:Slider({Title="最大距离（stud）",Value={Min=100,Max=5000,Default=2500},
 Step=100,Flag="range",Callback=function(v)State.espRange=tonumber(v)or 2500 end})
preciseInput(e2,"精确 ESP 距离","espRange",0)
e2:Colorpicker({Title="ESP 颜色",Default=State.espColor,Flag="espColor",
 Callback=function(color)if typeof(color)=="Color3" then State.espColor=color end end})
ESP:Button({Title="重新绘制 ESP 对象",Icon="refresh-cw",Callback=function()
 for p in pairs(App.esp)do clearESP(p)end
 toast("ESP","绘制对象已重新初始化","check")
end})

PlayerUI:Paragraph({Title="玩家交互",Desc="输入完整用户名或昵称前缀来选中一个玩家。列表实时匹配，无需绑定特定服务器。"})
local chosen=PlayerUI:Button({Title="当前选择：无",Desc="请先搜索玩家",Icon="user",
 Callback=function()
  local p=lookup(State.target)
  toast("选中玩家",p and ("@"..p.Name.." | ID "..p.UserId) or "暂无玩家","users")
 end})
-- Live roster: dropdown labels map to exact usernames. The input and menu stay synchronized.
local playerInput,playerDropdown
local playerLabels={}
local rosterSignature=""
local rosterUpdating=false
local sortRoster="用户名"
local rosterFilter=""
local function selectPlayer(p,fromInput)
 if not p then return end
 State.target=p.Name
 chosen:SetTitle("当前选择："..p.DisplayName)
 chosen:SetDesc("@"..p.Name.." · ID "..p.UserId)
 if not fromInput and playerInput then pcall(function()playerInput:Set(p.Name)end)end
 if playerDropdown then
  for label,name in pairs(playerLabels)do
   if name==p.Name then
    rosterUpdating=true
    pcall(function()playerDropdown:Select(label)end)
    rosterUpdating=false
    break
   end
  end
 end
end
local function refreshRoster(force)
 if not App.Running or not playerDropdown then return end
 local ps=otherPlayers()
 if sortRoster=="距离"then
  local own=hrp()
  table.sort(ps,function(a,b)
   local ra,rb=hrp(a),hrp(b)
   local da=own and ra and (own.Position-ra.Position).Magnitude or math.huge
   local db=own and rb and (own.Position-rb.Position).Magnitude or math.huge
   return da<db
  end)
 else table.sort(ps,function(a,b)return a.Name:lower()<b.Name:lower()end)end
 local sig={}
 local list={}
 local lookupLabels={}
 for _,p in ipairs(ps)do
  local item=p.DisplayName.."  (@"..p.Name..")"
  if rosterFilter=="" or item:lower():find(rosterFilter,1,true) then
   table.insert(list,item)
   lookupLabels[item]=p.Name
  end
  table.insert(sig,tostring(p.UserId)..":"..p.DisplayName)
 end
 if #list==0 then list={#ps>0 and "无匹配结果：请清除搜索过滤" or "当前服务器暂无其他玩家"}end
 local signature=sortRoster.."|"..rosterFilter.."|"..table.concat(sig,";")
 if not force and rosterSignature==signature then return end
 rosterSignature=signature
 playerLabels=lookupLabels
 rosterUpdating=true
 local ok,err=pcall(function()playerDropdown:Refresh(list)end)
 if not ok then warn("[NEXUS] roster refresh failed: "..tostring(err))end
 if State.target~=""then
  for label,name in pairs(playerLabels)do
   if name==State.target then pcall(function()playerDropdown:Select(label)end)break end
  end
 end
 rosterUpdating=false
end
playerDropdown=PlayerUI:Dropdown({
 Title="在线玩家 · 展开直接选择",Desc="自动扫描、按名称搜索框过滤结果",
 Values={"正在扫描..."},Value="正在扫描...",SearchBarEnabled=false,MenuWidth=320,
 Callback=function(value)
  if rosterUpdating then return end
  local name=playerLabels[tostring(value)]
  local p=name and Players:FindFirstChild(name)
  if p then selectPlayer(p,false)end
 end
})
playerInput=PlayerUI:Input({
 Title="按用户名或昵称搜索",Placeholder="支持完整名称或前缀，和下拉框联动",Flag="playerSearch",
 Callback=function(value)
  State.target=tostring(value or "")
  rosterFilter=State.target:lower():match("^%s*(.-)%s*$")
  refreshRoster(true)
  local p=lookup(State.target)
  if p then selectPlayer(p,true)
  else chosen:SetTitle("当前选择：未找到");chosen:SetDesc("请使用下拉列表或输入前缀")end
 end
})
PlayerUI:Dropdown({Title="玩家排序",Values={"用户名","距离"},Value="用户名",
 Callback=function(value)sortRoster=value;refreshRoster(true)end})
PlayerUI:Button({Title="清除搜索过滤 / 显示所有玩家",Icon="list-filter",Callback=function()
 local selected=State.target
 rosterFilter=""
 if playerInput then pcall(function()playerInput:Set("")end)end
 State.target=selected
 refreshRoster(true)
 toast("玩家选择","已恢复完整在线名单","users")
end})
PlayerUI:Button({Title="立即刷新玩家列表",Icon="refresh-cw",Callback=function()
 refreshRoster(true)
 toast("服务器玩家","目前在线 "..#Players:GetPlayers().." 人","users")
end})
connect(Players.PlayerAdded,function()task.defer(function()refreshRoster(true)end)end)
connect(Players.PlayerRemoving,function(p)
 task.defer(function()
  if State.target==p.Name then
   State.target=""
   chosen:SetTitle("当前选择：玩家已离线")
  end
  refreshRoster(true)
 end)
end)
pcall(function()Window:Loop("nexus-roster",4,function()refreshRoster(false)end)end)
task.defer(function()refreshRoster(true)end)
PlayerUI:Button({Title="自动选取最近玩家",Icon="locate",Callback=function()
 local r=hrp()
 if not r then return end
 local closest,best=nil,math.huge
 for _,p in ipairs(otherPlayers())do
  local pr=hrp(p)
  if pr and (r.Position-pr.Position).Magnitude<best then
   closest=p;best=(r.Position-pr.Position).Magnitude
  end
 end
 if closest then
  selectPlayer(closest,false)
  toast("已选取",closest.Name,"user-check")
 end
end})
PlayerUI:Button({Title="输出当前在线玩家清单",Icon="list",Callback=function()
 local a={}
 for _,p in ipairs(otherPlayers())do table.insert(a,p.Name)end
 print("[NEXUS players] "..table.concat(a,", "))
 toast("玩家列表","已输出 "..#a.." 名玩家到控制台","users")
end})
PlayerUI:Button({Title="复制目标用户名",Icon="copy",Callback=function()
 local p=lookup(State.target)
 if p then copy(p.Name)else toast("未选择","先选择目标玩家","alert-circle")end
end})
preciseInput(PlayerUI,"自动跟随距离","followOffset",0)
local rosterCycle=0
PlayerUI:Button({Title="切换到下一位在线玩家",Icon="skip-forward",Callback=function()
 local ps=otherPlayers()
 table.sort(ps,function(a,b)return a.Name:lower()<b.Name:lower()end)
 if #ps==0 then toast("无玩家","服务器没有其他玩家","alert-circle")return end
 rosterCycle=(rosterCycle%#ps)+1
 selectPlayer(ps[rosterCycle],false)
end})
local pbox=PlayerUI:Section({Title="目标交互",Opened=false,Box=true})
pbox:Button({Title="传送到选中玩家附近",Icon="navigation",Callback=function()
 local p=lookup(State.target)
 if p and hrp(p)then teleport(hrp(p).CFrame*CFrame.new(0,0,5))
 else toast("目标无效","玩家离线或角色未加载","alert-circle")end
end})
pbox:Button({Title="观战该玩家",Icon="eye",Callback=function()
 local p=lookup(State.target)
 if p then spectate(p)else toast("未选择目标","请先搜索玩家","alert-circle")end
end})
pbox:Button({Title="停止观战",Icon="eye-off",Callback=function()spectate(nil)end})
pbox:Toggle({Title="自动跟随",Desc="本地持续移动到选中玩家身后",Flag="follow",Callback=function(v)
 if v then
  local p=lookup(State.target)
  if not p then toast("跟随失败","请选择目标玩家","alert-circle");return end
  followTarget=p.Name
 end
 State.follow=v
end})
pbox:Button({Title="复制玩家 UserId",Icon="copy",Callback=function()
 local p=lookup(State.target)
 if p then copy(p.UserId)else toast("没有选中玩家","请先搜索","alert-circle")end
end})
pbox:Button({Title="显示玩家状态",Icon="info",Callback=function()
 local p=lookup(State.target)
 if not p then toast("没有目标","请先选择玩家","alert-circle")return end
 local h=humanoid(p)
 local pr=hrp(p)
 local r=hrp()
 toast("玩家状态",p.Name.." · HP "..(h and math.floor(h.Health) or "?")..
 " · 距离 "..(r and pr and math.floor((pr.Position-r.Position).Magnitude) or "?"),"user")
end})

Travel:Paragraph({Title="传送点管理",Desc="三组位置槽位保存在本次脚本运行期间。关闭或卸载后将清空。"})
Travel:Dropdown({Title="选择位置槽",Values={"位置 1","位置 2","位置 3"},Value="位置 1",
 Callback=function(v)markerSlot=tonumber(tostring(v):match("%d"))or 1 end})
Travel:Button({Title="保存当前位置",Icon="bookmark-plus",Callback=function()
 local r=hrp()
 if r then bookmarks[markerSlot]=r.CFrame;toast("保存成功","已记录位置 "..markerSlot,"bookmark")end
end})
Travel:Button({Title="传送到保存位置",Icon="map-pin",Callback=function()
 if bookmarks[markerSlot]then teleport(bookmarks[markerSlot])
 else toast("未记录","请先保存当前槽位","alert-circle")end
end})
Travel:Button({Title="返回上次传送前位置",Icon="undo-2",Callback=function()
 if State.lastPos then teleport(State.lastPos)
 else toast("没有记录","需要先执行一次传送","alert-circle")end
end})
Travel:Toggle({Title="T 键传送到鼠标位置",Desc="开启后鼠标指向地面并按 T",Flag="clickTP",
 Callback=function(v)State.clickTP=v end})
Travel:Toggle({Title="复活后恢复上次传送位置",Flag="respawnTP",
 Callback=function(v)State.respawnTP=v end})
Travel:Button({Title="复制自身坐标",Icon="copy",Callback=function()
 local r=hrp()
 if r then copy(string.format("%.2f, %.2f, %.2f",r.Position.X,r.Position.Y,r.Position.Z))end
end})

local teleX=preciseInput(Travel,"目标坐标 X","teleX",nil)
local teleY=preciseInput(Travel,"目标坐标 Y","teleY",nil)
local teleZ=preciseInput(Travel,"目标坐标 Z","teleZ",nil)
Travel:Button({Title="读取当前坐标到输入框",Icon="locate-fixed",Callback=function()
 local r=hrp()
 if not r then return end
 State.teleX=r.Position.X;State.teleY=r.Position.Y;State.teleZ=r.Position.Z
 pcall(function()teleX:Set(tostring(State.teleX));teleY:Set(tostring(State.teleY));teleZ:Set(tostring(State.teleZ))end)
 toast("坐标已读取","可以修改数值后传送","check")
end})
Travel:Button({Title="传送到手动输入的 XYZ",Icon="navigation",Callback=function()
 local ok,err=pcall(function()
  teleport(CFrame.new(State.teleX,State.teleY,State.teleZ))
 end)
 if not ok then toast("坐标无效",err,"alert-circle")end
end})

World:Paragraph({Title="世界画面",Desc="只修改本地客户端光照、摄像机和模型可见度，不影响其他玩家。"})
World:Toggle({Title="Fullbright 全亮",Flag="fullbright",
 Callback=function(v)State.fullbright=v;setLighting()end})
World:Toggle({Title="移除环境迷雾",Flag="noFog",
 Callback=function(v)State.noFog=v;setFog()end})
World:Toggle({Title="场景 X-Ray",Desc="降低场景不透明度，最多处理 2500 个部件",Flag="xray",
 Callback=function(v)State.xray=v;refreshXray()end})
World:Slider({Title="场景透明度",Flag="xrayAlpha",Value={Min=10,Max=95,Default=60},Step=5,
 Callback=function(v)State.xrayAlpha=(tonumber(v)or 60)/100;if State.xray then refreshXray()end end})
World:Slider({Title="相机 FOV",Flag="fov",Value={Min=40,Max=120,Default=70},Step=1,
 Callback=function(v)
  State.fov=tonumber(v)or 70
  if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=State.fov end
 end})
preciseInput(World,"精确 FOV 数值","fov",1,function(n)
 if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=n end
end)
World:Button({Title="还原原始视觉参数",Icon="rotate-ccw",Callback=function()
 State.fullbright=false;State.noFog=false;State.xray=false
 setLighting();setFog();refreshXray()
 if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=startFOV end
 toast("已还原","亮度、迷雾、透视、FOV 已恢复","check")
end})

Utilities:Toggle({Title="防挂机 Anti-AFK",Desc="触发空闲事件时模拟右键点击；依赖执行器权限",Flag="antiAFK",
 Callback=function(v)State.antiAfk=v end})
local telemetry=Utilities:Button({Title="角色状态",Desc="FPS / HP / 坐标",Icon="gauge",
 Callback=function()toast("实时统计","FPS "..fps.." · 在线 "..#Players:GetPlayers(),"activity")end})
Utilities:Button({Title="重置观战与相机",Icon="camera",Callback=function()
 spectate(nil)
 if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=State.fov end
 toast("相机","已重置 CameraSubject","check")
end})
Utilities:Button({Title="停止自动跟随",Icon="hand",Callback=function()
 State.follow=false;followTarget=""
 toast("跟随","已停止","check")
end})
Utilities:Button({Title="复制当前服务器标识",Icon="copy",Callback=function()copy(game.JobId)end})
Utilities:Button({Title="列出自身角色部件",Icon="terminal",Callback=function()
 local c=char();if not c then return end
 for _,v in ipairs(c:GetChildren())do print("[NEXUS]",v.ClassName,v.Name)end
 toast("信息","已输出角色结构到控制台","check")
end})


-- ============= AIM AND PROJECTILE PAGE =============
Aim:Paragraph({
 Title="<gradient=#74dbff,#a792ff>雨 Hub · 自瞄与弹道</gradient> {crosshair}",
 Desc="摄像机视角辅助与本地轨迹显示，支持鼠标右键激活、平滑度、视野范围、墙体可见性检测。不会自动开火或修改服务器命中判定。"
})
local aimBasic=Aim:Section({Title="瞄准辅助",Opened=false,Box=true})
aimBasic:Toggle({Title="启用摄像机瞄准辅助",Flag="rainAim",Callback=function(v)
 State.aim=v
 if not v then currentAimTarget=nil end
end})
aimBasic:Toggle({Title="按住鼠标右键时辅助",Value=true,Flag="rainAimHold",
 Callback=function(v)State.aimHold=v end})
aimBasic:Dropdown({Title="锁定圈定位模式",
 Values={"跟随鼠标","屏幕中央"},Value="跟随鼠标",Flag="rainAimCenter",
 Callback=function(v)State.aimCenterMode=v end})
aimBasic:Toggle({Title="显示目标锁人圈",Value=true,Flag="rainAimLockCircle",
 Desc="独立的绿色锁定圈会跟随目标身体，而非搜索范围圆圈",
 Callback=function(v)State.aimLockRing=v end})
aimBasic:Toggle({Title="保持已选定目标",Flag="rainAimSticky",
 Desc="目标仍在搜索圈内时优先保持原目标，减少来回切换",
 Callback=function(v)State.aimSticky=v end})
aimBasic:Slider({Title="目标锁人圈半径",Value={Min=10,Max=75,Default=28},Step=2,
 Callback=function(v)State.aimLockRadius=tonumber(v)or 28 end})
aimBasic:Dropdown({Title="瞄准位置",Values={"头部","躯干","根部"},Value="头部",Flag="rainAimPart",
 Callback=function(v)State.aimPart=v end})
aimBasic:Slider({Title="视野半径（像素）",Value={Min=40,Max=450,Default=170},Step=10,Flag="rainAimFOV",
 Callback=function(v)State.aimRadius=tonumber(v)or 170 end})
aimBasic:Slider({Title="瞄准平滑速度",Value={Min=1,Max=40,Default=11},Step=1,Flag="rainAimSmooth",
 Callback=function(v)State.aimSmooth=tonumber(v)or 11 end})
local aimFilters=Aim:Section({Title="目标筛选",Opened=false,Box=true})
aimFilters:Toggle({Title="队伍过滤",Value=true,Flag="rainAimTeams",
 Callback=function(v)State.aimTeamCheck=v end})
aimFilters:Toggle({Title="墙体阻挡检测",Value=true,Flag="rainAimWalls",
 Callback=function(v)State.aimWallCheck=v end})
aimFilters:Toggle({Title="只选择存活目标",Value=true,Flag="rainAimAlive",
 Callback=function(v)State.aimAliveOnly=v end})
aimFilters:Toggle({Title="显示视野圆圈",Value=true,Flag="rainAimCircle",
 Callback=function(v)State.aimShowRadius=v end})
aimFilters:Toggle({Title="显示当前候选玩家",Value=true,Flag="rainAimTarget",
 Callback=function(v)State.aimShowTarget=v end})
aimFilters:Slider({Title="最远目标距离",Value={Min=50,Max=4000,Default=1500},Step=50,
 Callback=function(v)State.aimMaxDistance=tonumber(v)or 1500 end})
preciseInput(aimFilters,"精准 FOV 像素半径","aimRadius",1)
preciseInput(aimFilters,"精准瞄准平滑系数","aimSmooth",0)
preciseInput(aimFilters,"精准目标距离","aimMaxDistance",0)
local aimTraces=Aim:Section({Title="子弹追踪 / 轨迹",Opened=false,Box=true})
aimTraces:Toggle({Title="启用弹道可视化",Desc="跟踪客户端能观察到的飞行物零件，绘制短尾迹",Flag="rainBulletTrace",
 Callback=function(v)
  State.projectileTrace=v
  if v then scanProjectiles()else clearProjectiles()end
 end})
aimTraces:Slider({Title="尾迹持续时间（秒×100）",Value={Min=10,Max=150,Default=40},Step=5,
 Callback=function(v)State.projectileLifetime=(tonumber(v)or 40)/100 end})
aimTraces:Colorpicker({Title="弹道轨迹颜色",Default=State.projectileColor,
 Callback=function(c)if typeof(c)=="Color3"then State.projectileColor=c end end})
aimTraces:Button({Title="重新扫描场景内的飞行物",Icon="refresh-cw",
 Callback=function()scanProjectiles();toast("弹道扫描","当前追踪对象 "..trackedCount,"eye")end})
aimTraces:Button({Title="清理所有追踪线",Icon="trash-2",
 Callback=function()clearProjectiles();toast("弹道","已清理全部追踪线","check")end})
Aim:Paragraph({Title="跨游戏兼容性",Desc="不同游戏可能采用 Raycast 射击，子弹不一定是 BasePart 实例；这种情况下可能没有可追踪的物理弹道。摄像机辅助也可能被游戏自定义相机覆盖。"})


-- ============= MULTI-PAGE UNIVERSAL TOOLBOX =============
local toolPages=Utilities:Category({
 Title="雨 Hub 工具分区",Default="背包工具",
 Options={
  {Title="背包工具",Icon="backpack"},
  {Title="传送道具",Icon="map-pinned"},
  {Title="角色工具",Icon="person-standing"},
  {Title="雨 Hub 标识",Icon="cloud-rain"},
  {Title="调试信息",Icon="terminal"}
 }
})

-- ANUI's category preset uses pale green button backgrounds and translucent
-- lavender labels. Force dark, fully opaque text for readable contrast.
local function fixToolPageContrast()
 if not toolPages or not toolPages.ElementFrame then return end
 for _,obj in ipairs(toolPages.ElementFrame:GetDescendants())do
  if obj:IsA("TextLabel") or obj:IsA("TextButton")then
   if obj.Text~=""then
    obj.TextColor3=Color3.fromRGB(17,36,49)
    obj.TextTransparency=0
    obj.Font=Enum.Font.GothamBold
    obj.TextStrokeTransparency=1
    if obj.TextSize<13 then obj.TextSize=13 end
    if not obj:GetAttribute("RainContrastBound")then
     obj:SetAttribute("RainContrastBound",true)
     connect(obj:GetPropertyChangedSignal("TextColor3"),function()
      if obj.TextColor3~=Color3.fromRGB(17,36,49)then obj.TextColor3=Color3.fromRGB(17,36,49)end
     end)
     connect(obj:GetPropertyChangedSignal("TextTransparency"),function()
      if obj.TextTransparency~=0 then obj.TextTransparency=0 end
     end)
    end
   end
  end
 end
end
fixToolPageContrast()
App.FixToolContrast=fixToolPageContrast

local selectedToolName=""
local backpackDropdown
local function inventoryNames()
 local values={}
 local seen={}
 for _,container in ipairs({LP:FindFirstChildOfClass("Backpack"),char()})do
  if container then
   for _,obj in ipairs(container:GetChildren())do
    if obj:IsA("Tool") and not obj:GetAttribute("RainHubLocalTool") and not seen[obj.Name] then
     table.insert(values,obj.Name)
     seen[obj.Name]=true
    end
   end
  end
 end
 table.sort(values)
 if #values==0 then values={"当前背包没有可复制的 Tool"} end
 return values
end
toolPages:With("背包工具",function()
 Utilities:Paragraph({
  Title="本地道具管理",Desc="支持扫描背包 Tool、生成本地外观副本并清理。复制副本不经过服务器发放，也不能保证具有原物品能力。"
 })
 backpackDropdown=Utilities:Dropdown({
  Title="从背包选择 Tool",Values={"正在扫描..."},Value="正在扫描...",
  Callback=function(v)selectedToolName=tostring(v)end
 })
 Utilities:Button({Title="刷新背包道具清单",Icon="refresh-cw",Callback=function()
  backpackDropdown:Refresh(inventoryNames())
  toast("道具列表","已扫描背包与手持装备","backpack")
 end})
 Utilities:Button({Title="复制当前选择的 Tool（本地）",Icon="copy",Callback=function()
  duplicateHeldTool(selectedToolName)
 end})
 Utilities:Button({Title="复制手持 / 第一个原版物品（本地）",Icon="copy-plus",Callback=function()
  duplicateHeldTool("")
 end})
 Utilities:Button({Title="删除雨 Hub 创建的全部本地道具",Icon="trash-2",
  Callback=function()removeOwnedTools();toast("道具清理","所有雨 Hub 本地生成道具已清理","check")end})
end)
toolPages:With("传送道具",function()
 Utilities:Paragraph({Title="通用 Tool 发放",Desc="发放到 Roblox Backpack，装备道具后点击即可使用。传送行为仍受当前游戏服务器规则限制。"})
 Utilities:Button({Title="发放「点击传送」Tool",Icon="mouse-pointer-2",Callback=giveClickTeleport})
 Utilities:Button({Title="发放「记录 / 回程」Tool",Icon="bookmark-plus",Callback=givePositionTool})
 Utilities:Button({Title="发放「穿墙切换」Tool",Icon="layers",Callback=giveWallTool})
 Utilities:Button({Title="发放「飞行切换」Tool",Icon="wind",Callback=giveFlyTool})
 Utilities:Button({Title="发放全套 4 个实用 Tool",Icon="package-plus",Callback=function()
  giveClickTeleport();givePositionTool();giveWallTool();giveFlyTool()
 end})
end)
toolPages:With("角色工具",function()
 Utilities:Paragraph({Title="角色控制",Desc="角色重生后尽量自动恢复当前模式；部分状态受服务器控制。"})
 Utilities:Button({Title="给角色一次跳跃",Icon="arrow-up",Callback=function()
  local h=humanoid()
  if h then h:ChangeState(Enum.HumanoidStateType.Jumping)end
 end})
 Utilities:Button({Title="清零当前异常速度",Icon="shield-check",Callback=function()
  local r=hrp()
  if r then r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero;toast("已归零","已清理客户端角速度和线速度","check")end
 end})
 Utilities:Button({Title="保存当前安全位置",Icon="bookmark",Callback=function()
  local r=hrp()
  if r then guard.safeCFrame=r.CFrame;guard.lastSafe=os.clock();toast("安全位置","已记录","check")end
 end})
 Utilities:Button({Title="回到手动保存的安全位置",Icon="map-pin",Callback=function()
  if guard.safeCFrame then teleport(guard.safeCFrame)else toast("暂无位置","请先记录安全位置","alert-circle")end
 end})
 Utilities:Button({Title="恢复标准移动属性",Icon="rotate-ccw",Callback=function()
  State.speedEnabled=false;State.jumpEnabled=false;State.hipEnabled=false
  restoreMovement();toast("移动","已还原角色初始属性","check")
 end})
end)
toolPages:With("雨 Hub 标识",function()
 Utilities:Paragraph({Title="雨 Hub 🌧️ 专属标签",Desc="精致的头顶圆角渐变徽章，写有「雨🌧️脚本用户」。本地客户端可显示自己的标签。其他客户端运行脚本的用户无法被无服务端协作的通用客户端脚本自动可靠识别。"})
 Utilities:Toggle({Title="显示自己的「雨🌧️脚本用户」标签",Value=true,Flag="rainOwnBadge",Callback=function(v)
  State.selfTag=v;rebuildBadges()
 end})
 Utilities:Toggle({Title="显示手动标记的玩家标签",Value=true,Flag="rainOtherBadge",Callback=function(v)
  State.showMarkedTags=v;rebuildBadges()
 end})
 Utilities:Slider({Title="头顶标签缩放",Value={Min=60,Max=160,Default=100},Step=5,Flag="rainBadgeSize",Callback=function(v)
  State.tagScale=(tonumber(v)or 100)/100;rebuildBadges()
 end})
 Utilities:Button({Title="手动标记玩家页面选中的目标",Icon="user-round-check",Callback=function()
  local p=lookup(State.target)
  if not p then toast("标记失败","请先在玩家页面选中目标","alert-circle")return end
  markedPlayers[p]=true;rebuildBadges()
  toast("本地标记",p.Name.." 已标记（并非脚本用户身份验证）","check")
 end})
 Utilities:Button({Title="移除目标玩家标记",Icon="user-round-x",Callback=function()
  local p=lookup(State.target)
  if p then markedPlayers[p]=nil;removeBadge(p)end
 end})
 Utilities:Button({Title="刷新所有标签",Icon="refresh-cw",Callback=function()rebuildBadges()end})
end)
toolPages:With("调试信息",function()
 Utilities:Paragraph({Title="当前游戏诊断",Desc="检查脚本状态、设备和项目通用接口，不会向外部上传身份资料。"})
 Utilities:Button({Title="查看雨 Hub 当前功能状态",Icon="activity",Callback=function()
  local active={}
  for _,pair in ipairs({
   {"ESP",State.esp},{"飞行",State.fly},{"穿墙",State.noclip},
   {"防甩飞",State.antiFling},{"自瞄",State.aim},{"弹道",State.projectileTrace}
  })do if pair[2] then table.insert(active,pair[1])end end
  toast("已开启的模块",#active>0 and table.concat(active," / ")or"无","info")
 end})
 Utilities:Button({Title="复制游戏 JobId",Icon="clipboard",Callback=function()copy(game.JobId)end})
 Utilities:Button({Title="输出玩家与场景信息",Icon="terminal",Callback=function()
  print("[雨 Hub]",game.Name,game.PlaceId,"players",#Players:GetPlayers(),"trackedProjectiles",trackedCount)
  toast("日志","已输出到执行器控制台","terminal")
 end})
 Utilities:Button({Title="清理弹道与头顶标记",Icon="eraser",Callback=function()
  clearProjectiles()
  for p in pairs(markedPlayers)do markedPlayers[p]=nil end
  rebuildBadges()
  toast("清理完毕","已清理特效和手动玩家标签","check")
 end})
end)
task.defer(function()
 if backpackDropdown and App.Running then
  pcall(function()backpackDropdown:Refresh(inventoryNames())end)
 end
end)


local function buildCombatUI()
 local tab=App.CombatTab
 tab:Paragraph({Title="<gradient=#68CCFF,#B89FFF>雨 Hub · 物理扩展</gradient> {orbit}",
  Desc="以下是客户端物理和视觉辅助。服务器对移动、碰撞、血量有最终决定权；不会通过未知 RemoteEvent 获取伤害权限。"})
 local protect=tab:Section({Title="反自瞄 / 姿态干扰",Opened=false,Box=true})
 protect:Toggle({Title="开启反自瞄动作",Flag="rainAntiAim",
  Desc="低幅度 FPS 姿态微摆；不是服务端反自瞄，尽量避免明显的抽搐动作",
  Callback=function(v)App.Combat.SetAntiAim(v)end})
 protect:Dropdown({Title="FPS 姿态模式",Values={"微摆","旋转"},Value="微摆",
  Callback=function(v)State.antiAimStyle=v end})
 protect:Slider({Title="微摆角度",Value={Min=0,Max=25,Default=8},Step=1,
  Callback=function(v)State.antiAimAngle=tonumber(v)or 85 end})
 preciseInput(protect,"自定义转向角度","antiAimAngle",0)
 protect:Slider({Title="转向频率 / 速度",Value={Min=1,Max=15,Default=2},Step=1,
  Callback=function(v)State.antiAimSpeed=tonumber(v)or 6 end})
 preciseInput(protect,"自定义转向频率","antiAimSpeed",0)
 local spinTab=tab:Section({Title="自我旋转",Opened=false,Box=true})
 spinTab:Toggle({Title="开启自我旋转",Desc="持续绕自身竖轴旋转；与反自瞄互斥",Flag="rainSelfSpin",
  Callback=function(v)App.Combat.SetSelfSpin(v)end})
 spinTab:Slider({Title="自转速度（度/秒）",Value={Min=0,Max=3600,Default=360},Step=30,
  Callback=function(v)State.selfSpinSpeed=tonumber(v)or 360 end})
 preciseInput(spinTab,"精确自转速度（度/秒，负数反方向）","selfSpinSpeed",nil)
 local hole=tab:Section({Title="全场物品漩涡",Opened=false,Box=true})
 hole:Dropdown({Title="黑洞吸附位置",Values={"角色周围","角色前方","鼠标指向"},Value="角色周围",
  Callback=function(v)State.blackHoleMode=v end})
 hole:Toggle({Title="生成跟随角色的黑洞",Flag="rainBlackHole",
  Desc="持续扫描全场已加载松散物体并吸到身边快速绕圈；不会强制控制服务器拥有的物体",
  Callback=function(v)if v then App.Combat.StartBlackHole()else App.Combat.StopBlackHole()end end})
 hole:Toggle({Title="显示黑洞发光特效",Value=true,
  Callback=function(v)State.blackHoleVisual=v end})
 hole:Slider({Title="搜索范围（0 为全场）",Value={Min=0,Max=1500,Default=0},Step=50,
  Callback=function(v)State.blackHoleRadius=tonumber(v)or 35 end})
 preciseInput(hole,"精确吸引半径","blackHoleRadius",1)
 hole:Slider({Title="聚拢速度",Value={Min=20,Max=500,Default=180},Step=20,
  Callback=function(v)State.blackHoleStrength=tonumber(v)or 45 end})
 preciseInput(hole,"精确黑洞力度","blackHoleStrength",0)
 preciseInput(hole,"黑洞环绕速度（弧度/秒）","blackHoleOrbitSpeed",0)
 preciseInput(hole,"黑洞距离角色前方","blackHoleOffset",0)
 preciseInput(hole,"角色周围吸附高度","blackHoleHeight",-30)
 preciseInput(hole,"可吸附物品最大质量","blackHoleMaxMass",1)
 preciseInput(hole,"最多处理物体数","blackHoleMaxParts",1)
 hole:Button({Title="移除黑洞并清理特效",Icon="trash-2",
  Callback=function()App.Combat.StopBlackHole()end})
 local grab=tab:Section({Title="鼠标 / 手势吸附物品",Opened=false,Box=true})
 grab:Paragraph({Title="物品拖拽说明",Desc="PC：开启后按住 Alt + 鼠标左键选中散落物品，移动鼠标控制方向；滚轮调远近，R 旋转，F 释放。触屏：长按/按住可移动物品。仅对未锚定、客户端可影响的物品有效。"})
 grab:Toggle({Title="启用手势物品操控",Flag="rainGestureGrab",Callback=function(v)
  State.grabEnabled=v
  if not v and App.Grab then App.Grab.Release()end
 end})
 grab:Slider({Title="最大选取距离",Value={Min=5,Max=150,Default=60},Step=5,
  Callback=function(v)State.grabRange=tonumber(v)or 60 end})
 preciseInput(grab,"精确拖拽力度","grabStrength",1)
 preciseInput(grab,"精确选取距离","grabRange",1)
 preciseInput(grab,"最大可抓物品质量","grabMaxMass",1)
 grab:Button({Title="松开当前吸附的物品",Icon="hand",
  Callback=function()if App.Grab then App.Grab.Release()end end})
 grab:Button({Title="旋转当前物品",Icon="rotate-cw",
  Callback=function()if App.Grab then App.Grab.Spin()end end})
 local physics=tab:Section({Title="物理接触 / 甩飞",Opened=false,Box=true})
 physics:Toggle({Title="触碰死亡（本地尝试）",
  Desc="修改本地接触对象的 Humanoid 血量；服务器可能忽略，不保证别人真正死亡",
  Callback=function(v)App.Combat.SetTouch(v)end})
 physics:Button({Title="启动短时物理甩飞",Icon="rotate-cw",
  Desc="仅操作自己角色的旋转力；能否推动他人取决于服务器",
  Callback=function()
   local ok,err=App.Combat.StartFling()
   if not ok then toast("无法启动",err,"alert-circle")end
  end})
 physics:Button({Title="停止物理甩飞",Icon="square",Callback=function()App.Combat.StopFling()end})
 physics:Slider({Title="旋转强度",Value={Min=50,Max=4000,Default=1800},Step=50,
  Callback=function(v)State.flingSpeed=tonumber(v)or 1800 end})
 preciseInput(physics,"精确旋转速度","flingSpeed",0)
 physics:Slider({Title="旋转时间（0.1 秒）",Value={Min=2,Max=50,Default=13},Step=1,
  Callback=function(v)State.flingDuration=(tonumber(v)or 13)/10 end})
 preciseInput(physics,"精确旋转持续秒数","flingDuration",.2)
 physics:Toggle({Title="靠近玩家页面选中的目标",Desc="只在物理甩飞期间短距离靠近选中角色",
  Callback=function(v)State.flingApproach=v end})
 preciseInput(physics,"甩飞冷却秒数","flingCooldown",1)
 tab:Button({Title="紧急停止全部对抗和物理功能",Icon="shield-alert",
  Callback=function()App.Combat.Emergency()end})
 App.CombatGroups={protect,spinTab,hole,grab,physics}
end
buildCombatUI()


local function buildHotkeyUI()
 local tab=App.HotkeyTab
 tab:Paragraph({Title="<gradient=#56CBFF,#B69DFF>雨 Hub · 快捷键中心</gradient> {keyboard}",
 Desc="点击按键控件并按新键即可绑定。已预留菜单键 RightShift、移动键与 T，避免冲突。绑定保存到本地，重新加载自动恢复。"})
 local binds=tab:Section({Title="功能快捷键",Opened=false,Box=true})
 local controls={}
 for _,action in ipairs(App.HotkeyActions)do
  controls[action]=binds:Keybind({
   Title=App.HotkeyLabels[action].." · "..(App.Hotkeys[action] or "未绑定"),
   Value=App.Hotkeys[action] or App.HotkeyDefaults[action],
   Callback=function(value)
    local ok,reason=App.Combat.SetHotkey(action,value)
    if not ok then toast("绑定失败",reason,"alert-circle")end
   end
  })
 end
 App.HotkeyControls=controls
 local other=tab:Section({Title="快捷键配置",Opened=false,Box=true})
 other:Toggle({Title="快捷键触发提示通知",Value=true,
  Callback=function(v)State.hotkeyHints=v end})
 other:Button({Title="保存当前所有快捷键",Icon="save",Callback=function()
  local ok,err=App.SaveHotkeys()
  toast(ok and "快捷键已保存" or "保存失败",ok and App.HotkeyFile or err,ok and "check" or "alert-circle")
 end})
 other:Button({Title="从本地重新读取快捷键",Icon="folder-open",Callback=function()
  local ok=App.LoadHotkeys()
  if ok then
   for key,c in pairs(controls)do
    if App.Hotkeys[key] then pcall(function()c:Set(App.Hotkeys[key])end)end
   end
  end
  toast(ok and "快捷键已恢复" or "无法读取",ok and App.HotkeyFile or "文件不存在或接口不可用",ok and "check" or "alert-circle")
 end})
 other:Button({Title="恢复默认快捷键",Icon="rotate-ccw",Callback=function()
  for key,v in pairs(App.HotkeyDefaults)do
   App.Hotkeys[key]=v
  end
  local ok=App.SaveHotkeys()
  for key,c in pairs(controls)do pcall(function()c:Set(App.Hotkeys[key])end)end
  toast("快捷键已重置",ok and "默认键位已保存" or "当前运行已恢复默认键位","check")
 end})
 other:Paragraph({Title="预设键位",Desc="F6 飞行 · F7 穿墙 · F8 防甩飞 · F9 自瞄\nF10 反自瞄 · F11 黑洞 · F12 触碰模式\nG 物理甩飞 · Insert 点击传送 · Home 紧急停止"})
end
buildHotkeyUI()

-- ============== RAIN HUB MUSIC CENTER ==============
function App.BuildMusicUI()
 local tab=App.MusicTab
 local music=App.Music
 if not music then return end
 local pendingName=""
 local pendingRobloxId=""
 local pendingNeteaseId=""
 local currentOptions={}
 local currentDropdown
 local titleStatus=tab:Button({
  Title="♫ 东南苦山行 · 殷正洋",Icon="disc-3",
  Desc="播放器正在初始化……",
  Callback=function()
   local state,err=music.GetStatus()
   toast("雨 Hub 音乐",state..(err~="" and ("\n"..err) or ""),"music-2")
  end
 })
 tab:Paragraph({
  Title="<gradient=#72D4FF,#AF8AFF>雨 Hub · Music Player</gradient> {music-2}",
  Desc="默认曲目：殷正洋《东南苦山行》\n"
   .."支持 Roblox 音频资源播放及网易云歌曲链接/ID 管理。\n"
   .."Roblox 不能直接将网易云网页或 MP3 链接作为 SoundId，必须关联当前游戏有权限播放的 Roblox 音频。"
 })
 local basic=tab:Section({Title="播放控制",Opened=false,Box=true})
 basic:Button({Title="播放选中的歌曲",Icon="play",Callback=function()
  local ok,err=music.Play()
  if not ok then toast("播放不可用",err,"alert-circle")end
 end})
 basic:Button({Title="暂停 / 继续",Icon="pause",Callback=function()
  music.Pause()
 end})
 basic:Button({Title="停止播放",Icon="square",Callback=function()
  music.Stop()
 end})
 basic:Button({Title="上一首",Icon="skip-back",Callback=function()
  local ok,err=music.Prev()
  if not ok then toast("无法切歌",err,"alert-circle")end
 end})
 basic:Button({Title="下一首",Icon="skip-forward",Callback=function()
  local ok,err=music.Next()
  if not ok then toast("无法切歌",err,"alert-circle")end
 end})
 basic:Slider({
  Title="音量（0-200%）",Flag="rainMusicVolume",
  Value={Min=0,Max=200,Default=math.floor(music.GetVolume()*100)},
  Step=5,Callback=function(v)music.SetVolume((tonumber(v)or 50)/100)end
 })
 basic:Slider({
  Title="播放倍速（×100）",Flag="rainMusicSpeed",
  Value={Min=50,Max=200,Default=math.floor(music.GetSpeed()*100)},
  Step=5,Callback=function(v)music.SetSpeed((tonumber(v)or 100)/100)end
 })
 basic:Slider({
  Title="跳转至曲目进度（%）",Value={Min=0,Max=99,Default=0},Step=1,
  Callback=function(percent)
   if not music.Seek(music.Sound.TimeLength*(tonumber(percent)or 0)/100)then
    toast("无法跳转","当前音乐未加载完成","alert-circle")
   end
  end
 })
 basic:Toggle({Title="单曲循环",Value=music.IsLoop(),Flag="rainMusicLoop",
  Callback=function(v)music.SetLoop(v)end})
 basic:Toggle({Title="随机下一首",Value=music.IsShuffle(),Flag="rainMusicShuffle",
  Callback=function(v)music.SetShuffle(v)end})
 basic:Toggle({Title="启动时自动播放",Value=music.IsAutoplay(),Flag="rainMusicAutoplay",
  Callback=function(v)music.SetAutoPlay(v)end})

 local list=tab:Section({Title="音乐列表",Opened=false,Box=true})
 local options={}
 local function rebuildList(force)
  table.clear(options)
  table.clear(currentOptions)
  for i,item in ipairs(music.Playlist())do
   local label=string.format("%02d  %s · %s",i,item.title,item.artist)
   options[#options+1]=label
   currentOptions[label]=i
  end
  if currentDropdown then
   pcall(function()currentDropdown:Refresh(options)end)
   if force and options[music.GetIndex()]then
    pcall(function()currentDropdown:Select(options[music.GetIndex()])end)
   end
  end
 end
 local initial={}
 for i,item in ipairs(music.Playlist())do
  local label=string.format("%02d  %s · %s",i,item.title,item.artist)
  initial[#initial+1]=label
  currentOptions[label]=i
 end
 currentDropdown=list:Dropdown({
  Title="选择歌曲",Values=initial,
  Value=initial[music.GetIndex()]or initial[1],
  Callback=function(label)
   local i=currentOptions[tostring(label)]
   if i then music.Select(i)end
  end
 })
 list:Button({Title="刷新音乐列表",Icon="refresh-cw",Callback=function()rebuildList(true)end})
 list:Button({Title="删除当前选中曲目",Icon="trash-2",Callback=function()
  local ok,err=music.Remove()
  toast(ok and "已删除" or "删除失败",err,ok and "check" or "alert-circle")
  rebuildList(true)
 end})
 list:Button({Title="保存音乐列表和播放设置",Icon="save",Callback=function()
  local ok,err=music.Save()
  toast(ok and "已保存" or "保存失败",ok and "RainHub/music-v1.json" or tostring(err),ok and "check" or "alert-circle")
 end})

 local add=tab:Section({Title="添加 Roblox 音频",Opened=false,Box=true})
 add:Input({Title="曲目名称",Placeholder="例如：喜欢的背景音乐",Callback=function(v)pendingName=tostring(v or "")end})
 add:Input({Title="Roblox 音频 ID",Placeholder="输入数字 ID 或 rbxassetid://...",Callback=function(v)pendingRobloxId=tostring(v or "")end})
 add:Button({Title="加入 Roblox 播放列表",Icon="list-plus",Callback=function()
  local ok,err=music.AddRoblox(pendingName,pendingRobloxId)
  toast(ok and "添加成功" or "添加失败",err,ok and "check" or "alert-circle")
  if ok then rebuildList(true)end
 end})
 add:Button({Title="给当前歌曲关联这个 Roblox ID",Icon="link",Callback=function()
  local ok,err=music.BindRoblox(pendingRobloxId)
  toast(ok and "已关联" or "关联失败",err,ok and "check" or "alert-circle")
 end})
 add:Button({Title="播放刚输入的 Roblox 音频",Icon="play-circle",Callback=function()
  local ok,err=music.BindRoblox(pendingRobloxId)
  if ok then
   local played,msg=music.Play()
   if not played then toast("播放失败",msg,"alert-circle")end
  else toast("无效 ID",err,"alert-circle")end
 end})

 local netease=tab:Section({Title="网易云音乐歌曲管理",Opened=false,Box=true})
 netease:Paragraph({
  Title="网易云兼容模式",
  Desc="接受 music.163.com/song?id=...、/#/song?id=... 和数字歌曲 ID。\n"
    .."自动读取歌曲编号并保存条目；游戏内发声需另外关联有权限使用的 Roblox 音频资源。"
 })
 netease:Input({Title="网易云歌曲名称",Placeholder="例如：东南苦山行",Callback=function(v)pendingName=tostring(v or "")end})
 netease:Input({Title="网易云歌曲链接 / ID",Placeholder="粘贴 music.163.com/song?id=...",Callback=function(v)pendingNeteaseId=tostring(v or "")end})
 netease:Button({Title="导入网易云歌曲条目",Icon="list-music",Callback=function()
  local ok,err=music.AddNetease(pendingName,pendingNeteaseId)
  toast(ok and "已添加" or "导入失败",err,ok and "check" or "alert-circle")
  if ok then rebuildList(true)end
 end})
 netease:Button({Title="复制当前网易云歌曲分享链接",Icon="copy",Callback=function()
  local link=music.GetNeteaseLink()
  if link==""then toast("没有网易云链接","请选中网易云来源的歌曲","alert-circle")
  else copy(link)end
 end})
 netease:Paragraph({
  Title="默认音乐文件",
  Desc="如果你有合法授权的曲目文件，可将它放在 RainHub/music/default.mp3。"
    .."\n执行器支持 getcustomasset / getsynasset 时，雨 Hub 会优先尝试加载。"
    .."\n否则请在上方输入有权限使用的 Roblox 音频 ID，绑定到默认歌曲。"
 })

 local diagnostics=tab:Section({Title="播放状态与故障诊断",Opened=false,Box=true})
 diagnostics:Button({Title="检查是否有声音",Icon="volume-2",Callback=function()
  local s=music.Sound
  local state,err=music.GetStatus()
  toast("音频状态",state.."\n加载："..tostring(s.IsLoaded)..
   " · 正在播放："..tostring(s.IsPlaying)..
   " · 音频 ID："..(s.SoundId~=""and s.SoundId or "无")..
   (err~=""and ("\n"..err)or ""),"activity")
 end})
 diagnostics:Button({Title="重新尝试加载当前音频",Icon="refresh-ccw",Callback=function()
  local ok,err=music.Play()
  if not ok then toast("音源配置缺失",err,"alert-circle")end
 end})
 diagnostics:Paragraph({Title="Roblox 音频权限",Desc="即使 Roblox Sound:Play() 没有抛错，资源若不存在、被移除或当前游戏无访问权限，也可能保持静音。当前玩家只会听见自己的本地播放器，其他玩家不会自动听到。"})
 local lastTick=0
 pcall(function()
  Window:StatusLoop("rain-music",.5,function()
   if not App.Running then return end
   music.Tick()
   local info=music.Current()
   local status,err=music.GetStatus()
   local snd=music.Sound
   local t=music.FormatTime(snd.TimePosition)
   local total=music.FormatTime(snd.TimeLength)
   local title=info and (info.title.." · "..info.artist) or "未选择"
   titleStatus:SetTitle("♫  "..title)
   titleStatus:SetDesc(status.."   │   "..t.." / "..total..
    "   │   音量 "..math.floor(snd.Volume*100).."%"..
    (err~=""and ("\n"..err:sub(1,110))or""))
  end)
 end)
 App.MusicRefreshList=rebuildList
 App.MusicGroups={basic,list,add,netease,diagnostics}
end
App.BuildMusicUI()

-- v2.4 adaptive performance presets tune scheduling without bypassing the Roblox renderer.
App.SetPerformanceMode=function(value)
 State.perfMode=value
 if value=="画质优先"then
  State.perfEspInterval=.09
  State.perfAimInterval=.07
  State.perfProjectileScan=2
  State.perfEffectsLimit=3500
 elseif value=="高帧率"then
  State.perfEspInterval=.3
  State.perfAimInterval=.18
  State.perfProjectileScan=8
  State.perfEffectsLimit=1300
 else
  State.perfMode="均衡"
  State.perfEspInterval=.14
  State.perfAimInterval=.1
  State.perfProjectileScan=4
  State.perfEffectsLimit=2500
 end
end
do
local perfSettings=Performance:Section({Title="帧率与刷新调度",Opened=false,Box=true})
perfSettings:Paragraph({Title="性能预设",Desc="画质优先：更新更流畅，CPU 使用更多；均衡：默认；高帧率：降低 ESP、瞄准扫描和弹道查询频率。不会承诺突破 Roblox/设备本身的帧率限制。"})
perfSettings:Dropdown({Title="性能预设",Values={"画质优先","均衡","高帧率"},Value="均衡",
 Callback=function(v)App.SetPerformanceMode(v)end})
perfSettings:Toggle({Title="FPS 低时自动减少更新次数",Value=true,Flag="rainAdaptiveFPS",
 Callback=function(v)State.perfAutoAdjust=v end})
perfSettings:Slider({Title="ESP 刷新间隔（毫秒）",Value={Min=60,Max=400,Default=140},Step=10,
 Callback=function(v)State.perfEspInterval=(tonumber(v)or 140)/1000 end})
perfSettings:Slider({Title="目标扫描间隔（毫秒）",Value={Min=40,Max=300,Default=100},Step=10,
 Callback=function(v)State.perfAimInterval=(tonumber(v)or 100)/1000 end})
perfSettings:Slider({Title="弹道场景检查周期（秒）",Value={Min=1,Max=15,Default=4},Step=1,
 Callback=function(v)State.perfProjectileScan=tonumber(v)or 4 end})
perfSettings:Slider({Title="一次性特效优化的最大实例数",Value={Min=500,Max=7000,Default=2500},Step=250,
 Callback=function(v)State.perfEffectsLimit=tonumber(v)or 2500 end})
perfSettings:Button({Title="重置性能参数为均衡",Icon="rotate-ccw",
 Callback=function()App.SetPerformanceMode("均衡");toast("性能","已恢复均衡调度参数","check")end})
perfSettings:Button({Title="检查当前帧率",Icon="activity",
 Callback=function()
  toast("雨 Hub 性能","FPS "..fps.." · 模式 "..State.perfMode.." · ESP "..math.floor(State.perfEspInterval*1000).."ms","gauge")
 end})

end -- performance tuning UI scope
Performance:Paragraph({Title="低负载模式",Desc="关闭本地粒子、拖尾、光束与动态阴影；只改变客户端表现。切换后可还原原始属性。适合人数多、特效重的服务器。"})
Performance:Toggle({Title="低特效 / FPS Boost",Flag="performance",
 Callback=function(v)
  State.performance=v
  setPerformance(v)
  toast("性能模式",v and "已降低客户端部分特效负担" or "已恢复保存的特效","gauge")
 end})
Performance:Button({Title="重新应用性能优化",Icon="refresh-cw",Callback=function()
 if State.performance then setPerformance(true);toast("性能","已经重新扫描当前场景","check")end
end})
Performance:Button({Title="恢复全部原始特效",Icon="rotate-ccw",Callback=function()
 State.performance=false;setPerformance(false)
 toast("性能","所有已备份效果已还原","check")
end})
-- Process only newly created effects, avoiding expensive full-scene scans every six seconds.
connect(workspace.DescendantAdded,function(obj)
 if not State.performance then return end
 if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or
    obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")then
  if perfSaved[obj]==nil then perfSaved[obj]={property="Enabled",value=obj.Enabled}end
  obj.Enabled=false
 elseif obj:IsA("BasePart") and obj.CastShadow then
  if perfSaved[obj]==nil then perfSaved[obj]={property="CastShadow",value=obj.CastShadow}end
  obj.CastShadow=false
 end
end)

App.MusicVisibility=Settings:Section({Title="音乐功能",Opened=false,Box=true})
App.MusicVisibility:Toggle({
 Title="在侧栏显示音乐播放器",
 Desc="默认隐藏；控制入口显示，不会自动开始播放",
 Value=State.musicVisible,
 Callback=function(v)
  State.musicVisible=v
  if App.RefreshUIMode then App.RefreshUIMode()end
  saveDisplaySettings()
 end
})
App.NavSettings=Settings:Section({Title="侧栏布局",Opened=true,Box=true})
App.NavSettings:Toggle({Title="使用四组折叠导航",Desc="关闭：所有功能直接显示在左侧；开启：按四大类折叠显示",
 Value=State.sidebarGrouped,Callback=function(v)
  State.sidebarGrouped=v
  if App.RefreshSidebarLayout then App.RefreshSidebarLayout()end
  saveDisplaySettings()
 end
})
Settings:Paragraph({
 Title="<gradient=#37CFFF,#B387FF>使用体验</gradient> {sparkles}",
 Desc="精简（默认）：保留日常功能，收起重复入口和细节参数。\n高级：显示完整工具、诊断与精细控制。自定义：自主选择显示项。"
})
local function initDisplayEditor()
local modeSelect
modeSelect=Settings:Dropdown({Title="功能展示模式",Desc="精简 / 高级 / 自定义 · 自动保存",
 Values={"精简","高级","自定义"},Value=State.uiMode,Flag="displayMode",
 Callback=function(value)
  if value=="精简" or value=="高级" or value=="自定义"then
   State.uiMode=value
   if App.RefreshUIMode then App.RefreshUIMode()end
   saveDisplaySettings()
  end
 end
})

-- ============= DISPLAY CUSTOMIZATION (saved JSON) =============
local customizableTabs={
 {"Movement","移动"}, {"Defense","防护"}, {"ESP","ESP 透视"},
 {"PlayerUI","玩家"}, {"Travel","传送"}, {"World","画面"},
 {"Aim","自瞄与弹道"}, {"Combat","对抗与物理"}, {"Hotkeys","快捷键"}, {"Music","音乐播放器"}, {"Performance","性能"}, {"Utilities","工具"}
}
local pageTitles={}
local pageKeys={}
for _,pair in ipairs(customizableTabs)do
 pageTitles[#pageTitles+1]=pair[2]
 pageKeys[pair[2]]=pair[1]
end
local editorReady=false
App.CustomizeTab:Paragraph({Title="🌧️ 自由布局中心",Desc="在这里决定哪些分类和控件要显示，修改会自动保存。总览、设置和自定义入口始终可用。"})
local customPageSection=App.CustomizeTab:Section({Title="自定义主分类",Opened=false,Box=true})
customPageSection:Paragraph({Title="自由组合菜单",Desc="主分类可单独开关。总览和设置始终可见，避免把菜单完全隐藏。切换时不关闭相关功能。"})
local function activateCustom()
 State.uiMode="自定义"
 if modeSelect then pcall(function()modeSelect:Select("自定义")end)end
 if App.RefreshUIMode then App.RefreshUIMode()end
end
for _,entry in ipairs(customizableTabs)do
 local key,label=entry[1],entry[2]
 customPageSection:Toggle({
  Title="显示「"..label.."」",
  Value=State.customPages[key]~=false,
  Callback=function(v)
   if not editorReady then return end
   State.customPages[key]=v
   activateCustom()
   saveDisplaySettings()
  end
 })
end

local customControlsSection=App.CustomizeTab:Section({Title="逐项功能显示",Opened=false,Box=true})
customControlsSection:Paragraph({
 Title="选择具体功能",
 Desc="选择栏目 → 选择其中的按钮/开关/输入框 → 点击显示或隐藏。隐藏的是菜单控件，不会擅自启用或停用游戏功能。"
})
local chosenPage="Movement"
local chosenTitle=""
local pageElementDropdown
local function elementsFor(key)
 local tab=App.Tabs[key]
 if not tab then return {}end
 local list,exists={},{}
 local function collect(container)
  if not container or type(container.Elements)~="table"then return end
  for _,item in pairs(container.Elements)do
   if type(item)=="table"then
    local title=item.Title
    if item.ElementFrame and type(title)=="string" and title~=""
       and item.__type~="Section" and item.__type~="Category" and not exists[title]then
     exists[title]=true
     table.insert(list,title)
    end
    if item.__type=="Section"then collect(item)end
   end
  end
 end
 collect(tab)
 for _,group in ipairs((App.CategoryGroups and App.CategoryGroups[key]) or {})do collect(group)end
 table.sort(list)
 return list
end
local selectionStatus=customControlsSection:Button({
 Title="功能：尚未选择",Desc="选择功能后可以单独隐藏或显示",
 Icon="eye",Callback=function()
  if chosenTitle~=""then
   local hidden=State.customHiddenControls[chosenPage.."::"..chosenTitle]
   toast("当前功能",chosenTitle.."："..(hidden and "已隐藏" or "已显示"),"eye")
  end
 end
})
local function updateSelection()
 if chosenTitle==""then
  selectionStatus:SetTitle("功能：尚未选择")
  return
 end
 local hidden=State.customHiddenControls[chosenPage.."::"..chosenTitle]
 selectionStatus:SetTitle((hidden and "已隐藏：" or "已显示：")..chosenTitle)
 selectionStatus:SetDesc("选择「隐藏此功能」或「显示此功能」立即生效")
end
local categoryPicker=customControlsSection:Dropdown({
 Title="选择功能所在分类",Values=pageTitles,Value="移动",
 Callback=function(name)
  chosenPage=pageKeys[name] or "Movement"
  chosenTitle=""
  if pageElementDropdown then
   local values=elementsFor(chosenPage)
   if #values==0 then values={"此分类暂无可选择的控件"}end
   pcall(function()pageElementDropdown:Refresh(values)end)
  end
  updateSelection()
 end
})
pageElementDropdown=customControlsSection:Dropdown({
 Title="选择要显示 / 隐藏的功能",
 Values={"正在生成可选控件"},Value="正在生成可选控件",
 Callback=function(name)
  chosenTitle=tostring(name or "")
  updateSelection()
 end
})
local function setControlVisible(show)
 if chosenTitle=="" or chosenTitle=="此分类暂无可选择的控件"then
  toast("请先选择功能","从下拉菜单中选择一项","alert-circle")return
 end
 local code=chosenPage.."::"..chosenTitle
 if show then State.customHiddenControls[code]=nil
 else State.customHiddenControls[code]=true end
 activateCustom()
 updateSelection()
 local ok,err=saveDisplaySettings()
 if not ok then toast("未能保存",tostring(err),"alert-circle")end
end
customControlsSection:Button({Title="显示当前选中功能",Icon="eye",
 Callback=function()setControlVisible(true)end})
customControlsSection:Button({Title="隐藏当前选中功能",Icon="eye-off",
 Callback=function()setControlVisible(false)end})
customControlsSection:Button({Title="恢复所有逐项功能的显示",Icon="list-checks",
 Callback=function()
  table.clear(State.customHiddenControls)
  activateCustom()
  saveDisplaySettings()
  updateSelection()
  toast("已恢复","全部功能控件已恢复显示","check")
 end})
local customSaveSection=App.CustomizeTab:Section({Title="保存 / 读取自定义布局",Opened=false,Box=true})
customSaveSection:Paragraph({Title="自动保存",Desc="更改分类或功能显示状态后，会保存到执行器本地 RainHub/display-v3.json。下一次运行将自动尝试加载；若执行器不支持文件接口则仅本次有效。"})
customSaveSection:Button({Title="立即保存当前布局",Icon="save",Callback=function()
 local ok,err=saveDisplaySettings()
 toast(ok and "布局已保存" or "保存失败",ok and "RainHub/display-v3.json" or tostring(err),ok and "check" or "alert-circle")
end})
customSaveSection:Button({Title="重新读取本地布局",Icon="folder-open",Callback=function()
 if loadDisplaySettings()then
  if App.RefreshUIMode then App.RefreshUIMode()end
  toast("布局已读取","主分类和逐项功能显示已恢复","check")
 else toast("读取失败","文件不存在或缺少 readfile 权限","alert-circle")end
end})
App.Custom={
 SetPage=function(key,visible)
  if not customPageDefaults[key]then return false end
  State.customPages[key]=visible
  activateCustom()
  saveDisplaySettings()
  return true
 end,
 SetControl=function(key,title,visible)
  if not App.Tabs[key] or type(title)~="string"then return false end
  local tag=key.."::"..title
  if visible then State.customHiddenControls[tag]=nil else State.customHiddenControls[tag]=true end
  activateCustom()
  saveDisplaySettings()
  return true
 end,
 Catalog=elementsFor,
 Save=saveDisplaySettings,
 Load=loadDisplaySettings
}
editorReady=true
task.defer(function()
 if pageElementDropdown then
  local values=elementsFor(chosenPage)
  if #values==0 then values={"无可用控件"}end
  pcall(function()pageElementDropdown:Refresh(values)end)
 end
end)
end -- end display editor scope
initDisplayEditor()

local hudSection=Settings:Section({Title="悬浮信息组件",Opened=false,Box=true})
hudSection:Toggle({Title="显示悬浮状态条",Desc="独立圆角长方形 · 支持鼠标或触屏拖动",
 Value=true,Flag="hudEnabled",Callback=function(v)State.hudEnabled=v;refreshHud()end})
hudSection:Toggle({Title="悬浮条精简内容",Desc="单行仅显示 FPS 和玩家人数",
 Flag="hudCompact",Callback=function(v)State.hudCompact=v;refreshHud()end})
local hudAdvanced=Settings:Section({Title="悬浮条高级定制",Opened=false,Box=true})
hudAdvanced:Toggle({Title="启用功能状态自动扩展",Value=true,Flag="hudFeatures",
 Callback=function(v)State.hudFeatures=v;refreshHud()end})
hudAdvanced:Toggle({Title="显示自瞄目标用户名",Value=true,Flag="hudAimTarget",
 Callback=function(v)State.hudAimTarget=v;refreshHud()end})
hudAdvanced:Toggle({Title="附加延迟信息",Value=true,Flag="hudShowPing",
 Callback=function(v)State.hudShowPing=v;refreshHud()end})
hudAdvanced:Toggle({Title="附加生命值信息",Value=true,Flag="hudShowHealth",
 Callback=function(v)State.hudShowHealth=v;refreshHud()end})
hudAdvanced:Slider({Title="悬浮条缩放（%）",Flag="hudScale",
 Value={Min=65,Max=160,Default=100},Step=5,
 Callback=function(v)State.hudScale=(tonumber(v)or 100)/100;refreshHud()end})
hudAdvanced:Slider({Title="面板透明度（%）",Flag="hudOpacity",
 Value={Min=0,Max=80,Default=7},Step=1,
 Callback=function(v)State.hudOpacity=(tonumber(v)or 7)/100;refreshHud()end})
hudAdvanced:Colorpicker({Title="悬浮条强调色",Default=State.hudAccent,Flag="hudAccent",
 Callback=function(c)if typeof(c)=="Color3"then State.hudAccent=c;refreshHud()end end})
hudSection:Button({Title="将悬浮条复位到右上角",Icon="locate-fixed",Callback=function()
 local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
 State.hudX=math.max(8,vp.X-hudContentWidth*State.hudScale-18);State.hudY=57
 if hudPanel then hudPanel.Position=UDim2.fromOffset(State.hudX,State.hudY)end
 saveHUDPosition()
 toast("悬浮条","位置已复位","check")
end})
Settings:Paragraph({Title="作者 / 制作信息",Desc="作者：朱翎\nQQ：3555387734\n程序：雨 Hub v"..App.Version.."\n界面：ANUI by ANHub-Script"})
Settings:Button({Title="复制作者 QQ 联系方式",Icon="copy",Callback=function()copy("3555387734")end})

Settings:Paragraph({Title="界面与配置",Desc="使用 ANUI 官方组件。RightShift 隐藏和显示窗口，NEXUS 悬浮按钮可重新打开。"})
Settings:Dropdown({Title="切换 ANUI 主题",Flag="theme",Values={
 "TokyoNight","Dark","Light","OceanBlue","NordTheme","DraculaTheme",
 "OneDark","CyberpunkPink","Indigo","Sky","Violet","Emerald","Rose",
 "MonokaiPro","NeonGreen","CottonCandy"},Value="TokyoNight",
 Callback=function(v)pcall(function()ANUI:SetTheme(v)end)end})
Settings:Toggle({Title="亚克力背景效果",Value=true,Flag="acrylic",
 Callback=function(v)pcall(function()ANUI:ToggleAcrylic(v)end)end})
Settings:Toggle({Title="窗口透明背景",Flag="transparent",
 Callback=function(v)pcall(function()Window:ToggleTransparency(v)end)end})
Settings:Keybind({Title="打开 / 隐藏窗口快捷键",Value="RightShift",Flag="toggleKey",
 Callback=function(k)
  local ok,key=pcall(function()return Enum.KeyCode[k]end)
  if ok and key then Window:SetToggleKey(key)end
 end})
Settings:Button({Title="折叠菜单侧边栏",Icon="panel-left-close",
 Callback=function()Window:CollapseSidebar()end})
Settings:Button({Title="展开菜单侧边栏",Icon="panel-left-open",
 Callback=function()Window:ExpandSidebar()end})
Settings:Button({Title="保存 default 配置",Icon="save",Callback=function()
 if not Window.CurrentConfig then
  toast("配置不可用","执行器缺少 readfile/writefile 等文件接口","alert-circle")return
 end
 local ok,err=pcall(function()Window.CurrentConfig:Save()end)
 toast(ok and "保存成功" or "保存失败",ok and "default" or err,ok and "check" or "alert-circle")
end})
Settings:Button({Title="加载 default 配置",Icon="folder-open",Callback=function()
 if not Window.CurrentConfig then
  toast("配置不可用","执行器缺少文件系统接口","alert-circle")return
 end
 local ok,err=pcall(function()Window.CurrentConfig:Load()end)
 toast(ok and "加载成功" or "加载失败",ok and "default" or err,ok and "check" or "alert-circle")
end})
Settings:Button({Title="彻底卸载 HUB",Desc="还原效果并销毁事件与窗口",Icon="power",
 Color=Color3.fromRGB(183,60,78),Callback=function()destroy()end})


do
-- Minimal/advanced presentation only changes visibility. It never resets feature state.
local advancedTitles={
 ["执行器兼容性 · Xeno"]=true,
 ["防甩飞已全面升级"]=true,
 ["重新应用性能优化"]=true,
 ["恢复全部原始特效"]=true,
 ["重新扫描场景内的飞行物"]=true,
 ["清理所有追踪线"]=true,
 ["检查当前帧率"]=true,
 ["FPS 低时自动减少更新次数"]=true,
 ["ESP 刷新间隔（毫秒）"]=true,
 ["目标扫描间隔（毫秒）"]=true,
 ["弹道场景检查周期（秒）"]=true,
 ["一次性特效优化的最大实例数"]=true,
 ["重置性能参数为均衡"]=true,
 ["高级运行信息"]=true,
 ["复制作者 QQ 联系方式"]=true,
 ["精确自转速度（度/秒，负数反方向）"]=true,
 ["精确移速（无滑块上限）"]=true,
 ["精确跳跃力度（无滑块上限）"]=true,
 ["精确飞行速度（无滑块上限）"]=true,
 ["精确冲刺速度"]=true, ["精确 HipHeight"]=true,
 ["精确 ESP 距离"]=true,
 ["自定义 HipHeight（角色站立高度）"]=true,
 ["防甩飞已全面升级"]=true,
 ["检测范围与阈值"]=true,
 ["防坠落与应急"]=true,
 ["过滤与样式"]=true,
 ["最大距离（stud）"]=true,["队伍过滤"]=true,
 ["目标坐标 X"]=true,["目标坐标 Y"]=true,["目标坐标 Z"]=true,
 ["读取当前坐标到输入框"]=true,["传送到手动输入的 XYZ"]=true,
 ["自动跟随距离"]=true,["输出当前在线玩家清单"]=true,
 ["显示玩家状态"]=true,["复制玩家 UserId"]=true,
 ["复制目标用户名"]=true,["切换到下一位在线玩家"]=true,
 ["防护触发通知"]=true,["坐在载具时暂停位置恢复"]=true,
 ["切换 ANUI 主题"]=true,["亚克力背景效果"]=true,
 ["窗口透明背景"]=true,["折叠菜单侧边栏"]=true,
 ["展开菜单侧边栏"]=true
}
local visibleTabs={Home=true,Movement=true,Defense=true,ESP=true,PlayerUI=true,Travel=true,World=true,Aim=true,Combat=true,Hotkeys=true,Music=false,Performance=true,Utilities=true,Settings=true,Customize=true}
local allContainers={Home,Movement,Defense,ESP,PlayerUI,Travel,World,Aim,App.CombatTab,App.HotkeyTab,App.MusicTab,Performance,Utilities,Settings,App.CustomizeTab,
 aimBasic,aimFilters,aimTraces,
 m1,m2,sprint,d1,d2,d3,e1,e2,pbox,hudSection,hudAdvanced,App.MusicVisibility,App.HomeAdvanced,App.NavSettings}
App.CategoryGroups={
 Movement={m1,m2,sprint},Defense={d1,d2,d3},ESP={e1,e2},
 PlayerUI={pbox},Aim={aimBasic,aimFilters,aimTraces},
 Settings={hudSection,hudAdvanced,App.NavSettings},Home={App.HomeAdvanced},Combat=App.CombatGroups or {},Hotkeys={},Music=App.MusicGroups or {}
}
local advancedFrames={}
local visited={}
for _,container in ipairs(allContainers)do
 if type(container)=="table" and type(container.Elements)=="table"then
  for _,e in pairs(container.Elements)do
   if type(e)=="table" and e.ElementFrame and not visited[e.ElementFrame]then
    visited[e.ElementFrame]=true
    if advancedTitles[e.Title]then table.insert(advancedFrames,e.ElementFrame)end
   end
  end
 end
end
for _,v in ipairs({d2,e2,hudAdvanced,App.HomeAdvanced})do
 if v and v.ElementFrame and not visited[v.ElementFrame]then
  visited[v.ElementFrame]=true
  table.insert(advancedFrames,v.ElementFrame)
 end
end
App.RefreshUIMode=function()
 local advanced=State.uiMode=="高级"
 local custom=State.uiMode=="自定义"
 for key,tab in pairs(App.Tabs)do
  if tab.UIElements and tab.UIElements.Main then
   local show
   if key=="Home" or key=="Settings" or key=="Customize"then show=true
   elseif custom then show=State.customPages[key]~=false
   else show=advanced or visibleTabs[key]==true end
   if key=="Music"then show=State.musicVisible end
   tab.UIElements.Main.Visible=show
  end
 end
 -- Main section containers, including advanced-only options.
 for _,frame in ipairs(advancedFrames)do
  if frame.Parent then frame.Visible=advanced or custom end
 end
 for _,element in ipairs({overDetails,overDevice,overIP,ipCheck})do
  if element and element.ElementFrame and element.ElementFrame.Parent then
   element.ElementFrame.Visible=advanced or custom
  end
 end
 -- Explicit per-control selections, keyed by stable tab name and control title.
 if custom then
  for key,tab in pairs(App.Tabs)do
   local visitedWidgets={}
   local function refreshElements(parent)
    if not parent or type(parent.Elements)~="table"then return end
    for _,item in pairs(parent.Elements)do
     if type(item)=="table"then
      if item.ElementFrame and item.__type~="Category" and item.__type~="Section"
          and not visitedWidgets[item.ElementFrame]then
       visitedWidgets[item.ElementFrame]=true
       if item.Title then
        item.ElementFrame.Visible=State.customHiddenControls[key.."::"..tostring(item.Title)]~=true
       end
      end
      if item.__type=="Section"then refreshElements(item)end
     end
    end
   end
   refreshElements(tab)
   for _,group in ipairs((App.CategoryGroups and App.CategoryGroups[key]) or {})do refreshElements(group)end
  end
 else
  -- Revert individually hidden controls when selecting a preset.
  for key,tab in pairs(App.Tabs)do
   local visitedWidgets={}
   local function resetElements(parent)
    if not parent or type(parent.Elements)~="table"then return end
    for _,item in pairs(parent.Elements)do
     if type(item)=="table"then
      if item.ElementFrame and item.__type~="Category" and item.__type~="Section"
          and not visitedWidgets[item.ElementFrame]then
       visitedWidgets[item.ElementFrame]=true
       item.ElementFrame.Visible=advanced or not advancedTitles[item.Title]
      end
      if item.__type=="Section"then resetElements(item)end
     end
    end
   end
   resetElements(tab)
   for _,group in ipairs((App.CategoryGroups and App.CategoryGroups[key]) or {})do resetElements(group)end
  end
 end
 if advanced or custom then
  overDevice:SetDesc(
   "系统："..platform..
   "\n注入器："..executorName..(executorVersion~="" and (" · "..executorVersion) or "")..
   "\n设备标识（仅末 4 位）："..maskedHardwareID()..
   "\n权限：设备信息不会自动上传"
  )
 end
end
App.RefreshSidebarLayout()
App.RefreshUIMode()
end
refreshHud()

pcall(function()
 Window:StatusLoop("nexus-stats",0.5,function()
  if not App.Running then return end
  local h,r=humanoid(),hrp()
  local ping=localPing()
  App.HomeOverview:SetDesc(
   "游戏："..game.Name.."  ·  PlaceId："..game.PlaceId..
   "\n用户：@"..LP.Name.."  ·  玩家："..#Players:GetPlayers().."/"..Players.MaxPlayers..
   "\nFPS："..fps.."  ·  延迟："..(ping and ping.." ms" or "未知")..
   "  ·  生命："..(h and math.floor(h.Health) or "-")..
   "\n执行器："..executorName..(executorVersion~="" and (" "..executorVersion) or "")..
   "  ·  平台："..platform..
   "\n在线时长："..math.floor(workspace.DistributedGameTime/60).." 分钟  ·  菜单：RightShift"
  )
  if State.uiMode=="高级"then
   overDetails:SetDesc(
    "UniverseId："..tostring(game.GameId)..
    "\nPlace Version："..tostring(game.PlaceVersion)..
    "\nCreatorId："..tostring(game.CreatorId)..
    "\nJobId："..tostring(game.JobId)
   )
  end
  defenseStatus:SetTitle("防护触发："..guard.recoveries.." 次")
  defenseStatus:SetDesc("模式 "..State.antiFlingMode.." · "..(guard.threat~="" and ("附近异常玩家 @"..guard.threat) or "未检测到异常角色"))
  telemetry:SetTitle("FPS "..fps.." · HP "..(h and math.floor(h.Health) or "-"))
  telemetry:SetDesc(r and string.format("坐标：%.0f / %.0f / %.0f",r.Position.X,r.Position.Y,r.Position.Z) or "等待角色")
 end)
end)
pcall(function()Home:Select()end)
toast("雨 Hub 🌧️","v2.6 · 精简菜单 / 可选折叠侧栏 / 合并总览 | RightShift","sparkles")
print("[雨 Hub Xeno] Loaded v"..App.Version.." in "..game.Name.." | "..App.Compat.Report())
