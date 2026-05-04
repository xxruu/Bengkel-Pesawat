-- VelxHub Premium Universal Script UI v1.5.3

-- ══════════════════════════════════════════════
-- ICON KONFIGURASI — Ganti URL di bawah dengan
-- link raw GitHub foto/icon kamu (format .png)
-- Contoh: https://raw.githubusercontent.com/USERNAME/REPO/main/icon.png
-- ══════════════════════════════════════════════
local MINI_ICON_URL = "https://raw.githubusercontent.com/xxruu/Bengkel-Pesawat/main/logo.png"
local MINI_ICON_ID  = "rbxassetid://10656208579" -- fallback default icon kalau gagal

-- UPDATE v1.5.3:
-- - Fast Hit: tahan klik kiri untuk hit cepat
-- - Dance: simpan preset dance/emote custom
-- - Spectate: search by display name
-- - Teleport: player search dropdown

-- ═══════════════ ANTI-DETECTION SERVICE LOADER v2 ═══════════════
-- Bypass "Disallowed Services Detected" (Error 267)
-- Games scan GetService/FindService calls to detect forbidden services.
-- We hook __namecall to hide our service usage from anti-cheat scanners.

local _cloneref = cloneref or function(o) return o end

-- List of services that trigger "Disallowed Services Detected"
local _SENSITIVE_SERVICES = {
    ["VirtualUser"] = true,
    ["InsertService"] = true,
    ["HttpService"] = true,
    ["CoreGui"] = true,
    ["ScriptContext"] = true,
    ["TestService"] = true,
    ["LogService"] = true,
}

-- Raw service fetcher (direct, no hooks)
local _rawServiceCache = {}
local function _getsvc(n)
    if _rawServiceCache[n] then return _rawServiceCache[n] end
    local ok, svc = pcall(function()
        return _cloneref(game:GetService(n))
    end)
    if not ok then
        ok, svc = pcall(function()
            return _cloneref(game:FindService(n))
        end)
    end
    if ok and svc then _rawServiceCache[n] = svc end
    return ok and svc or nil
end

-- Fetch ALL services NOW before any hooks are installed by the game
local Players = _getsvc("Players")
local UIS = _getsvc("UserInputService")
local RunService = _getsvc("RunService")
local TweenService = _getsvc("TweenService")
local Workspace = _getsvc("Workspace")
local _CoreGui = _getsvc("CoreGui")
local _StarterGui = _getsvc("StarterGui")
local _TeleportSvc = _getsvc("TeleportService")
local _HttpSvc = _getsvc("HttpService")
local _Lighting = _getsvc("Lighting")
local _VirtualUser = _getsvc("VirtualUser")
local _InsertSvc = _getsvc("InsertService")
local _MarketSvc = _getsvc("MarketplaceService")

-- ═══════════════ ANTI-CHEAT BYPASS HOOKS ═══════════════
-- Hook __namecall so when the GAME's anti-cheat calls game:GetService("VirtualUser")
-- or game:FindService("InsertService"), it returns nil — hiding our usage.
do
    local _hookmetamethod = hookmetamethod or nil
    local _checkcaller = checkcaller or nil
    if _hookmetamethod and _checkcaller then
        local oldNamecall
        oldNamecall = _hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            -- Only block the GAME's anti-cheat from finding sensitive services
            -- Allow OUR calls (checkcaller returns true for exploit context)
            if not _checkcaller() then
                if (method == "GetService" or method == "FindService" or method == "FindFirstChild") then
                    local args = {...}
                    if args[1] and type(args[1]) == "string" and _SENSITIVE_SERVICES[args[1]] then
                        return nil -- Hide service from anti-cheat
                    end
                end
                -- Block anti-cheat from kicking us
                if method == "Kick" then
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)

        -- Also hook __index on game so game.VirtualUser / game.InsertService returns nil
        -- for game's anti-cheat but works for us
        local oldIndex
        oldIndex = _hookmetamethod(game, "__index", function(self, key)
            if not _checkcaller() and type(key) == "string" and _SENSITIVE_SERVICES[key] then
                return nil
            end
            return oldIndex(self, key)
        end)
    end
end

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local States = {
    NoClip=false, Fly=false, ESP=false, God=false,
    InfJump=false, Speed=false, Fullbright=false,
    Freecam=false, AntiAFK=true, Spectating=false,
}
local FlySpeed = 50
local WalkSpeedVal = 16
local JumpPowerVal = 50
local Connections = {}
local flyBody = {}
local currentToggleKey = Enum.KeyCode.LeftControl
local isBindingKey = false

-- ═══════════════ SCREENGUI ═══════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VelxHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    if get_hidden_gui or gethui then
        ScreenGui.Parent = (get_hidden_gui or gethui)()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui); ScreenGui.Parent = _CoreGui
    else
        ScreenGui.Parent = _CoreGui
    end
end)
if not ScreenGui.Parent then ScreenGui.Parent = Player:WaitForChild("PlayerGui") end

local C = {
    bg=Color3.fromRGB(18,18,24), sidebar=Color3.fromRGB(22,22,30),
    card=Color3.fromRGB(28,28,38), accent=Color3.fromRGB(99,102,241),
    accentHover=Color3.fromRGB(129,132,255), green=Color3.fromRGB(34,197,94),
    red=Color3.fromRGB(239,68,68), orange=Color3.fromRGB(251,146,60),
    text=Color3.fromRGB(240,240,245), textDim=Color3.fromRGB(140,140,160),
    border=Color3.fromRGB(45,45,60), toggleOff=Color3.fromRGB(55,55,70),
}

local function notify(t,m) pcall(function() _StarterGui:SetCore("SendNotification",{Title=t,Text=m,Duration=3}) end) end
local function tween(o,p,d) TweenService:Create(o,TweenInfo.new(d or 0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),p):Play() end
local function addCorner(o,r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r or 8); return c end
local function addStroke(o,col,t) local s=Instance.new("UIStroke",o); s.Color=col or C.border; s.Thickness=t or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end

-- ═══════════════ MAIN FRAME ═══════════════
local Main = Instance.new("Frame",ScreenGui)
Main.Name="Main"; Main.Size=UDim2.new(0,520,0,380)
Main.Position=UDim2.new(0.5,-260,0.5,-190)
Main.BackgroundColor3=C.bg; Main.BorderSizePixel=0; Main.ClipsDescendants=false
addCorner(Main,12); addStroke(Main,C.border,1)

local Shadow=Instance.new("ImageLabel",Main); Shadow.BackgroundTransparency=1
Shadow.Position=UDim2.new(0,-15,0,-15); Shadow.Size=UDim2.new(1,30,1,30); Shadow.ZIndex=0
Shadow.ImageTransparency=0.6; Shadow.Image="rbxassetid://6015897843"; Shadow.ImageColor3=Color3.new(0,0,0)
Shadow.ScaleType=Enum.ScaleType.Slice; Shadow.SliceCenter=Rect.new(49,49,450,450)

-- ═══════════════ TITLE BAR ═══════════════
local TitleBar=Instance.new("Frame",Main); TitleBar.Name="TitleBar"
TitleBar.Size=UDim2.new(1,0,0,36); TitleBar.BackgroundColor3=C.sidebar; TitleBar.BorderSizePixel=0
addCorner(TitleBar,12)
do
    local dragging,dragStart,startPos
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=Main.Position end end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-dragStart
            Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end
local TitleFix=Instance.new("Frame",TitleBar); TitleFix.Size=UDim2.new(1,0,0,14)
TitleFix.Position=UDim2.new(0,0,1,-14); TitleFix.BackgroundColor3=C.sidebar; TitleFix.BorderSizePixel=0
local TitleText=Instance.new("TextLabel",TitleBar); TitleText.Size=UDim2.new(1,-80,1,0)
TitleText.Position=UDim2.new(0,14,0,0); TitleText.BackgroundTransparency=1
TitleText.Text=">> VelxHub Premium Universal Script v1.5.2"
TitleText.TextColor3=C.text; TitleText.Font=Enum.Font.GothamBold; TitleText.TextSize=14; TitleText.TextXAlignment=Enum.TextXAlignment.Left

local function titleBtn(txt,pos,col)
    local b=Instance.new("TextButton",TitleBar); b.Size=UDim2.new(0,28,0,28); b.Position=pos
    b.BackgroundColor3=col; b.BackgroundTransparency=0.8; b.Text=txt; b.TextColor3=C.text
    b.Font=Enum.Font.GothamBold; b.TextSize=14; b.BorderSizePixel=0; addCorner(b,6)
    b.MouseEnter:Connect(function() tween(b,{BackgroundTransparency=0.4},0.15) end)
    b.MouseLeave:Connect(function() tween(b,{BackgroundTransparency=0.8},0.15) end)
    return b
end
local CloseBtn=titleBtn("X",UDim2.new(1,-38,0,4),C.red)
local MinBtn=titleBtn("—",UDim2.new(1,-70,0,4),C.orange)
local minimized=false
-- Auto-detect: PC mode aktif kalau ada keyboard (PC/laptop),
-- mati otomatis di HP tanpa keyboard (show MiniBtn instead)
local pcModeEnabled = UIS.KeyboardEnabled
-- Kalau nanti user colokin keyboard ke HP, aktifin PC mode
UIS.LastInputTypeChanged:Connect(function(inputType)
    if inputType == Enum.UserInputType.Keyboard and not pcModeEnabled then
        pcModeEnabled = true
        notify("Mode", "⌨️ Keyboard terdeteksi — PC Mode aktif")
    end
end)

local MiniBtn=Instance.new("ImageButton",ScreenGui); MiniBtn.Name="MiniBtn"
MiniBtn.Size=UDim2.new(0,42,0,42); MiniBtn.Position=UDim2.new(0,10,0.5,-21)
MiniBtn.BackgroundColor3=C.accent; MiniBtn.BorderSizePixel=0
MiniBtn.Image=MINI_ICON_ID; MiniBtn.ImageColor3=Color3.new(1,1,1)
MiniBtn.ScaleType=Enum.ScaleType.Fit
MiniBtn.Visible=false; MiniBtn.ZIndex=99; addCorner(MiniBtn,10); addStroke(MiniBtn,C.border,1)

-- Load custom icon secara asynchronous supaya nggak nge-block UI
task.spawn(function()
    pcall(function()
        local data = game:HttpGet(MINI_ICON_URL)
        if data then
            local fileName = "velx_icon_" .. tostring(math.random(1000, 9999)) .. ".png"
            if writefile and getcustomasset then
                writefile(fileName, data)
                local newId = getcustomasset(fileName)
                if newId then
                    MiniBtn.Image = newId
                end
            end
        end
    end)
end)
do
    local mbDown,mbDragging,mbStart,mbStartPos=false,false,nil,nil
    local DRAG_THRESHOLD=6
    MiniBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            mbDown=true; mbDragging=false; mbStart=i.Position; mbStartPos=MiniBtn.Position end end)
    UIS.InputChanged:Connect(function(i)
        if mbDown and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-mbStart
            if d.Magnitude>DRAG_THRESHOLD then mbDragging=true end
            if mbDragging then MiniBtn.Position=UDim2.new(mbStartPos.X.Scale,mbStartPos.X.Offset+d.X,mbStartPos.Y.Scale,mbStartPos.Y.Offset+d.Y) end end end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            if mbDown and not mbDragging then
                if Main.Visible then Main.Visible=false
                else minimized=false; Main.Size=UDim2.new(0,520,0,380); Main.BackgroundTransparency=0; Main.Visible=true end end
            mbDown=false; mbDragging=false end end)
end
MiniBtn.MouseEnter:Connect(function() tween(MiniBtn,{BackgroundColor3=C.accentHover},0.15) end)
MiniBtn.MouseLeave:Connect(function() tween(MiniBtn,{BackgroundColor3=C.accent},0.15) end)

-- Confirm dialog
local ConfirmOverlay=Instance.new("Frame",ScreenGui)
ConfirmOverlay.Size=UDim2.new(1,0,1,0); ConfirmOverlay.BackgroundColor3=Color3.new(0,0,0)
ConfirmOverlay.BackgroundTransparency=0.5; ConfirmOverlay.BorderSizePixel=0; ConfirmOverlay.Visible=false; ConfirmOverlay.ZIndex=100
local ConfirmBox=Instance.new("Frame",ConfirmOverlay); ConfirmBox.Size=UDim2.new(0,280,0,130)
ConfirmBox.Position=UDim2.new(0.5,-140,0.5,-65); ConfirmBox.BackgroundColor3=C.card; ConfirmBox.BorderSizePixel=0; ConfirmBox.ZIndex=101
addCorner(ConfirmBox,12); addStroke(ConfirmBox,C.accent,1.5)
local ConfirmTitle=Instance.new("TextLabel",ConfirmBox); ConfirmTitle.Size=UDim2.new(1,0,0,30); ConfirmTitle.Position=UDim2.new(0,0,0,16)
ConfirmTitle.BackgroundTransparency=1; ConfirmTitle.Text="Yakin mau keluar?"; ConfirmTitle.TextColor3=C.text
ConfirmTitle.Font=Enum.Font.GothamBold; ConfirmTitle.TextSize=16; ConfirmTitle.ZIndex=102
local ConfirmSub=Instance.new("TextLabel",ConfirmBox); ConfirmSub.Size=UDim2.new(1,0,0,18); ConfirmSub.Position=UDim2.new(0,0,0,44)
ConfirmSub.BackgroundTransparency=1; ConfirmSub.Text="Script akan dihapus sepenuhnya."; ConfirmSub.TextColor3=C.textDim
ConfirmSub.Font=Enum.Font.GothamMedium; ConfirmSub.TextSize=11; ConfirmSub.ZIndex=102
local ConfirmYes=Instance.new("TextButton",ConfirmBox); ConfirmYes.Size=UDim2.new(0,110,0,34); ConfirmYes.Position=UDim2.new(0,20,1,-48)
ConfirmYes.BackgroundColor3=C.red; ConfirmYes.BorderSizePixel=0; ConfirmYes.Text="Ya, Keluar"
ConfirmYes.TextColor3=Color3.new(1,1,1); ConfirmYes.Font=Enum.Font.GothamBold; ConfirmYes.TextSize=13; ConfirmYes.ZIndex=102; addCorner(ConfirmYes,8)
ConfirmYes.MouseEnter:Connect(function() tween(ConfirmYes,{BackgroundTransparency=0.2},0.1) end)
ConfirmYes.MouseLeave:Connect(function() tween(ConfirmYes,{BackgroundTransparency=0},0.1) end)
local ConfirmNo=Instance.new("TextButton",ConfirmBox); ConfirmNo.Size=UDim2.new(0,110,0,34); ConfirmNo.Position=UDim2.new(1,-130,1,-48)
ConfirmNo.BackgroundColor3=C.card; ConfirmNo.BorderSizePixel=0; ConfirmNo.Text="Batal"
ConfirmNo.TextColor3=C.text; ConfirmNo.Font=Enum.Font.GothamBold; ConfirmNo.TextSize=13; ConfirmNo.ZIndex=102; addCorner(ConfirmNo,8); addStroke(ConfirmNo,C.border,1)
ConfirmNo.MouseEnter:Connect(function() tween(ConfirmNo,{BackgroundColor3=C.accent},0.1) end)
ConfirmNo.MouseLeave:Connect(function() tween(ConfirmNo,{BackgroundColor3=C.card},0.1) end)
CloseBtn.MouseButton1Click:Connect(function() ConfirmOverlay.Visible=true end)
ConfirmYes.MouseButton1Click:Connect(function()
    ConfirmOverlay.Visible=false; tween(Main,{Size=UDim2.new(0,520,0,0)},0.3); task.wait(0.3)
    ScreenGui:Destroy()
    for _,c in Connections do if c.Disconnect then c:Disconnect() end end
end)
ConfirmNo.MouseButton1Click:Connect(function() ConfirmOverlay.Visible=false end)
MinBtn.MouseButton1Click:Connect(function()
    minimized=true; tween(Main,{Size=UDim2.new(0,40,0,40),BackgroundTransparency=0.5},0.3); task.wait(0.3)
    Main.Visible=false
    if not pcModeEnabled then MiniBtn.Visible=true
    else notify("Minimized","Tekan "..tostring(currentToggleKey.Name).." / Insert untuk buka kembali") end
end)

-- ═══════════════ SIDEBAR ═══════════════
local Sidebar=Instance.new("Frame",Main); Sidebar.Name="Sidebar"
Sidebar.Size=UDim2.new(0,110,1,-36); Sidebar.Position=UDim2.new(0,0,0,36)
Sidebar.BackgroundColor3=C.sidebar; Sidebar.BorderSizePixel=0; Sidebar.ZIndex=2
local SBLine=Instance.new("Frame",Main); SBLine.Size=UDim2.new(0,1,1,-36)
SBLine.Position=UDim2.new(0,110,0,36); SBLine.BackgroundColor3=C.border; SBLine.BorderSizePixel=0; SBLine.ZIndex=3
local TabLayout=Instance.new("UIListLayout",Sidebar); TabLayout.Padding=UDim.new(0,4); TabLayout.SortOrder=Enum.SortOrder.LayoutOrder
local TabPad=Instance.new("UIPadding",Sidebar); TabPad.PaddingTop=UDim.new(0,8); TabPad.PaddingLeft=UDim.new(0,6); TabPad.PaddingRight=UDim.new(0,6)

local ContentArea=Instance.new("Frame",Main); ContentArea.Name="Content"
ContentArea.Size=UDim2.new(1,-110,1,-36); ContentArea.Position=UDim2.new(0,110,0,36)
ContentArea.BackgroundTransparency=1; ContentArea.BorderSizePixel=0

local Pages={}; local TabButtons={}; local ActiveTab=nil

local function createPage(name)
    local page=Instance.new("ScrollingFrame",ContentArea); page.Name=name
    page.Size=UDim2.new(1,0,1,0); page.BackgroundTransparency=1; page.BorderSizePixel=0
    page.ScrollBarThickness=3; page.ScrollBarImageColor3=C.accent
    page.CanvasSize=UDim2.new(0,0,0,0); page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.Visible=false
    local layout=Instance.new("UIListLayout",page); layout.Padding=UDim.new(0,6); layout.SortOrder=Enum.SortOrder.LayoutOrder
    local pad=Instance.new("UIPadding",page); pad.PaddingTop=UDim.new(0,10); pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,10)
    Pages[name]=page; return page
end

local function createTab(icon,name,order)
    local btn=Instance.new("TextButton",Sidebar); btn.Name=name
    btn.Size=UDim2.new(1,0,0,32); btn.BackgroundColor3=C.accent; btn.BackgroundTransparency=1
    btn.BorderSizePixel=0; btn.Text=icon.."  "..name; btn.TextColor3=C.textDim
    btn.Font=Enum.Font.GothamMedium; btn.TextSize=12; btn.TextXAlignment=Enum.TextXAlignment.Left; btn.LayoutOrder=order; addCorner(btn,6)
    local pad=Instance.new("UIPadding",btn); pad.PaddingLeft=UDim.new(0,8)
    btn.MouseEnter:Connect(function() if ActiveTab~=name then tween(btn,{BackgroundTransparency=0.85},0.15) end end)
    btn.MouseLeave:Connect(function() if ActiveTab~=name then tween(btn,{BackgroundTransparency=1},0.15) end end)
    btn.MouseButton1Click:Connect(function()
        for n,p in Pages do p.Visible=false end
        for n,b in TabButtons do tween(b,{BackgroundTransparency=1,TextColor3=C.textDim},0.2) end
        Pages[name].Visible=true; tween(btn,{BackgroundTransparency=0.7,TextColor3=C.text},0.2); ActiveTab=name
    end)
    TabButtons[name]=btn; createPage(name); return btn
end

-- ═══════════════ UI COMPONENTS ═══════════════
local function addToggle(parent,label,default,callback)
    local holder=Instance.new("Frame",parent); holder.Size=UDim2.new(1,0,0,36)
    holder.BackgroundColor3=C.card; holder.BorderSizePixel=0; addCorner(holder,8)
    local lbl=Instance.new("TextLabel",holder); lbl.Size=UDim2.new(1,-60,1,0); lbl.Position=UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local togBg=Instance.new("Frame",holder); togBg.Size=UDim2.new(0,40,0,20); togBg.Position=UDim2.new(1,-52,0.5,-10)
    togBg.BackgroundColor3=default and C.accent or C.toggleOff; togBg.BorderSizePixel=0; addCorner(togBg,10)
    local circle=Instance.new("Frame",togBg); circle.Size=UDim2.new(0,16,0,16)
    circle.Position=default and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)
    circle.BackgroundColor3=C.text; circle.BorderSizePixel=0; addCorner(circle,8)
    local state=default or false
    local btn=Instance.new("TextButton",holder); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=5
    btn.MouseButton1Click:Connect(function()
        state=not state
        tween(togBg,{BackgroundColor3=state and C.accent or C.toggleOff},0.2)
        tween(circle,{Position=state and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},0.2)
        if callback then callback(state) end
    end)
    local function setState(newState)
        if state==newState then return end; state=newState
        tween(togBg,{BackgroundColor3=state and C.accent or C.toggleOff},0.2)
        tween(circle,{Position=state and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},0.2)
    end
    return holder,setState
end

local function addButton(parent,label,callback)
    local btn=Instance.new("TextButton",parent); btn.Size=UDim2.new(1,0,0,36)
    btn.BackgroundColor3=C.card; btn.BorderSizePixel=0; btn.Text=label; btn.TextColor3=C.text
    btn.Font=Enum.Font.GothamMedium; btn.TextSize=13; addCorner(btn,8)
    btn.MouseEnter:Connect(function() tween(btn,{BackgroundColor3=C.accent},0.15) end)
    btn.MouseLeave:Connect(function() tween(btn,{BackgroundColor3=C.card},0.15) end)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local activeSliderUpdate=nil
UIS.InputChanged:Connect(function(i)
    if activeSliderUpdate and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        activeSliderUpdate(i) end end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then activeSliderUpdate=nil end end)

local function addSlider(parent,label,min,max,default,callback)
    local holder=Instance.new("Frame",parent); holder.Size=UDim2.new(1,0,0,50)
    holder.BackgroundColor3=C.card; holder.BorderSizePixel=0; addCorner(holder,8)
    local lbl=Instance.new("TextLabel",holder); lbl.Size=UDim2.new(1,-60,0,20); lbl.Position=UDim2.new(0,12,0,4)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local valLabel=Instance.new("TextLabel",holder); valLabel.Size=UDim2.new(0,50,0,20); valLabel.Position=UDim2.new(1,-60,0,4)
    valLabel.BackgroundTransparency=1; valLabel.Text=tostring(default); valLabel.TextColor3=C.accent; valLabel.Font=Enum.Font.GothamBold; valLabel.TextSize=12
    local track=Instance.new("Frame",holder); track.Size=UDim2.new(1,-24,0,6); track.Position=UDim2.new(0,12,0,32)
    track.BackgroundColor3=C.toggleOff; track.BorderSizePixel=0; addCorner(track,3)
    local pct=(default-min)/(max-min)
    local fill=Instance.new("Frame",track); fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; addCorner(fill,3)
    local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(pct,-7,0.5,-7)
    knob.BackgroundColor3=C.text; knob.BorderSizePixel=0; knob.ZIndex=3; addCorner(knob,7)
    local sliderBtn=Instance.new("TextButton",track); sliderBtn.Size=UDim2.new(1,0,0,20); sliderBtn.Position=UDim2.new(0,0,0,-7)
    sliderBtn.BackgroundTransparency=1; sliderBtn.Text=""; sliderBtn.ZIndex=4
    local function update(i)
        local abs=track.AbsolutePosition.X; local w=track.AbsoluteSize.X
        local rel=math.clamp((i.Position.X-abs)/w,0,1)
        local val=math.floor(min+(max-min)*rel)
        valLabel.Text=tostring(val); fill.Size=UDim2.new(rel,0,1,0); knob.Position=UDim2.new(rel,-7,0.5,-7)
        if callback then callback(val) end
    end
    sliderBtn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            activeSliderUpdate=update; update(i) end end)
    return holder
end

local function addLabel(parent,text)
    local lbl=Instance.new("TextLabel",parent); lbl.Size=UDim2.new(1,0,0,22)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.accent
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left
    return lbl
end

local function addInput(parent,placeholder,callback)
    local holder=Instance.new("Frame",parent); holder.Size=UDim2.new(1,0,0,36)
    holder.BackgroundColor3=C.card; holder.BorderSizePixel=0; addCorner(holder,8)
    local box=Instance.new("TextBox",holder); box.Size=UDim2.new(1,-80,1,0); box.Position=UDim2.new(0,12,0,0)
    box.BackgroundTransparency=1; box.PlaceholderText=placeholder; box.PlaceholderColor3=C.textDim; box.Text=""
    box.TextColor3=C.text; box.Font=Enum.Font.GothamMedium; box.TextSize=13; box.TextXAlignment=Enum.TextXAlignment.Left; box.ClearTextOnFocus=false
    local go=Instance.new("TextButton",holder); go.Size=UDim2.new(0,55,0,26); go.Position=UDim2.new(1,-65,0.5,-13)
    go.BackgroundColor3=C.accent; go.BorderSizePixel=0; go.Text="GO"; go.TextColor3=C.text; go.Font=Enum.Font.GothamBold; go.TextSize=12; addCorner(go,6)
    go.MouseButton1Click:Connect(function() if callback then callback(box.Text) end end)
    box.FocusLost:Connect(function(enter) if enter and callback then callback(box.Text) end end)
    return holder,box
end

-- ═══════════════ CREATE TABS ═══════════════
createTab("[P]","Player",1); createTab("[T]","Teleport",2); createTab("[M]","Movement",3)
createTab("[V]","Visual",4); createTab("[D]","Dance",5); createTab("[F]","Farm",6)
createTab("[X]","Misc",7); createTab("[A]","Apocalypse",8)

TabButtons["Player"].BackgroundTransparency=0.7; TabButtons["Player"].TextColor3=C.text
Pages["Player"].Visible=true; ActiveTab="Player"

local function getChar() return Player.Character or Player.CharacterAdded:Wait() end
local function getHRP() local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ═══════════════ PLAYER TAB ═══════════════
do
local pPage=Pages["Player"]
addLabel(pPage,"-- CHARACTER")
addSlider(pPage,"WalkSpeed",0,500,16,function(v) WalkSpeedVal=v; local h=getHum(); if h then h.WalkSpeed=v end end)
addSlider(pPage,"JumpPower",0,500,50,function(v) JumpPowerVal=v; local h=getHum(); if h then h.UseJumpPower=true; h.JumpPower=v end end)
addToggle(pPage,"God Mode",false,function(on) States.God=on; local h=getHum(); if h then if on then h.MaxHealth=math.huge; h.Health=math.huge else h.MaxHealth=100; h.Health=100 end end end)
addToggle(pPage,"Infinite Jump",false,function(on) States.InfJump=on end)
addLabel(pPage,"-- ACTIONS")
addButton(pPage,"[*] Reset Character",function() local h=getHum(); if h then h.Health=0 end end)
addButton(pPage,"[*] Rejoin Server",function() _TeleportSvc:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player) end)
addButton(pPage,"[*] Server Hop",function()
    local servers=_HttpSvc:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
    if servers and servers.data then for _,s in servers.data do if s.playing<s.maxPlayers and s.id~=game.JobId then
        _TeleportSvc:TeleportToPlaceInstance(game.PlaceId,s.id,Player); break end end end
end)

end -- end Player tab scope

-- ═══════════════ TELEPORT TAB ═══════════════
do
local tPage=Pages["Teleport"]
addLabel(tPage,"-- TELEPORT TO PLAYER")
local tpSelectedPlayer=nil
local tpSelectCard=Instance.new("Frame",tPage); tpSelectCard.Size=UDim2.new(1,0,0,44)
tpSelectCard.BackgroundColor3=C.card; tpSelectCard.BorderSizePixel=0; addCorner(tpSelectCard,8); addStroke(tpSelectCard,C.border,1)
local tpSelectIcon=Instance.new("TextLabel",tpSelectCard); tpSelectIcon.Size=UDim2.new(0,28,1,0); tpSelectIcon.Position=UDim2.new(0,10,0,0)
tpSelectIcon.BackgroundTransparency=1; tpSelectIcon.Text="👤"; tpSelectIcon.TextSize=16; tpSelectIcon.Font=Enum.Font.GothamBold; tpSelectIcon.TextColor3=C.textDim
local tpSelectTop=Instance.new("TextLabel",tpSelectCard); tpSelectTop.Size=UDim2.new(1,-50,0,16); tpSelectTop.Position=UDim2.new(0,38,0,6)
tpSelectTop.BackgroundTransparency=1; tpSelectTop.Text="Select Player to Teleport"; tpSelectTop.TextColor3=C.textDim
tpSelectTop.Font=Enum.Font.GothamMedium; tpSelectTop.TextSize=10; tpSelectTop.TextXAlignment=Enum.TextXAlignment.Left
local tpSelectName=Instance.new("TextLabel",tpSelectCard); tpSelectName.Size=UDim2.new(1,-50,0,18); tpSelectName.Position=UDim2.new(0,38,0,20)
tpSelectName.BackgroundTransparency=1; tpSelectName.Text="— (none selected)"; tpSelectName.TextColor3=C.text
tpSelectName.Font=Enum.Font.GothamBold; tpSelectName.TextSize=13; tpSelectName.TextXAlignment=Enum.TextXAlignment.Left; tpSelectName.TextTruncate=Enum.TextTruncate.AtEnd
local tpSelectChev=Instance.new("TextLabel",tpSelectCard); tpSelectChev.Size=UDim2.new(0,24,1,0); tpSelectChev.Position=UDim2.new(1,-30,0,0)
tpSelectChev.BackgroundTransparency=1; tpSelectChev.Text="▼"; tpSelectChev.TextColor3=C.textDim; tpSelectChev.Font=Enum.Font.GothamBold; tpSelectChev.TextSize=11
local tpDropdown=Instance.new("ScrollingFrame",tPage); tpDropdown.Size=UDim2.new(1,0,0,0)
tpDropdown.BackgroundColor3=Color3.fromRGB(20,20,30); tpDropdown.BorderSizePixel=0; tpDropdown.ClipsDescendants=true; tpDropdown.Visible=false
tpDropdown.ScrollBarThickness=3; tpDropdown.ScrollBarImageColor3=C.accent
tpDropdown.CanvasSize=UDim2.new(0,0,0,0); tpDropdown.AutomaticCanvasSize=Enum.AutomaticSize.Y; tpDropdown.ScrollingDirection=Enum.ScrollingDirection.Y
addCorner(tpDropdown,8); addStroke(tpDropdown,C.accent,1)
local tpDropLayout=Instance.new("UIListLayout",tpDropdown)
tpDropLayout.Padding=UDim.new(0,2); tpDropLayout.SortOrder=Enum.SortOrder.LayoutOrder
local tpDropPad=Instance.new("UIPadding",tpDropdown); tpDropPad.PaddingTop=UDim.new(0,4); tpDropPad.PaddingBottom=UDim.new(0,4); tpDropPad.PaddingLeft=UDim.new(0,4); tpDropPad.PaddingRight=UDim.new(0,4)
local TP_DROP_MAX_H=200; local tpDropOpen=false; local tpSearchQuery=""
local function closeTpDropdown()
    tpDropOpen=false; tpSearchQuery=""; tween(tpDropdown,{Size=UDim2.new(1,0,0,0)},0.18); tween(tpSelectChev,{Rotation=0},0.18)
    task.delay(0.2,function() if not tpDropOpen then tpDropdown.Visible=false end end)
end
local tpPlayerListFrame=nil
local function buildTpPlayerList(filter)
    if not tpPlayerListFrame then return end
    for _,c in tpPlayerListFrame:GetChildren() do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
    local others={}; local query=(filter or ""):lower()
    for _,p in Players:GetPlayers() do
        if p~=Player then if query=="" or p.Name:lower():find(query,1,true) or p.DisplayName:lower():find(query,1,true) then table.insert(others,p) end end
    end
    if #others==0 then
        local noLbl=Instance.new("TextLabel",tpPlayerListFrame); noLbl.Size=UDim2.new(1,0,0,30); noLbl.BackgroundTransparency=1
        noLbl.Text=query~="" and "Player tidak ditemukan" or "No other players"; noLbl.TextColor3=C.textDim; noLbl.Font=Enum.Font.GothamMedium; noLbl.TextSize=11
    else
        for _,p in ipairs(others) do
            local row=Instance.new("TextButton",tpPlayerListFrame); row.Size=UDim2.new(1,0,0,48)
            row.BackgroundColor3=C.card; row.BackgroundTransparency=0.3; row.BorderSizePixel=0; row.Text=""; addCorner(row,6)
            local av=Instance.new("Frame",row); av.Size=UDim2.new(0,30,0,30); av.Position=UDim2.new(0,8,0.5,-15)
            av.BackgroundColor3=Color3.fromHSV((p.UserId%360)/360,0.55,0.75); av.BorderSizePixel=0; addCorner(av,7)
            local avL=Instance.new("TextLabel",av); avL.Size=UDim2.new(1,0,1,0); avL.BackgroundTransparency=1
            avL.Text=string.upper(string.sub(p.Name,1,1)); avL.TextColor3=Color3.new(1,1,1); avL.Font=Enum.Font.GothamBold; avL.TextSize=14
            local rN=Instance.new("TextLabel",row); rN.Size=UDim2.new(1,-50,0,22); rN.Position=UDim2.new(0,46,0,6)
            rN.BackgroundTransparency=1; rN.Text=p.DisplayName; rN.TextColor3=C.text; rN.Font=Enum.Font.GothamBold; rN.TextSize=15; rN.TextXAlignment=Enum.TextXAlignment.Left; rN.TextTruncate=Enum.TextTruncate.AtEnd
            local rU=Instance.new("TextLabel",row); rU.Size=UDim2.new(1,-50,0,16); rU.Position=UDim2.new(0,46,0,27)
            rU.BackgroundTransparency=1; rU.Text="@"..p.Name; rU.TextColor3=C.textDim; rU.Font=Enum.Font.GothamMedium; rU.TextSize=12; rU.TextXAlignment=Enum.TextXAlignment.Left
            row.MouseEnter:Connect(function() tween(row,{BackgroundTransparency=0},0.1) end)
            row.MouseLeave:Connect(function() tween(row,{BackgroundTransparency=0.3},0.1) end)
            row.MouseButton1Click:Connect(function()
                tpSelectedPlayer=p; tpSelectName.Text=p.DisplayName.."  (@"..p.Name..")"; tpSelectIcon.Text="✅"
                tween(tpSelectCard,{BackgroundColor3=Color3.fromRGB(30,35,48)},0.2); closeTpDropdown()
            end)
        end
    end
    local cnt=#others==0 and 1 or #others
    local h=math.min(36+cnt*52+12,TP_DROP_MAX_H); tpDropdown.Size=UDim2.new(1,0,0,h)
end
local function buildTpDropdown(filter)
    for _,c in tpDropdown:GetChildren() do if c:IsA("TextButton") or c:IsA("Frame") or c:IsA("TextBox") then c:Destroy() end end
    -- Search box dibuat sekali saat dropdown dibuka, tidak dihapus saat typing
    local searchBox=Instance.new("TextBox",tpDropdown); searchBox.Name="TpSearchBox"; searchBox.Size=UDim2.new(1,0,0,32)
    searchBox.BackgroundColor3=C.card; searchBox.BorderSizePixel=0; searchBox.PlaceholderText="🔍 Cari nama / username player..."
    searchBox.PlaceholderColor3=C.textDim; searchBox.Text=filter or ""; searchBox.TextColor3=C.text
    searchBox.Font=Enum.Font.GothamMedium; searchBox.TextSize=12; searchBox.ClearTextOnFocus=false; searchBox.LayoutOrder=0; addCorner(searchBox,6)
    -- Container terpisah untuk list player — hanya ini yang direbuild saat search
    tpPlayerListFrame=Instance.new("Frame",tpDropdown); tpPlayerListFrame.Name="TpPlayerList"
    tpPlayerListFrame.LayoutOrder=1
    tpPlayerListFrame.Size=UDim2.new(1,0,0,0); tpPlayerListFrame.BackgroundTransparency=1
    tpPlayerListFrame.AutomaticSize=Enum.AutomaticSize.Y; tpPlayerListFrame.BorderSizePixel=0
    local plLayout=Instance.new("UIListLayout",tpPlayerListFrame); plLayout.Padding=UDim.new(0,2)
    -- Saat text berubah hanya rebuild list, bukan seluruh dropdown (searchBox tetap fokus)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        tpSearchQuery=searchBox.Text; buildTpPlayerList(searchBox.Text)
    end)
    buildTpPlayerList(filter)
    local others={}; for _,p in Players:GetPlayers() do if p~=Player then table.insert(others,p) end end
    local totalH=36+(#others==0 and 1 or #others)*52+12; return math.min(totalH,TP_DROP_MAX_H)
end
local tpSelectClickBtn=Instance.new("TextButton",tpSelectCard); tpSelectClickBtn.Size=UDim2.new(1,0,1,0)
tpSelectClickBtn.BackgroundTransparency=1; tpSelectClickBtn.Text=""; tpSelectClickBtn.ZIndex=5
tpSelectClickBtn.MouseButton1Click:Connect(function()
    if tpDropOpen then closeTpDropdown()
    else tpDropOpen=true; tpDropdown.Visible=true; local dropH=buildTpDropdown(); tween(tpDropdown,{Size=UDim2.new(1,0,0,dropH)},0.2); tween(tpSelectChev,{Rotation=180},0.18) end
end)
local tpActionBtn=Instance.new("TextButton",tPage); tpActionBtn.Size=UDim2.new(1,0,0,38)
tpActionBtn.BackgroundColor3=C.accent; tpActionBtn.BackgroundTransparency=0.2; tpActionBtn.BorderSizePixel=0
tpActionBtn.Text="▶  Teleport to Player"; tpActionBtn.TextColor3=C.text; tpActionBtn.Font=Enum.Font.GothamBold; tpActionBtn.TextSize=13; addCorner(tpActionBtn,8)
tpActionBtn.MouseEnter:Connect(function() tween(tpActionBtn,{BackgroundTransparency=0},0.15) end)
tpActionBtn.MouseLeave:Connect(function() tween(tpActionBtn,{BackgroundTransparency=0.2},0.15) end)
tpActionBtn.MouseButton1Click:Connect(function()
    if not tpSelectedPlayer then notify("Teleport","Pilih player dulu!"); tween(tpSelectCard,{BackgroundColor3=C.red},0.1); task.delay(0.3,function() tween(tpSelectCard,{BackgroundColor3=C.card},0.3) end); return end
    local hrp=getHRP(); local t=tpSelectedPlayer.Character and tpSelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and t then hrp.CFrame=t.CFrame*CFrame.new(0,0,3); tween(tpActionBtn,{BackgroundColor3=C.green},0.1); task.delay(0.4,function() tween(tpActionBtn,{BackgroundColor3=C.accent},0.3) end); notify("Teleported","→ "..tpSelectedPlayer.DisplayName)
    else notify("Error",tpSelectedPlayer.DisplayName.." tidak ditemukan"); tween(tpActionBtn,{BackgroundColor3=C.red},0.1); task.delay(0.4,function() tween(tpActionBtn,{BackgroundColor3=C.accent},0.3) end) end
end)
addToggle(tPage,"Auto Follow Player (selected)",false,function(on)
    if Connections.autoFollow then Connections.autoFollow:Disconnect() end
    if on then
        if not tpSelectedPlayer then notify("Auto Follow","Pilih player dulu!") return end
        Connections.autoFollow=RunService.Heartbeat:Connect(function()
            if not tpSelectedPlayer then return end
            local hrp=getHRP(); local t=tpSelectedPlayer.Character and tpSelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and t then local dist=(hrp.Position-t.Position).Magnitude; if dist>5 then hrp.CFrame=t.CFrame*CFrame.new(0,0,3) end end
        end); notify("Auto Follow","Following: "..(tpSelectedPlayer and tpSelectedPlayer.DisplayName or "?"))
    else notify("Auto Follow","Stopped") end
end)
addLabel(tPage,"-- TELEPORT TO POSITION")
addInput(tPage,"X, Y, Z (e.g. 100, 50, 200)",function(text)
    local coords={}; for n in text:gmatch("[%-]?%d+%.?%d*") do table.insert(coords,tonumber(n)) end
    if #coords>=3 then local hrp=getHRP(); if hrp then hrp.CFrame=CFrame.new(coords[1],coords[2],coords[3]); notify("Teleported",string.format("→ %.0f, %.0f, %.0f",coords[1],coords[2],coords[3])) end
    else notify("Error","Use format: X, Y, Z") end
end)
addLabel(tPage,"-- QUICK TELEPORT")
addButton(tPage,"[^] TP to Highest Point",function() local hrp=getHRP(); if hrp then hrp.CFrame=hrp.CFrame+Vector3.new(0,500,0) end end)
addButton(tPage,"[H] TP to Spawn",function()
    local hrp=getHRP(); local spawn=Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChildOfClass("SpawnLocation")
    if hrp and spawn then hrp.CFrame=spawn.CFrame+Vector3.new(0,5,0) elseif hrp then hrp.CFrame=CFrame.new(0,50,0) end
end)
end -- end Teleport tab scope

-- ═══════════════ MOVEMENT TAB ═══════════════
do
local mPage=Pages["Movement"]
addLabel(mPage,"-- MOVEMENT HACKS")
addToggle(mPage,"NoClip",false,function(on)
    States.NoClip=on
    if on then Connections.noclip=RunService.Stepped:Connect(function() local c=getChar(); if c then for _,p in c:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end end end); notify("NoClip","Enabled ✅")
    else if Connections.noclip then Connections.noclip:Disconnect() end; notify("NoClip","Disabled ❌") end
end)
addToggle(mPage,"Fly",false,function(on)
    States.Fly=on; local hrp=getHRP(); local hum=getHum(); if not hrp or not hum then return end
    if on then
        local bg=Instance.new("BodyGyro",hrp); bg.Name="FlyGyro"; bg.P=9e4; bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.CFrame=hrp.CFrame
        local bv=Instance.new("BodyVelocity",hrp); bv.Name="FlyVelocity"; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.Velocity=Vector3.new(0,0,0)
        flyBody.bg=bg; flyBody.bv=bv
        Connections.fly=RunService.RenderStepped:Connect(function()
            if not States.Fly then return end
            local cam=Workspace.CurrentCamera; bg.CFrame=cam.CFrame; local dir=Vector3.new(0,0,0)
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir=dir+cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir=dir-cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir=dir-cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir=dir+cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir=dir-Vector3.new(0,1,0) end
            local hum2=getHum()
            if hum2 and hum2.MoveDirection.Magnitude>0.1 then
                local md=hum2.MoveDirection
                local camFlat=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z).Unit
                local camRight=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z).Unit
                dir=dir+(camFlat*md:Dot(camFlat))+(camRight*md:Dot(camRight))
            end
            local ts2=UIS:GetGamepadState(Enum.UserInputType.Gamepad1)
            for _,inp in ipairs(ts2) do if inp.KeyCode==Enum.KeyCode.Thumbstick2 then dir=dir+Vector3.new(0,inp.Position.Y,0) end end
            bv.Velocity=dir.Magnitude>0 and dir.Unit*FlySpeed or Vector3.new(0,0,0)
        end); notify("Fly","Enabled ✅")
    else
        if Connections.fly then Connections.fly:Disconnect() end
        if flyBody.bg then flyBody.bg:Destroy() end
        if flyBody.bv then flyBody.bv:Destroy() end
        notify("Fly","Disabled ❌")
    end
end)
addSlider(mPage,"Fly Speed",10,500,50,function(v) FlySpeed=v end)
UIS.JumpRequest:Connect(function() if States.InfJump then local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
end -- end Movement tab scope

-- ═══════════════ VISUAL TAB ═══════════════
do
local vPage=Pages["Visual"]
addLabel(vPage,"-- ESP & VISUALS")
local function addESPHighlight(p)
    if p==Player then return end; local c=p.Character; if not c then return end
    local ex=c:FindFirstChild("ESPHighlight"); if ex then ex:Destroy() end
    local h=Instance.new("Highlight",c); h.Name="ESPHighlight"; h.FillColor=C.accent; h.FillTransparency=0.7; h.OutlineColor=C.accent; h.OutlineTransparency=0.3
end
local function removeESPHighlights()
    for _,p in Players:GetPlayers() do if p.Character then local h=p.Character:FindFirstChild("ESPHighlight"); if h then h:Destroy() end end end
end
addToggle(vPage,"Player ESP (Highlight)",false,function(on)
    States.ESP=on
    if on then
        for _,p in Players:GetPlayers() do if p.Character then addESPHighlight(p) end; p.CharacterAdded:Connect(function() task.wait(1); if States.ESP then addESPHighlight(p) end end) end
        Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(1); if States.ESP then addESPHighlight(p) end end) end)
        notify("ESP","Enabled ✅")
    else
        removeESPHighlights(); notify("ESP","Disabled ❌")
    end
end)
local espTracerLines={}
addToggle(vPage,"Player ESP (Tracers + Highlight)",false,function(on)
    for _,lineObj in pairs(espTracerLines) do pcall(function() lineObj:Remove() end) end; espTracerLines={}
    if Connections.espTracers then Connections.espTracers:Disconnect(); Connections.espTracers=nil end
    if on then
        -- Nyalakan highlight sekalian
        States.ESP=true
        for _,p in Players:GetPlayers() do if p.Character then addESPHighlight(p) end; p.CharacterAdded:Connect(function() task.wait(1); if States.ESP then addESPHighlight(p) end end) end
        Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(1); if States.ESP then addESPHighlight(p) end end) end)
        -- Tracer dari atas layar
        Connections.espTracers=RunService.RenderStepped:Connect(function()
            local cam=Workspace.CurrentCamera; local vp=cam.ViewportSize
            local fromPos=Vector2.new(vp.X/2, 0)  -- dari atas tengah
            for uid,lineObj in pairs(espTracerLines) do lineObj.Visible=false end
            for _,p in Players:GetPlayers() do
                if p~=Player and p.Character then
                    local hrp=p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local screenPos,onScreen=cam:WorldToViewportPoint(hrp.Position)
                        if onScreen and screenPos.Z>0 then
                            local uid=p.UserId
                            if not espTracerLines[uid] then
                                local line=Drawing.new("Line"); line.Thickness=1.2
                                line.Color=Color3.fromRGB(180,220,255)  -- biru muda lembut
                                line.Transparency=1
                                espTracerLines[uid]=line
                            end
                            espTracerLines[uid].From=fromPos
                            espTracerLines[uid].To=Vector2.new(screenPos.X,screenPos.Y)
                            espTracerLines[uid].Visible=true
                        end
                    end
                end
            end
        end)
        notify("ESP Tracers","Enabled ✅ (+ Highlight)")
    else
        States.ESP=false; removeESPHighlights(); notify("ESP Tracers","Disabled ❌")
    end
end)
addToggle(vPage,"Fullbright",false,function(on)
    States.Fullbright=on; local li=_Lighting
    if on then li.Brightness=2; li.ClockTime=14; li.FogEnd=100000; li.GlobalShadows=false
        for _,v in li:GetChildren() do if v:IsA("Atmosphere") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then v.Enabled=false end end
        notify("Fullbright","Enabled ✅")
    else li.GlobalShadows=true; li.Brightness=1
        for _,v in li:GetChildren() do if v:IsA("Atmosphere") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then v.Enabled=true end end
        notify("Fullbright","Disabled ❌") end
end)
addLabel(vPage,"-- CAMERA")
addSlider(vPage,"FOV",30,120,70,function(v) Workspace.CurrentCamera.FieldOfView=v end)
addButton(vPage,"Reset FOV",function() Workspace.CurrentCamera.FieldOfView=70 end)

-- Freecam HUD
local FreecamHUD=Instance.new("Frame",ScreenGui); FreecamHUD.Name="FreecamHUD"
FreecamHUD.Size=UDim2.new(0,250,0,148); FreecamHUD.Position=UDim2.new(1,-264,1,-162)
FreecamHUD.BackgroundColor3=Color3.fromRGB(13,13,20); FreecamHUD.BackgroundTransparency=0.1
FreecamHUD.BorderSizePixel=0; FreecamHUD.Visible=false; FreecamHUD.ZIndex=60; addCorner(FreecamHUD,14); addStroke(FreecamHUD,C.accent,1.5)
do
    local fDrag,fStart,fPos=false,nil,nil
    FreecamHUD.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then fDrag=true; fStart=i.Position; fPos=FreecamHUD.Position end end)
    UIS.InputChanged:Connect(function(i) if fDrag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-fStart; FreecamHUD.Position=UDim2.new(fPos.X.Scale,fPos.X.Offset+d.X,fPos.Y.Scale,fPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then fDrag=false end end)
end
local fcHudTitle=Instance.new("TextLabel",FreecamHUD); fcHudTitle.Size=UDim2.new(1,-16,0,22); fcHudTitle.Position=UDim2.new(0,12,0,10)
fcHudTitle.BackgroundTransparency=1; fcHudTitle.Text="📷  FREECAM"; fcHudTitle.TextColor3=C.accent; fcHudTitle.Font=Enum.Font.GothamBold; fcHudTitle.TextSize=13; fcHudTitle.TextXAlignment=Enum.TextXAlignment.Left; fcHudTitle.ZIndex=61
local fcSpeedValue=Instance.new("TextLabel",FreecamHUD); fcSpeedValue.Size=UDim2.new(0.5,-14,0,18); fcSpeedValue.Position=UDim2.new(0.5,0,0,36)
fcSpeedValue.BackgroundTransparency=1; fcSpeedValue.Text="1.00"; fcSpeedValue.TextColor3=C.text; fcSpeedValue.Font=Enum.Font.GothamBold; fcSpeedValue.TextSize=14; fcSpeedValue.TextXAlignment=Enum.TextXAlignment.Right; fcSpeedValue.ZIndex=61
local fcSpeedLbl=Instance.new("TextLabel",FreecamHUD); fcSpeedLbl.Size=UDim2.new(0.5,0,0,18); fcSpeedLbl.Position=UDim2.new(0,12,0,36)
fcSpeedLbl.BackgroundTransparency=1; fcSpeedLbl.Text="Speed"; fcSpeedLbl.TextColor3=C.textDim; fcSpeedLbl.Font=Enum.Font.GothamMedium; fcSpeedLbl.TextSize=12; fcSpeedLbl.TextXAlignment=Enum.TextXAlignment.Left; fcSpeedLbl.ZIndex=61
local fcTrack=Instance.new("Frame",FreecamHUD); fcTrack.Size=UDim2.new(1,-24,0,6); fcTrack.Position=UDim2.new(0,12,0,60)
fcTrack.BackgroundColor3=C.toggleOff; fcTrack.BorderSizePixel=0; fcTrack.ZIndex=61; addCorner(fcTrack,3)
local fcFill=Instance.new("Frame",fcTrack); fcFill.Size=UDim2.new(0.05,0,1,0); fcFill.BackgroundColor3=C.accent; fcFill.BorderSizePixel=0; fcFill.ZIndex=62; addCorner(fcFill,3)
local function makeSpeedBtn(txt,xOff)
    local b=Instance.new("TextButton",FreecamHUD); b.Size=UDim2.new(0,34,0,30); b.Position=UDim2.new(0,xOff,0,74)
    b.BackgroundColor3=C.card; b.BorderSizePixel=0; b.Text=txt; b.TextColor3=C.text; b.Font=Enum.Font.GothamBold; b.TextSize=16; b.ZIndex=62; addCorner(b,7)
    b.MouseEnter:Connect(function() tween(b,{BackgroundColor3=C.accent},0.12) end); b.MouseLeave:Connect(function() tween(b,{BackgroundColor3=C.card},0.12) end); return b
end
local fcMinusBtn=makeSpeedBtn("−",12); local fcPlusBtn=makeSpeedBtn("+",204)
local fcSpeedInputBg=Instance.new("Frame",FreecamHUD); fcSpeedInputBg.Size=UDim2.new(1,-110,0,30); fcSpeedInputBg.Position=UDim2.new(0,52,0,74)
fcSpeedInputBg.BackgroundColor3=C.card; fcSpeedInputBg.BorderSizePixel=0; fcSpeedInputBg.ZIndex=61; addCorner(fcSpeedInputBg,7); addStroke(fcSpeedInputBg,C.border,1)
local fcSpeedInput=Instance.new("TextBox",fcSpeedInputBg); fcSpeedInput.Size=UDim2.new(1,-10,1,0); fcSpeedInput.Position=UDim2.new(0,5,0,0)
fcSpeedInput.BackgroundTransparency=1; fcSpeedInput.Text="1.00"; fcSpeedInput.PlaceholderText="speed"; fcSpeedInput.PlaceholderColor3=C.textDim
fcSpeedInput.TextColor3=C.text; fcSpeedInput.Font=Enum.Font.GothamBold; fcSpeedInput.TextSize=14; fcSpeedInput.ClearTextOnFocus=false; fcSpeedInput.ZIndex=62
local fcHint=Instance.new("TextLabel",FreecamHUD); fcHint.Size=UDim2.new(1,-24,0,14); fcHint.Position=UDim2.new(0,12,0,112)
fcHint.BackgroundTransparency=1; fcHint.Text="RMB=look · WASD/Space/Shift · Q/E speed"; fcHint.TextColor3=C.textDim; fcHint.Font=Enum.Font.GothamMedium; fcHint.TextSize=9; fcHint.TextXAlignment=Enum.TextXAlignment.Left; fcHint.ZIndex=61
local fcStopBtn=Instance.new("TextButton",FreecamHUD); fcStopBtn.Size=UDim2.new(1,-24,0,28); fcStopBtn.Position=UDim2.new(0,12,1,-34)
fcStopBtn.BackgroundColor3=C.red; fcStopBtn.BackgroundTransparency=0.2; fcStopBtn.BorderSizePixel=0; fcStopBtn.Text="■   Stop Freecam"
fcStopBtn.TextColor3=Color3.new(1,1,1); fcStopBtn.Font=Enum.Font.GothamBold; fcStopBtn.TextSize=13; fcStopBtn.ZIndex=62; addCorner(fcStopBtn,7)
fcStopBtn.MouseEnter:Connect(function() tween(fcStopBtn,{BackgroundTransparency=0},0.12) end); fcStopBtn.MouseLeave:Connect(function() tween(fcStopBtn,{BackgroundTransparency=0.2},0.12) end)
local freecamSpeedShared=0.01; local FC_MAX_SPEED=200; local FC_MIN_SPEED=0.01
local function setFreecamSpeed(v)
    local parsed=tonumber(v); if not parsed then return end
    freecamSpeedShared=math.clamp(parsed,FC_MIN_SPEED,FC_MAX_SPEED)
    fcSpeedValue.Text=string.format("%.2f",freecamSpeedShared); fcSpeedInput.Text=string.format("%.2f",freecamSpeedShared)
    local logRatio=math.log(freecamSpeedShared/FC_MIN_SPEED)/math.log(FC_MAX_SPEED/FC_MIN_SPEED)
    fcFill.Size=UDim2.new(math.clamp(logRatio,0,1),0,1,0)
end
fcMinusBtn.MouseButton1Click:Connect(function() setFreecamSpeed(freecamSpeedShared-0.05) end)
fcPlusBtn.MouseButton1Click:Connect(function() setFreecamSpeed(freecamSpeedShared+0.05) end)
fcSpeedInput.FocusLost:Connect(function() setFreecamSpeed(fcSpeedInput.Text) end)
local freecamToggleState=false; local freecamSetState=nil
local function stopFreecam()
    if not freecamToggleState then return end; freecamToggleState=false; States.Freecam=false
    if Connections.freecam then Connections.freecam:Disconnect() end
    if Connections.freecamRmb then Connections.freecamRmb:Disconnect() end
    if Connections.freecamRmbEnd then Connections.freecamRmbEnd:Disconnect() end
    UIS.MouseBehavior=Enum.MouseBehavior.Default; FreecamHUD.Visible=false
    if freecamSetState then freecamSetState(false) end
    local cam=Workspace.CurrentCamera; cam.CameraType=Enum.CameraType.Custom; cam.CameraSubject=getHum()
    local hrpFC=getHRP(); local humFC=getHum()
    if hrpFC then hrpFC.Anchored=false end
    if humFC then humFC.WalkSpeed=WalkSpeedVal; humFC.JumpPower=JumpPowerVal end
    notify("Freecam","OFF")
end
fcStopBtn.MouseButton1Click:Connect(stopFreecam)
local _,fcSetState=addToggle(vPage,"Freecam  (tahan RMB = look)",false,function(on)
    local cam=Workspace.CurrentCamera
    if on then
        States.Freecam=true; freecamToggleState=true; cam.CameraType=Enum.CameraType.Scriptable
        local hrpFC=getHRP(); local humFC=getHum()
        if hrpFC then hrpFC.Anchored=true end; if humFC then humFC.WalkSpeed=0; humFC.JumpPower=0 end
        local _,yaw,_=cam.CFrame:ToEulerAnglesYXZ(); local freecamYaw=yaw; local freecamPitch=0; local isLooking=false; local eHeld=false; local qHeld=false
        Connections.freecamRmb=UIS.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton2 then isLooking=true; UIS.MouseBehavior=Enum.MouseBehavior.LockCenter end end)
        Connections.freecamRmbEnd=UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton2 then isLooking=false; UIS.MouseBehavior=Enum.MouseBehavior.Default end end)
        Connections.freecam=RunService.RenderStepped:Connect(function()
            if not States.Freecam then return end
            if isLooking then local d=UIS:GetMouseDelta(); freecamYaw=freecamYaw-d.X*0.003; freecamPitch=math.clamp(freecamPitch-d.Y*0.003,math.rad(-89),math.rad(89)) end
            if UIS:IsKeyDown(Enum.KeyCode.E) then if not eHeld then eHeld=true; setFreecamSpeed(freecamSpeedShared+0.05) end else eHeld=false end
            if UIS:IsKeyDown(Enum.KeyCode.Q) then if not qHeld then qHeld=true; setFreecamSpeed(freecamSpeedShared-0.05) end else qHeld=false end
            local rotCF=CFrame.fromEulerAnglesYXZ(freecamPitch,freecamYaw,0); local pos=cam.CFrame.Position; local move=Vector3.new(0,0,0)
            if UIS:IsKeyDown(Enum.KeyCode.W) then move+=rotCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move-=rotCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move-=rotCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move+=rotCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then move+=Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move-=Vector3.yAxis end
            cam.CFrame=CFrame.new(pos+move*freecamSpeedShared)*rotCF
        end)
        FreecamHUD.Visible=true; setFreecamSpeed(0.10); notify("Freecam","ON  |  RMB=look  |  Q/E=speed")
    else stopFreecam() end
end)
freecamSetState=fcSetState

-- Spectate
addLabel(vPage,"-- SPECTATE PLAYER")
local SpectateOverlay=Instance.new("Frame",ScreenGui); SpectateOverlay.Name="SpectateOverlay"
SpectateOverlay.Size=UDim2.new(0,338,0,96); SpectateOverlay.Position=UDim2.new(1,-352,1,-110)
SpectateOverlay.BackgroundColor3=Color3.fromRGB(13,13,20); SpectateOverlay.BackgroundTransparency=0.08
SpectateOverlay.BorderSizePixel=0; SpectateOverlay.Visible=false; SpectateOverlay.ZIndex=50; addCorner(SpectateOverlay,14); addStroke(SpectateOverlay,C.accent,1.5)
do
    local sDrag=false; local sDragStart; local sDragPos
    SpectateOverlay.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sDrag=true; sDragStart=i.Position; sDragPos=SpectateOverlay.Position end end)
    UIS.InputChanged:Connect(function(i) if sDrag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-sDragStart; SpectateOverlay.Position=UDim2.new(sDragPos.X.Scale,sDragPos.X.Offset+d.X,sDragPos.Y.Scale,sDragPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sDrag=false end end)
end
local SpectDot=Instance.new("Frame",SpectateOverlay); SpectDot.Size=UDim2.new(0,10,0,10); SpectDot.Position=UDim2.new(0,14,0,16)
SpectDot.BackgroundColor3=C.red; SpectDot.BorderSizePixel=0; SpectDot.ZIndex=51; addCorner(SpectDot,5)
task.spawn(function() while true do task.wait(0.7); if SpectateOverlay.Visible then tween(SpectDot,{BackgroundTransparency=0.8},0.35); task.wait(0.35); tween(SpectDot,{BackgroundTransparency=0},0.35) end end end)
local SpectTopLabel=Instance.new("TextLabel",SpectateOverlay); SpectTopLabel.Size=UDim2.new(1,-140,0,18); SpectTopLabel.Position=UDim2.new(0,32,0,10)
SpectTopLabel.BackgroundTransparency=1; SpectTopLabel.Text="SPECTATING"; SpectTopLabel.TextColor3=C.textDim; SpectTopLabel.Font=Enum.Font.GothamBold; SpectTopLabel.TextSize=11; SpectTopLabel.TextXAlignment=Enum.TextXAlignment.Left; SpectTopLabel.ZIndex=51
local SpectNameLabel=Instance.new("TextLabel",SpectateOverlay); SpectNameLabel.Size=UDim2.new(1,-145,0,26); SpectNameLabel.Position=UDim2.new(0,14,0,30)
SpectNameLabel.BackgroundTransparency=1; SpectNameLabel.Text="—"; SpectNameLabel.TextColor3=C.text; SpectNameLabel.Font=Enum.Font.GothamBold; SpectNameLabel.TextSize=18; SpectNameLabel.TextXAlignment=Enum.TextXAlignment.Left; SpectNameLabel.TextTruncate=Enum.TextTruncate.AtEnd; SpectNameLabel.ZIndex=51
local SpectCounterLabel=Instance.new("TextLabel",SpectateOverlay); SpectCounterLabel.Size=UDim2.new(1,-145,0,16); SpectCounterLabel.Position=UDim2.new(0,14,1,-22)
SpectCounterLabel.BackgroundTransparency=1; SpectCounterLabel.Text=""; SpectCounterLabel.TextColor3=C.textDim; SpectCounterLabel.Font=Enum.Font.GothamMedium; SpectCounterLabel.TextSize=11; SpectCounterLabel.TextXAlignment=Enum.TextXAlignment.Left; SpectCounterLabel.ZIndex=51
local navFrame=Instance.new("Frame",SpectateOverlay); navFrame.Size=UDim2.new(0,124,0,44); navFrame.Position=UDim2.new(1,-134,0.5,-22); navFrame.BackgroundTransparency=1; navFrame.BorderSizePixel=0; navFrame.ZIndex=51
local function makeNavBtn(parent,txt,xOff,col,zIdx)
    local b=Instance.new("TextButton",parent); b.Size=UDim2.new(0,38,0,38); b.Position=UDim2.new(0,xOff,0.5,-19)
    b.BackgroundColor3=col or C.card; b.BackgroundTransparency=0.25; b.BorderSizePixel=0; b.Text=txt; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=18; b.ZIndex=zIdx or 52; addCorner(b,8)
    b.MouseEnter:Connect(function() tween(b,{BackgroundTransparency=0},0.1) end); b.MouseLeave:Connect(function() tween(b,{BackgroundTransparency=0.25},0.1) end); return b
end
local SpectPrevBtn=makeNavBtn(navFrame,"◀",0,C.card); local SpectStopBtn=makeNavBtn(navFrame,"■",43,C.red); local SpectNextBtn=makeNavBtn(navFrame,"▶",86,C.card)
local spectPlayerListCache={}; local spectCurrentIndex=1
local function getSpectablePlayers() local list={}; for _,p in Players:GetPlayers() do if p~=Player then table.insert(list,p) end end; return list end
local function stopSpectate()
    States.Spectating=false; spectateTarget=nil; Workspace.CurrentCamera.CameraSubject=getHum(); SpectateOverlay.Visible=false
    local hrp=getHRP(); local hum=getHum(); if hrp then hrp.Anchored=false end; if hum then hum.WalkSpeed=WalkSpeedVal; hum.JumpPower=JumpPowerVal end
    if Connections.spectateKeys then Connections.spectateKeys:Disconnect(); Connections.spectateKeys=nil end; notify("Spectate","Stopped")
end
local function applySpectate(p)
    if not p then return end
    if p.Character and p.Character:FindFirstChildOfClass("Humanoid") then
        States.Spectating=true; spectateTarget=p; Workspace.CurrentCamera.CameraSubject=p.Character:FindFirstChildOfClass("Humanoid")
        SpectNameLabel.Text=p.DisplayName; local total=#spectPlayerListCache; local idx=table.find(spectPlayerListCache,p) or spectCurrentIndex
        SpectCounterLabel.Text="@"..p.Name.."  ·  "..idx.." / "..total; SpectateOverlay.Visible=true
        local hrp=getHRP(); local hum=getHum(); if hrp then hrp.Anchored=true end; if hum then hum.WalkSpeed=0; hum.JumpPower=0 end
        if not Connections.spectateKeys then
            local seHeld,sqHeld=false,false
            Connections.spectateKeys=RunService.RenderStepped:Connect(function()
                if not States.Spectating then return end
                if UIS:IsKeyDown(Enum.KeyCode.E) then if not seHeld then seHeld=true; spectPlayerListCache=getSpectablePlayers(); if #spectPlayerListCache>0 then spectCurrentIndex=spectCurrentIndex+1; if spectCurrentIndex>#spectPlayerListCache then spectCurrentIndex=1 end; applySpectate(spectPlayerListCache[spectCurrentIndex]) end end else seHeld=false end
                if UIS:IsKeyDown(Enum.KeyCode.Q) then if not sqHeld then sqHeld=true; spectPlayerListCache=getSpectablePlayers(); if #spectPlayerListCache>0 then spectCurrentIndex=spectCurrentIndex-1; if spectCurrentIndex<1 then spectCurrentIndex=#spectPlayerListCache end; applySpectate(spectPlayerListCache[spectCurrentIndex]) end end else sqHeld=false end
            end)
        end
    else notify("Spectate",p.DisplayName.." has no character") end
end
SpectStopBtn.MouseButton1Click:Connect(stopSpectate)
SpectPrevBtn.MouseButton1Click:Connect(function() spectPlayerListCache=getSpectablePlayers(); if #spectPlayerListCache==0 then return end; spectCurrentIndex=spectCurrentIndex-1; if spectCurrentIndex<1 then spectCurrentIndex=#spectPlayerListCache end; applySpectate(spectPlayerListCache[spectCurrentIndex]) end)
SpectNextBtn.MouseButton1Click:Connect(function() spectPlayerListCache=getSpectablePlayers(); if #spectPlayerListCache==0 then return end; spectCurrentIndex=spectCurrentIndex+1; if spectCurrentIndex>#spectPlayerListCache then spectCurrentIndex=1 end; applySpectate(spectPlayerListCache[spectCurrentIndex]) end)
-- Search spectate by display name
local spectSearchHolder=Instance.new("Frame",vPage); spectSearchHolder.Size=UDim2.new(1,0,0,36)
spectSearchHolder.BackgroundColor3=C.card; spectSearchHolder.BorderSizePixel=0; addCorner(spectSearchHolder,8)
local spectSearchBox=Instance.new("TextBox",spectSearchHolder); spectSearchBox.Size=UDim2.new(1,-12,1,0); spectSearchBox.Position=UDim2.new(0,8,0,0)
spectSearchBox.BackgroundTransparency=1; spectSearchBox.PlaceholderText="🔍 Cari nama display player..."; spectSearchBox.PlaceholderColor3=C.textDim; spectSearchBox.Text=""
spectSearchBox.TextColor3=C.text; spectSearchBox.Font=Enum.Font.GothamMedium; spectSearchBox.TextSize=12; spectSearchBox.ClearTextOnFocus=false
local spectListContainer=Instance.new("Frame",vPage); spectListContainer.Size=UDim2.new(1,0,0,0); spectListContainer.BackgroundTransparency=1; spectListContainer.AutomaticSize=Enum.AutomaticSize.Y
Instance.new("UIListLayout",spectListContainer).Padding=UDim.new(0,4)
local spectSearchQuery=""
local function refreshSpectList()
    for _,c in spectListContainer:GetChildren() do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
    spectPlayerListCache=getSpectablePlayers()
    local filtered={}
    local q=string.lower(spectSearchQuery)
    for i,p in ipairs(spectPlayerListCache) do
        if q=="" or string.lower(p.DisplayName):find(q,1,true) or string.lower(p.Name):find(q,1,true) then
            table.insert(filtered,{p=p,i=i})
        end
    end
    for _,entry in ipairs(filtered) do
        local p,i=entry.p,entry.i
        addButton(spectListContainer,"👁  "..p.DisplayName.." (@"..p.Name..")",function() spectCurrentIndex=i; applySpectate(p); if States.Spectating then notify("Spectate","👁 Watching: "..p.DisplayName) end end)
    end
    if #filtered==0 then
        local noOne=Instance.new("TextLabel",spectListContainer); noOne.Size=UDim2.new(1,0,0,30); noOne.BackgroundTransparency=1
        noOne.Text=spectSearchQuery~="" and "Tidak ada player: '"..spectSearchQuery.."'" or "No other players in server"
        noOne.TextColor3=C.textDim; noOne.Font=Enum.Font.GothamMedium; noOne.TextSize=12
    end
end
spectSearchBox:GetPropertyChangedSignal("Text"):Connect(function() spectSearchQuery=spectSearchBox.Text; refreshSpectList() end)
refreshSpectList()
addButton(vPage,"[*] Refresh Spectate List",refreshSpectList); addButton(vPage,"[X] Stop Spectate",stopSpectate)
addLabel(vPage,"-- LOCATE PLAYER")
addInput(vPage,"Player name to locate...",function(text)
    if text=="" then return end
    for _,p in Players:GetPlayers() do
        if p.Name:lower():find(text:lower()) or p.DisplayName:lower():find(text:lower()) then
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local pos=p.Character.HumanoidRootPart.Position; local myPos=getHRP() and getHRP().Position or Vector3.new(0,0,0)
                local dist=math.floor((pos-myPos).Magnitude)
                notify("Locate: "..p.DisplayName,string.format("Pos: %.0f, %.0f, %.0f\nDist: %d studs",pos.X,pos.Y,pos.Z,dist))
                pcall(function() local beam=Instance.new("Highlight",p.Character); beam.Name="LocateHL"; beam.FillColor=Color3.fromRGB(255,255,0); beam.FillTransparency=0.5; beam.OutlineColor=Color3.fromRGB(255,255,0); task.delay(5,function() if beam then beam:Destroy() end end) end)
            else notify("Locate",p.DisplayName.." has no character") end; return
        end
    end; notify("Error","Player not found")
end)
end -- end Visual tab scope

-- ═══════════════ DANCE TAB ═══════════════
do
local dPage=Pages["Dance"]
local currentEmoteTrack=nil; local currentAnimTrack=nil; local savedAnimateScript=nil; local loopAnimEnabled=false
local function killAllCharacterAnims()
    local hum=getHum(); if not hum then return end
    local animator=hum:FindFirstChildOfClass("Animator")
    if animator then for _,track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0); track:Destroy() end end
end
local function disableAnimateScript()
    local char=getChar(); if not char then return end
    local animScript=char:FindFirstChild("Animate"); if animScript then savedAnimateScript=animScript:Clone(); animScript:Destroy() end
end
local function restoreAnimateScript()
    if savedAnimateScript then local char=getChar(); if char then local ex=char:FindFirstChild("Animate"); if ex then ex:Destroy() end; savedAnimateScript.Parent=char; savedAnimateScript=nil end end
end
local function stopAllDanceAnims()
    if currentEmoteTrack then pcall(function() currentEmoteTrack:Stop(); currentEmoteTrack:Destroy() end); currentEmoteTrack=nil end
    if currentAnimTrack then pcall(function() currentAnimTrack:Stop(); currentAnimTrack:Destroy() end); currentAnimTrack=nil end
    restoreAnimateScript()
end
local function resolveEmoteId(emoteId)
    local animationId=nil
    pcall(function() local model=_InsertSvc:LoadAsset(emoteId); if model then for _,desc in ipairs(model:GetDescendants()) do if desc:IsA("Animation") then animationId=desc.AnimationId; break end end; model:Destroy() end end)
    if not animationId then pcall(function() if game.GetObjects then local objects=game:GetObjects("rbxassetid://"..tostring(emoteId)); if objects and objects[1] then if objects[1]:IsA("Animation") then animationId=objects[1].AnimationId else for _,desc in ipairs(objects[1]:GetDescendants()) do if desc:IsA("Animation") then animationId=desc.AnimationId; break end end end; objects[1]:Destroy() end end end) end
    if not animationId then animationId="rbxassetid://"..tostring(emoteId) end
    return animationId
end
local function playEmoteById(emoteId)
    stopAllDanceAnims(); local hum=getHum(); if not hum then notify("Dance","No character found") return end
    killAllCharacterAnims(); disableAnimateScript()
    local animator=hum:FindFirstChildOfClass("Animator"); if not animator then animator=Instance.new("Animator",hum) end
    local animationId=resolveEmoteId(emoteId); local anim=Instance.new("Animation"); anim.AnimationId=animationId
    local ok,track=pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority=Enum.AnimationPriority.Action4; track.Looped=loopAnimEnabled; track:Play(0); currentEmoteTrack=track
        notify("Dance","Playing emote: "..tostring(emoteId))
        track.Stopped:Connect(function() if currentEmoteTrack==track then pcall(function() track:Destroy() end); currentEmoteTrack=nil; restoreAnimateScript() end end)
        task.delay(1.5,function() if currentEmoteTrack==track and track.Length==0 then notify("Dance","⚠️ Emote gak valid atau belum owned."); pcall(function() track:Stop(); track:Destroy() end); currentEmoteTrack=nil; restoreAnimateScript() end end)
    else notify("Dance","Gagal load emote ID: "..tostring(emoteId)); restoreAnimateScript() end
end
local animSpeedVal=1
local function playAnimById(animId,speed)
    stopAllDanceAnims(); local hum=getHum(); if not hum then notify("Dance","No character found") return end
    killAllCharacterAnims(); disableAnimateScript()
    local animator=hum:FindFirstChildOfClass("Animator"); if not animator then animator=Instance.new("Animator",hum) end
    local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://"..tostring(animId)
    local ok,track=pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority=Enum.AnimationPriority.Action4; track.Looped=loopAnimEnabled; track:AdjustSpeed(speed or 1); track:Play(0); currentAnimTrack=track
        notify("Animation","Playing: "..tostring(animId).." (speed: "..tostring(speed or 1)..")")
        track.Stopped:Connect(function() if currentAnimTrack==track then pcall(function() track:Destroy() end); currentAnimTrack=nil; restoreAnimateScript() end end)
    else notify("Animation","Failed to load: "..tostring(animId)); restoreAnimateScript() end
end
addLabel(dPage,"-- PRESET DANCES")
local presetDances={{name="Default Dance",id=507771019},{name="Floss",id=5917459365},{name="Trip Out",id=75483681450871},{name="Rat Dance",id=94083401455021}}
for _,dance in ipairs(presetDances) do addButton(dPage,dance.name,function() playEmoteById(dance.id) end) end
addLabel(dPage,"-- PLAYBACK CONTROLS")
addToggle(dPage,"Loop Animation",false,function(on) loopAnimEnabled=on; if not on then stopAllDanceAnims(); notify("Dance","Loop off") else if currentAnimTrack then currentAnimTrack.Looped=true end; if currentEmoteTrack then currentEmoteTrack.Looped=true end end end)
addButton(dPage,"[X] Stop Dance / Animation",function() stopAllDanceAnims(); notify("Dance","All animations stopped") end)
addButton(dPage,"[X] Stop ALL + Reset Anims",function()
    if currentEmoteTrack then pcall(function() currentEmoteTrack:Stop(0); currentEmoteTrack:Destroy() end); currentEmoteTrack=nil end
    if currentAnimTrack then pcall(function() currentAnimTrack:Stop(0); currentAnimTrack:Destroy() end); currentAnimTrack=nil end
    restoreAnimateScript(); notify("Dance","All character animations cleared")
end)
addLabel(dPage,"-- CUSTOM EMOTE (by ID)")
addInput(dPage,"Enter Emote ID (e.g. 507771019)",function(text) if text=="" then return end; local id=tonumber(text); if id then playEmoteById(id) else notify("Dance","Invalid ID!") end end)
addLabel(dPage,"-- CUSTOM ANIMATION (by ID)")
addInput(dPage,"Enter Animation ID",function(text) if text=="" then return end; local id=tonumber(text); if id then playAnimById(id,animSpeedVal) else notify("Animation","Invalid ID!") end end)
addSlider(dPage,"Animation Speed",1,30,10,function(v) animSpeedVal=v/10; if currentAnimTrack then pcall(function() currentAnimTrack:AdjustSpeed(animSpeedVal) end) end; if currentEmoteTrack then pcall(function() currentEmoteTrack:AdjustSpeed(animSpeedVal) end) end end)

addLabel(dPage,"-- SIMPAN PRESET DANCE")
-- Saved custom dance presets (disimpan di session)
local savedDancePresets={}
local savedPresetContainer=Instance.new("Frame",dPage); savedPresetContainer.Size=UDim2.new(1,0,0,0)
savedPresetContainer.BackgroundTransparency=1; savedPresetContainer.AutomaticSize=Enum.AutomaticSize.Y
local savedPresetLayout=Instance.new("UIListLayout",savedPresetContainer); savedPresetLayout.Padding=UDim.new(0,4)
local function renderSavedPresets()
    for _,c in savedPresetContainer:GetChildren() do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
    if #savedDancePresets==0 then
        local empty=Instance.new("TextLabel",savedPresetContainer); empty.Name="EmptyLbl"
        empty.Size=UDim2.new(1,0,0,26); empty.BackgroundTransparency=1
        empty.Text="Belum ada preset tersimpan."; empty.TextColor3=C.textDim; empty.Font=Enum.Font.GothamMedium; empty.TextSize=11
        return
    end
    for idx,preset in ipairs(savedDancePresets) do
        local row=Instance.new("Frame",savedPresetContainer); row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=C.card; row.BorderSizePixel=0; addCorner(row,8)
        local nameLbl=Instance.new("TextLabel",row); nameLbl.Size=UDim2.new(1,-118,1,0); nameLbl.Position=UDim2.new(0,10,0,0)
        nameLbl.BackgroundTransparency=1; nameLbl.Text=preset.name.." ("..preset.id..")";
        nameLbl.TextColor3=C.text; nameLbl.Font=Enum.Font.GothamMedium; nameLbl.TextSize=11; nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
        local playBtn=Instance.new("TextButton",row); playBtn.Size=UDim2.new(0,48,0,26); playBtn.Position=UDim2.new(1,-108,0.5,-13)
        playBtn.BackgroundColor3=C.accent; playBtn.BorderSizePixel=0; playBtn.Text="▶"; playBtn.TextColor3=C.text; playBtn.Font=Enum.Font.GothamBold; playBtn.TextSize=12; addCorner(playBtn,6)
        playBtn.MouseEnter:Connect(function() tween(playBtn,{BackgroundTransparency=0.2},0.1) end)
        playBtn.MouseLeave:Connect(function() tween(playBtn,{BackgroundTransparency=0},0.1) end)
        local delBtn=Instance.new("TextButton",row); delBtn.Size=UDim2.new(0,48,0,26); delBtn.Position=UDim2.new(1,-56,0.5,-13)
        delBtn.BackgroundColor3=C.red; delBtn.BorderSizePixel=0; delBtn.Text="🗑"; delBtn.TextColor3=C.text; delBtn.Font=Enum.Font.GothamBold; delBtn.TextSize=12; addCorner(delBtn,6)
        delBtn.MouseEnter:Connect(function() tween(delBtn,{BackgroundTransparency=0.2},0.1) end)
        delBtn.MouseLeave:Connect(function() tween(delBtn,{BackgroundTransparency=0},0.1) end)
        local capturedPreset=preset; local capturedIdx=idx
        playBtn.MouseButton1Click:Connect(function()
            if capturedPreset.type=="emote" then playEmoteById(capturedPreset.id)
            else playAnimById(capturedPreset.id,animSpeedVal) end
            notify("Dance","▶ "..capturedPreset.name)
        end)
        delBtn.MouseButton1Click:Connect(function()
            table.remove(savedDancePresets,capturedIdx); renderSavedPresets()
            notify("Dance","🗑 Preset dihapus: "..capturedPreset.name)
        end)
    end
end
renderSavedPresets()
-- Form tambah preset baru
local savePresetNameHolder=Instance.new("Frame",dPage); savePresetNameHolder.Size=UDim2.new(1,0,0,36)
savePresetNameHolder.BackgroundColor3=C.card; savePresetNameHolder.BorderSizePixel=0; addCorner(savePresetNameHolder,8)
local savePresetNameBox=Instance.new("TextBox",savePresetNameHolder); savePresetNameBox.Size=UDim2.new(1,-12,1,0); savePresetNameBox.Position=UDim2.new(0,8,0,0)
savePresetNameBox.BackgroundTransparency=1; savePresetNameBox.PlaceholderText="Nama preset (e.g. Floss Saya)";
savePresetNameBox.PlaceholderColor3=C.textDim; savePresetNameBox.Text=""; savePresetNameBox.TextColor3=C.text
savePresetNameBox.Font=Enum.Font.GothamMedium; savePresetNameBox.TextSize=12; savePresetNameBox.ClearTextOnFocus=false
local savePresetIdHolder=Instance.new("Frame",dPage); savePresetIdHolder.Size=UDim2.new(1,0,0,36)
savePresetIdHolder.BackgroundColor3=C.card; savePresetIdHolder.BorderSizePixel=0; addCorner(savePresetIdHolder,8)
local savePresetIdBox=Instance.new("TextBox",savePresetIdHolder); savePresetIdBox.Size=UDim2.new(1,-12,1,0); savePresetIdBox.Position=UDim2.new(0,8,0,0)
savePresetIdBox.BackgroundTransparency=1; savePresetIdBox.PlaceholderText="Animation/Emote ID (angka)"
savePresetIdBox.PlaceholderColor3=C.textDim; savePresetIdBox.Text=""; savePresetIdBox.TextColor3=C.text
savePresetIdBox.Font=Enum.Font.GothamMedium; savePresetIdBox.TextSize=12; savePresetIdBox.ClearTextOnFocus=false
local savePresetBtnRow=Instance.new("Frame",dPage); savePresetBtnRow.Size=UDim2.new(1,0,0,34)
savePresetBtnRow.BackgroundTransparency=1; savePresetBtnRow.BorderSizePixel=0
local saveEmotePresetBtn=Instance.new("TextButton",savePresetBtnRow); saveEmotePresetBtn.Size=UDim2.new(0.5,-3,1,0); saveEmotePresetBtn.Position=UDim2.new(0,0,0,0)
saveEmotePresetBtn.BackgroundColor3=C.accent; saveEmotePresetBtn.BorderSizePixel=0
saveEmotePresetBtn.Text="+ Simpan sbg Emote"; saveEmotePresetBtn.TextColor3=C.text; saveEmotePresetBtn.Font=Enum.Font.GothamBold; saveEmotePresetBtn.TextSize=11; addCorner(saveEmotePresetBtn,7)
saveEmotePresetBtn.MouseEnter:Connect(function() tween(saveEmotePresetBtn,{BackgroundTransparency=0.2},0.1) end)
saveEmotePresetBtn.MouseLeave:Connect(function() tween(saveEmotePresetBtn,{BackgroundTransparency=0},0.1) end)
local saveAnimPresetBtn=Instance.new("TextButton",savePresetBtnRow); saveAnimPresetBtn.Size=UDim2.new(0.5,-3,1,0); saveAnimPresetBtn.Position=UDim2.new(0.5,3,0,0)
saveAnimPresetBtn.BackgroundColor3=C.green; saveAnimPresetBtn.BorderSizePixel=0
saveAnimPresetBtn.Text="+ Simpan sbg Anim"; saveAnimPresetBtn.TextColor3=C.text; saveAnimPresetBtn.Font=Enum.Font.GothamBold; saveAnimPresetBtn.TextSize=11; addCorner(saveAnimPresetBtn,7)
saveAnimPresetBtn.MouseEnter:Connect(function() tween(saveAnimPresetBtn,{BackgroundTransparency=0.2},0.1) end)
saveAnimPresetBtn.MouseLeave:Connect(function() tween(saveAnimPresetBtn,{BackgroundTransparency=0},0.1) end)
local function doSavePreset(ptype)
    local name=savePresetNameBox.Text; local idStr=savePresetIdBox.Text
    if name=="" then notify("Dance","Isi nama preset dulu!"); return end
    local id=tonumber(idStr); if not id then notify("Dance","ID tidak valid!"); return end
    table.insert(savedDancePresets,{name=name,id=id,type=ptype})
    renderSavedPresets(); savePresetNameBox.Text=""; savePresetIdBox.Text=""
    notify("Dance","✅ Preset disimpan: "..name)
end
saveEmotePresetBtn.MouseButton1Click:Connect(function() doSavePreset("emote") end)
saveAnimPresetBtn.MouseButton1Click:Connect(function() doSavePreset("anim") end)
addLabel(dPage,"-- REPLACE CHARACTER ANIMS")
local savedOriginalAnims={}
local function replaceCharAnim(animType,newId)
    local char=Player.Character; if not char then notify("Anim","No character") return end
    local animateScript=char:FindFirstChild("Animate"); if not animateScript then notify("Anim","No Animate script found") return end
    local folder=animateScript:FindFirstChild(animType); if not folder then notify("Anim","No folder: "..animType) return end
    if not savedOriginalAnims[animType] then savedOriginalAnims[animType]={}; for _,child in ipairs(folder:GetChildren()) do if child:IsA("Animation") then savedOriginalAnims[animType][child.Name]=child.AnimationId end end end
    local changed=0; for _,child in ipairs(folder:GetChildren()) do if child:IsA("Animation") then child.AnimationId="rbxassetid://"..tostring(newId); changed=changed+1 end end
    if changed>0 then notify("Anim",animType.." -> "..tostring(newId).." ("..changed.." updated)") else notify("Anim","No animations found in "..animType) end
end
local animTypes={{label="Idle",key="idle"},{label="Walk",key="walk"},{label="Run",key="run"},{label="Jump",key="jump"},{label="Fall",key="fall"},{label="Climb",key="climb"},{label="Swim",key="swim"}}
for _,at in ipairs(animTypes) do addInput(dPage,at.label.." Animation ID",function(text) if text=="" then return end; local id=tonumber(text); if id then replaceCharAnim(at.key,id) else notify("Anim","Invalid ID!") end end) end
addLabel(dPage,"-- ANIMATION PACKS")
local vampireAnims={{label="Vampire Idle",key="idle",id1=1083445855,id2=1083450166},{label="Vampire Walk",key="walk",id=1083473930},{label="Vampire Run",key="run",id=1083462077},{label="Vampire Jump",key="jump",id=1083455352},{label="Vampire Fall",key="fall",id=1083443587},{label="Vampire Climb",key="climb",id=1083439238},{label="Vampire Swim",key="swim",id=1083443587}}
local function replaceIdleAnim(id1,id2)
    local char=Player.Character; if not char then notify("Anim","No character") return end
    local animateScript=char:FindFirstChild("Animate"); if not animateScript then notify("Anim","No Animate script") return end
    local idleFolder=animateScript:FindFirstChild("idle"); if not idleFolder then notify("Anim","No idle folder") return end
    if not savedOriginalAnims["idle"] then savedOriginalAnims["idle"]={}; for _,child in ipairs(idleFolder:GetChildren()) do if child:IsA("Animation") then savedOriginalAnims["idle"][child.Name]=child.AnimationId end end end
    local a1=idleFolder:FindFirstChild("Animation1"); local a2=idleFolder:FindFirstChild("Animation2")
    if a1 then a1.AnimationId="rbxassetid://"..tostring(id1) end; if a2 then a2.AnimationId="rbxassetid://"..tostring(id2) end
    notify("Anim","Vampire Idle applied!")
end
for _,va in ipairs(vampireAnims) do if va.key=="idle" then addButton(dPage,va.label,function() replaceIdleAnim(va.id1,va.id2) end) else addButton(dPage,va.label,function() replaceCharAnim(va.key,va.id) end) end end
addButton(dPage,"[!] Apply ALL Vampire Anims",function() replaceIdleAnim(1083445855,1083450166); replaceCharAnim("walk",1083473930); replaceCharAnim("run",1083462077); replaceCharAnim("jump",1083455352); replaceCharAnim("fall",1083443587); replaceCharAnim("climb",1083439238); replaceCharAnim("swim",1083443587); notify("Anim Pack","Vampire Animation Pack applied! 🧛") end)
addLabel(dPage,"-- WEREWOLF PACK (Bonus)")
local werewolfAnims={{label="Werewolf Idle",key="idle",id=1113752682},{label="Werewolf Walk",key="walk",id=1113751657},{label="Werewolf Run",key="run",id=1113750642},{label="Werewolf Jump",key="jump",id=1113752285},{label="Werewolf Fall",key="fall",id=1113751889},{label="Werewolf Climb",key="climb",id=1113754738},{label="Werewolf Swim",key="swim",id=1113752975}}
for _,wa in ipairs(werewolfAnims) do addButton(dPage,wa.label,function() replaceCharAnim(wa.key,wa.id) end) end
addButton(dPage,"[!] Apply ALL Werewolf Anims",function() for _,wa in ipairs(werewolfAnims) do replaceCharAnim(wa.key,wa.id) end; notify("Anim Pack","Werewolf Animation Pack applied! 🐺") end)
addButton(dPage,"[*] Reset All Anims to Default",function()
    local char=Player.Character; if char then local animateScript=char:FindFirstChild("Animate"); if animateScript then for animType,originals in pairs(savedOriginalAnims) do local folder=animateScript:FindFirstChild(animType); if folder then for _,child in ipairs(folder:GetChildren()) do if child:IsA("Animation") and originals[child.Name] then child.AnimationId=originals[child.Name] end end end end end end
    savedOriginalAnims={}; notify("Anim","All animations reset to default!")
end)
end -- end Dance tab scope

-- ═══════════════ FARM TAB ═══════════════
do
local farmPage=Pages["Farm"]
addLabel(farmPage,"AUTO COLLECT COIN")
local autoCollectRunning=false; local collectDelay=1
local GOLD_ZONES={Vector3.new(442,125,-203),Vector3.new(214,125,3),Vector3.new(-52,101,-56),Vector3.new(-253,137,-286),Vector3.new(-186,114,-649),Vector3.new(-31,153,-851),Vector3.new(383,125,-737),Vector3.new(301,96,-349),Vector3.new(-47,59,-474),Vector3.new(-129,103,-15),Vector3.new(-40,100,83),Vector3.new(405,127,20),Vector3.new(-202,76,-371),Vector3.new(-204,121,-185),Vector3.new(-310,138,-93),Vector3.new(591,146,-418),Vector3.new(63,155,-819)}
local function findCoins()
    local coins={}
    local goldSpawns=workspace:FindFirstChild("GoldSpawns")
    if goldSpawns then for _,v in ipairs(goldSpawns:GetDescendants()) do if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then if v:GetAttribute("IsCollected")==false then table.insert(coins,v) end end end end
    local assetnew=workspace:FindFirstChild("assetnew")
    if assetnew then for _,v in ipairs(assetnew:GetDescendants()) do if v:IsA("Part") or v:IsA("MeshPart") then if v:GetAttribute("IsCollected")==false then table.insert(coins,v) end end end end
    if #coins==0 then for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("Part") or v:IsA("MeshPart") then if v:GetAttribute("IsCollected")==false then table.insert(coins,v) end end end end
    return coins
end
local collectStatusLabel=Instance.new("TextLabel"); collectStatusLabel.Size=UDim2.new(1,-16,0,22); collectStatusLabel.BackgroundTransparency=1
collectStatusLabel.TextColor3=Color3.fromRGB(255,200,50); collectStatusLabel.Font=Enum.Font.GothamBold; collectStatusLabel.TextSize=11
collectStatusLabel.Text="Status: OFF | Coin ditemukan: 0"; collectStatusLabel.TextXAlignment=Enum.TextXAlignment.Left; collectStatusLabel.Parent=farmPage
addToggle(farmPage,"Auto Collect Coin",false,function(on)
    autoCollectRunning=on
    if on then
        task.spawn(function()
            while autoCollectRunning do
                local char=Players.LocalPlayer.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
                if not (hrp and hum and hum.Health>0) then collectStatusLabel.Text="Nunggu karakter... ⏳"; task.wait(1); continue end
                local coins=findCoins(); collectStatusLabel.Text="Coin aktif: "..#coins.." 🟢 Collecting..."
                if #coins==0 then collectStatusLabel.Text="Nunggu coin spawn... ⏳"; task.wait(2); continue end
                local originalCFrame=hrp.CFrame
                for _,coin in ipairs(coins) do
                    if not autoCollectRunning then break end; if not coin or not coin.Parent then continue end
                    hrp=char and char:FindFirstChild("HumanoidRootPart"); hum=char and char:FindFirstChildOfClass("Humanoid"); if not hrp or not hum then break end
                    local coinPos=coin.Position
                    hrp.CFrame=CFrame.new(coinPos+Vector3.new(0,5,0)); task.wait(0.05)
                    hrp.CFrame=CFrame.new(coinPos+Vector3.new(0,3,0)); task.wait(0.05)
                    hrp.CFrame=CFrame.new(coinPos+Vector3.new(0,1,0)); task.wait(0.05)
                    hrp.CFrame=CFrame.new(coinPos); task.wait(0.05)
                    hrp.CFrame=CFrame.new(coinPos+Vector3.new(0,-1,0)); task.wait(0.05)
                    hrp.CFrame=CFrame.new(coinPos); hum.Jump=true; task.wait(collectDelay)
                end
                hrp=char and char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame=originalCFrame end; task.wait(0.5)
            end
            collectStatusLabel.Text="Status: OFF | Coin ditemukan: 0"
        end)
    else collectStatusLabel.Text="Status: OFF | Coin ditemukan: 0" end
end)
addSlider(farmPage,"Delay Per Coin (detik)",1,4,1,function(val) collectDelay=val end)
addLabel(farmPage,"TELEPORT KE GOLD ZONE")
for i,zPos in ipairs(GOLD_ZONES) do addButton(farmPage,"→ Gold Zone "..i,function() local char=Players.LocalPlayer.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame=CFrame.new(zPos+Vector3.new(0,4,0)); notify("Farm","Teleport ke Gold Zone "..i) end end) end

end -- end Farm tab scope

-- ═══════════════ MISC TAB ═══════════════
do
local miscPage=Pages["Misc"]
addLabel(miscPage,"ANTI STAFF")
local STAFF_GROUP_ID=564796604; local antiStaffRunning=false; local customStaffNames={}; local antiStaffConnection=nil
local staffStatusLabel=Instance.new("TextLabel"); staffStatusLabel.Size=UDim2.new(1,-16,0,22); staffStatusLabel.BackgroundTransparency=1
staffStatusLabel.TextColor3=Color3.fromRGB(100,220,100); staffStatusLabel.Font=Enum.Font.GothamBold; staffStatusLabel.TextSize=11
staffStatusLabel.Text="Anti Staff: OFF"; staffStatusLabel.TextXAlignment=Enum.TextXAlignment.Left; staffStatusLabel.Parent=miscPage
local function isStaff(player)
    if player==Players.LocalPlayer then return false end
    for _,name in ipairs(customStaffNames) do if player.Name:lower()==name:lower() then return true end end
    local ok,result=pcall(function() return player:IsInGroup(STAFF_GROUP_ID) end); if ok and result then return true end; return false
end
local function doRejoin() notify("⚠️ Anti Staff","Staff terdeteksi! Pindah server..."); task.wait(1.5); _TeleportSvc:Teleport(game.PlaceId,Players.LocalPlayer) end
addToggle(miscPage,"Anti Staff (Auto Rejoin)",false,function(on)
    antiStaffRunning=on; if antiStaffConnection then antiStaffConnection:Disconnect(); antiStaffConnection=nil end
    staffStatusLabel.Text=on and "Anti Staff: ON 🟢 Monitoring..." or "Anti Staff: OFF"
    if on then
        for _,p in ipairs(Players:GetPlayers()) do if isStaff(p) then staffStatusLabel.Text="⚠️ STAFF DETECTED: "..p.Name; doRejoin(); return end end
        antiStaffConnection=Players.PlayerAdded:Connect(function(p) if not antiStaffRunning then return end; task.wait(2); if isStaff(p) then staffStatusLabel.Text="⚠️ STAFF JOIN: "..p.Name; doRejoin() end end)
    end
end)
addInput(miscPage,"Tambah username staff...",function(text) if text=="" then return end; table.insert(customStaffNames,text); notify("Anti Staff","Ditambahkan: "..text); staffStatusLabel.Text="Custom staff list: "..#customStaffNames.." username" end)
addLabel(miscPage,"ANTI FEATURES")
addToggle(miscPage,"Anti AFK",true,function(on)
    States.AntiAFK=on
    if on then Connections.antiafk=Players.LocalPlayer.Idled:Connect(function() _VirtualUser:Button2Down(Vector2.new(0,0),Workspace.CurrentCamera.CFrame); task.wait(1); _VirtualUser:Button2Up(Vector2.new(0,0),Workspace.CurrentCamera.CFrame) end); notify("Anti AFK","Enabled")
    else if Connections.antiafk then Connections.antiafk:Disconnect() end; notify("Anti AFK","Disabled") end
end)
do Connections.antiafk=Players.LocalPlayer.Idled:Connect(function() _VirtualUser:Button2Down(Vector2.new(0,0),Workspace.CurrentCamera.CFrame); task.wait(1); _VirtualUser:Button2Up(Vector2.new(0,0),Workspace.CurrentCamera.CFrame) end) end
addButton(miscPage,"Anti Lag (Clean Up)",function()
    local removed=0
    for _,v in Workspace:GetDescendants() do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled=false; removed=removed+1
        elseif v:IsA("Explosion") then v:Destroy(); removed=removed+1
        elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1; removed=removed+1 end
    end
    pcall(function() local terrain=Workspace:FindFirstChildOfClass("Terrain"); if terrain then terrain.WaterWaveSize=0; terrain.WaterWaveSpeed=0; terrain.WaterReflectance=0; terrain.WaterTransparency=0 end end)
    local li=_Lighting; for _,v in li:GetDescendants() do if v:IsA("PostEffect") then v.Enabled=false end end
    li.GlobalShadows=false; li.FogEnd=100000; pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    notify("Anti Lag","Cleaned "..removed.." effects")
end)
addButton(miscPage,"Remove Textures (Smooth)",function()
    local count=0; for _,v in Workspace:GetDescendants() do if v:IsA("BasePart") and not v:IsA("MeshPart") then v.Material=Enum.Material.SmoothPlastic; count=count+1 end end
    notify("Smooth",count.." parts set to SmoothPlastic")
end)
addLabel(miscPage,"UTILITIES")
addButton(miscPage,"Click TP (Click anywhere)",function()
    notify("Click TP","Click anywhere to teleport!"); local conn
    conn=Mouse.Button1Down:Connect(function() local hrp=getHRP(); if hrp and Mouse.Hit then hrp.CFrame=Mouse.Hit+Vector3.new(0,5,0) end; conn:Disconnect() end)
end)
addButton(miscPage,"[E] TP to Mouse (Hold E)",function()
    notify("TP to Mouse","Hold E to teleport to cursor")
    if Connections.mouseTP then Connections.mouseTP:Disconnect() end
    Connections.mouseTP=RunService.RenderStepped:Connect(function() if UIS:IsKeyDown(Enum.KeyCode.E) then local hrp=getHRP(); if hrp and Mouse.Hit then hrp.CFrame=Mouse.Hit+Vector3.new(0,5,0) end end end)
end)
addButton(miscPage,"[C] Copy Game PlaceId",function() if setclipboard or toclipboard then (setclipboard or toclipboard)(tostring(game.PlaceId)); notify("Copied","PlaceId: "..game.PlaceId) end end)
addButton(miscPage,"[!] Kill All (Client-side)",function()
    for _,p in Players:GetPlayers() do if p~=Player and p.Character then local h=p.Character:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.Health=0 end) end end end
    notify("Kill All","Attempted (client-side only)")
end)
addLabel(miscPage,"-- KEYBIND")
local pcModeCard=Instance.new("Frame",miscPage); pcModeCard.Size=UDim2.new(1,0,0,52); pcModeCard.BackgroundColor3=C.card; pcModeCard.BorderSizePixel=0; addCorner(pcModeCard,8); addStroke(pcModeCard,C.border,1)
local pcModeTop=Instance.new("TextLabel",pcModeCard); pcModeTop.Size=UDim2.new(1,-60,0,20); pcModeTop.Position=UDim2.new(0,12,0,4); pcModeTop.BackgroundTransparency=1; pcModeTop.Text="PC Mode  (disable tombol P)"; pcModeTop.TextColor3=C.text; pcModeTop.Font=Enum.Font.GothamBold; pcModeTop.TextSize=12; pcModeTop.TextXAlignment=Enum.TextXAlignment.Left
local pcModeSub=Instance.new("TextLabel",pcModeCard); pcModeSub.Size=UDim2.new(1,-60,0,16); pcModeSub.Position=UDim2.new(0,12,0,24); pcModeSub.BackgroundTransparency=1; pcModeSub.Text="Sembunyikan floating P button saat minimize"; pcModeSub.TextColor3=C.textDim; pcModeSub.Font=Enum.Font.GothamMedium; pcModeSub.TextSize=10; pcModeSub.TextXAlignment=Enum.TextXAlignment.Left
local pcTogBg=Instance.new("Frame",pcModeCard); pcTogBg.Size=UDim2.new(0,40,0,20); pcTogBg.Position=UDim2.new(1,-52,0.5,-10); pcTogBg.BackgroundColor3=C.green; pcTogBg.BorderSizePixel=0; addCorner(pcTogBg,10)
local pcTogCircle=Instance.new("Frame",pcTogBg); pcTogCircle.Size=UDim2.new(0,16,0,16); pcTogCircle.Position=UDim2.new(1,-18,0,2); pcTogCircle.BackgroundColor3=C.text; pcTogCircle.BorderSizePixel=0; addCorner(pcTogCircle,8)
local pcTogBtn=Instance.new("TextButton",pcModeCard); pcTogBtn.Size=UDim2.new(1,0,1,0); pcTogBtn.BackgroundTransparency=1; pcTogBtn.Text=""; pcTogBtn.ZIndex=5
pcTogBtn.MouseButton1Click:Connect(function()
    pcModeEnabled=not pcModeEnabled
    tween(pcTogBg,{BackgroundColor3=pcModeEnabled and C.green or C.toggleOff},0.2)
    tween(pcTogCircle,{Position=pcModeEnabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},0.2)
    if pcModeEnabled then MiniBtn.Visible=false; notify("PC Mode","ON — Tombol P disembunyikan.")
    else notify("PC Mode","OFF — Tombol P aktif kembali saat minimize.") end
end)
local keyBindBtn=addButton(miscPage,"Toggle Key: LeftControl",function() end); keyBindBtn.TextColor3=C.textDim
addButton(miscPage,"[*] Ganti Toggle Key (tekan key apa aja)",function()
    if isBindingKey then isBindingKey=false; keyBindBtn.Text="Toggle Key: "..tostring(currentToggleKey.Name); notify("Keybind","Batal ganti key")
    else isBindingKey=true; keyBindBtn.Text="Tekan key baru..."; notify("Keybind","Tekan key yang kamu mau buat toggle UI!")
        task.spawn(function() while isBindingKey do task.wait(0.1) end; keyBindBtn.Text="Toggle Key: "..tostring(currentToggleKey.Name) end) end
end)
addButton(miscPage,"[R] Reset ke Default (LeftControl)",function() currentToggleKey=Enum.KeyCode.LeftControl; isBindingKey=false; keyBindBtn.Text="Toggle Key: LeftControl"; notify("Keybind","Reset ke LeftControl") end)
addLabel(miscPage,"-- INFO")
addButton(miscPage,"Game: ".._MarketSvc:GetProductInfo(game.PlaceId).Name,function() end)
addButton(miscPage,"PlaceId: "..game.PlaceId,function() end)
addButton(miscPage,"Player: "..Player.DisplayName.." (@"..Player.Name..")",function() end)

end -- end Misc tab scope

-- ═══════════════ SURVIVE THE APOCALYPSE TAB ═══════════════
-- Map: Survive the Apocalypse (rbxlx analysis)
-- Zombie: Model dgn Script "MobAI" + parts: Head/Torso/Flesh/MainPart
-- Loot: ScrapServer, CrateServer, AmmoCrateServer, BarrelServer
-- Items: Scrap Pile, Tin Can, Beans, Chips, Bloxy Cola, Battery, Bloxiade
-- Pickup part: BasePart bernama "PickUp" di dalam model item
do
local aPage=Pages["Apocalypse"]

-- ── State flags
local sta_killAura      = false
local sta_autoScrap     = false
local sta_autoCrate     = false
local sta_autoAmmo      = false
local sta_autoRevive    = false
local sta_godMode       = false
local sta_fastAtk       = false
local sta_espZombie     = false
local sta_espLoot       = false
local sta_espHighlights = {}
local sta_autoTPScrap   = false
local sta_autoTPCrate   = false
local sta_autoTPZombie  = false
local sta_damage9999    = false
local sta_autoLootBag   = false

-- ── Scan interval — satu slider kontrol semua loop berat
local sta_scanInterval = 0.5

-- ── Helpers
local function sta_getHRP() local c=Player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function sta_getHum() local c=Player.Character; return c and c:FindFirstChildOfClass("Humanoid") end

-- Cache descendants (rebuild tiap 2 detik)
local sta_descCache = {}
local sta_descCacheTime = 0
local function sta_getDescendants()
    local now = tick()
    if now - sta_descCacheTime > 2 then
        sta_descCache = Workspace:GetDescendants()
        sta_descCacheTime = now
    end
    return sta_descCache
end

-- Cek apakah sebuah Model adalah zombie (ada Script bernama MobAI di dalamnya)
local function sta_isZombie(model)
    if not model:IsA("Model") then return false end
    local ai = model:FindFirstChild("MobAI")
    return ai ~= nil and ai:IsA("Script")
end

-- Dapatkan BasePart utama dari model (MainPart → PrimaryPart → FirstBasePart)
local function sta_getModelRoot(model)
    return model:FindFirstChild("MainPart")
        or model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildOfClass("BasePart")
end

-- Cek apakah model adalah loot (ada ScrapServer/CrateServer/AmmoCrateServer/BarrelServer)
local lootScripts = {"ScrapServer","CrateServer","AmmoCrateServer","BarrelServer"}
local function sta_isLoot(model)
    if not model:IsA("Model") then return false end
    for _,sname in ipairs(lootScripts) do
        local s=model:FindFirstChild(sname)
        if s and s:IsA("Script") then return true end
    end
    return false
end

-- Nama item consumable yang bisa di-pickup
local sta_consumables = {"Scrap Pile","Tin Can","Beans","Chips","Bloxy Cola","Battery","Bloxiade","Can","Ammo Crate"}

-- ── PERFORMANCE SLIDER
addLabel(aPage,"-- PERFORMA SCAN")
local perfInfoLbl=Instance.new("TextLabel",aPage)
perfInfoLbl.Size=UDim2.new(1,0,0,24); perfInfoLbl.BackgroundColor3=Color3.fromRGB(20,40,20)
perfInfoLbl.BorderSizePixel=0; addCorner(perfInfoLbl,6)
perfInfoLbl.Text="  Interval kecil = lebih responsif tapi lebih berat"
perfInfoLbl.TextColor3=C.green; perfInfoLbl.Font=Enum.Font.GothamMedium
perfInfoLbl.TextSize=10; perfInfoLbl.TextXAlignment=Enum.TextXAlignment.Left
addSlider(aPage,"Scan Interval (ms)",100,3000,500,function(v) sta_scanInterval=v/1000 end)

-- ══ SURVIVE ══
addLabel(aPage,"-- SURVIVE")

addToggle(aPage,"God Mode (Max HP)",false,function(on)
    sta_godMode=on
    if on then
        task.spawn(function()
            while sta_godMode do
                local h=sta_getHum(); if h then h.MaxHealth=math.huge; h.Health=math.huge end
                task.wait(0.2)
            end
        end)
        notify("Apocalypse","God Mode ON")
    else
        local h=sta_getHum(); if h then h.MaxHealth=100; h.Health=100 end
        notify("Apocalypse","God Mode OFF")
    end
end)

addButton(aPage,"[!] Anti Void (TP ke Spawns)",function()
    local hrp=sta_getHRP(); if not hrp then return end
    -- Game pakai folder "Spawns" berisi spawn points
    local spawnsFolder=Workspace:FindFirstChild("Spawns",true)
    local spawnPart = spawnsFolder and (spawnsFolder:FindFirstChildOfClass("BasePart") or spawnsFolder:FindFirstChildOfClass("Model"))
    if spawnPart then
        local ref = spawnPart:IsA("Model") and sta_getModelRoot(spawnPart) or spawnPart
        if ref then hrp.CFrame=ref.CFrame+Vector3.new(0,6,0); notify("Apocalypse","TP ke Spawn") return end
    end
    hrp.CFrame=CFrame.new(0,100,0); notify("Apocalypse","TP ke 0,100,0")
end)

-- ══ AUTO FARM ══
addLabel(aPage,"-- AUTO FARM")

-- Kill Aura: deteksi zombie lewat Script "MobAI" di dalam model
local sta_killRange = 30
addToggle(aPage,"Kill Aura (Auto Kill Zombie)",false,function(on)
    sta_killAura=on
    if on then
        task.spawn(function()
            while sta_killAura do
                local hrp=sta_getHRP()
                if hrp then
                    for _,v in ipairs(sta_getDescendants()) do
                        if not sta_killAura then break end
                        if v:IsA("Script") and v.Name=="MobAI" and v.Parent then
                            local mob=v.Parent
                            local root=sta_getModelRoot(mob)
                            if root then
                                local d=(hrp.Position-root.Position).Magnitude
                                if d<=sta_killRange then
                                    -- Coba damage lewat MockHumanoid attributes dulu
                                    local mh=mob:FindFirstChild("MockHumanoid")
                                    if mh then pcall(function()
                                        local hp=mh:GetAttribute("Health")
                                        if hp then mh:SetAttribute("Health",0) end
                                    end) end
                                    -- Fallback: aktifkan tool (weapon) ke arah zombie
                                    local tool=Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                                    if tool then
                                        local old=hrp.CFrame
                                        pcall(function()
                                            hrp.CFrame=root.CFrame*CFrame.new(0,0,-3)
                                            hrp.CFrame=CFrame.lookAt(hrp.Position, root.Position)
                                            tool:Activate()
                                        end)
                                        task.wait(0.08)
                                        pcall(function() hrp.CFrame=old end)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Kill Aura ON (range "..sta_killRange..")")
    else notify("Apocalypse","Kill Aura OFF") end
end)
addSlider(aPage,"Kill Aura Range",10,150,30,function(v) sta_killRange=v end)

-- Auto Collect Scrap: model bernama "Scrap Pile" dengan ScrapServer script
addToggle(aPage,"Auto Collect Scrap",false,function(on)
    sta_autoScrap=on
    if on then
        task.spawn(function()
            while sta_autoScrap do
                local hrp=sta_getHRP()
                if hrp then
                    for _,v in ipairs(sta_getDescendants()) do
                        if not sta_autoScrap then break end
                        if v:IsA("Script") and v.Name=="ScrapServer" and v.Parent then
                            local model=v.Parent
                            local root=sta_getModelRoot(model) or model:FindFirstChild("PickUp")
                            if root and root:IsA("BasePart") then
                                local d=(hrp.Position-root.Position).Magnitude
                                if d<60 then
                                    pcall(function() hrp.CFrame=CFrame.new(root.Position+Vector3.new(0,3,0)) end)
                                    task.wait(0.15)
                                end
                            end
                        end
                    end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto Collect Scrap ON")
    else notify("Apocalypse","Auto Collect Scrap OFF") end
end)

-- Auto Loot Crate: model dengan CrateServer / AmmoCrateServer script
addToggle(aPage,"Auto Loot Crate & Ammo",false,function(on)
    sta_autoCrate=on
    if on then
        task.spawn(function()
            local crateScripts={"CrateServer","AmmoCrateServer","BarrelServer"}
            while sta_autoCrate do
                local hrp=sta_getHRP()
                if hrp then
                    for _,v in ipairs(sta_getDescendants()) do
                        if not sta_autoCrate then break end
                        if v:IsA("Script") then
                            local isCrate=false
                            for _,cs in ipairs(crateScripts) do if v.Name==cs then isCrate=true; break end end
                            if isCrate and v.Parent then
                                local model=v.Parent
                                local root=model:FindFirstChild("PickUp") or sta_getModelRoot(model)
                                if root and root:IsA("BasePart") then
                                    local d=(hrp.Position-root.Position).Magnitude
                                    if d<80 then
                                        pcall(function() hrp.CFrame=CFrame.new(root.Position+Vector3.new(0,3,0)) end)
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto Loot Crate ON")
    else notify("Apocalypse","Auto Loot Crate OFF") end
end)

-- Auto Revive: scan player list (ringan)
addToggle(aPage,"Auto Revive Teammate",false,function(on)
    sta_autoRevive=on
    if on then
        task.spawn(function()
            while sta_autoRevive do
                local hrp=sta_getHRP()
                if hrp then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p~=Player and p.Character then
                            local hum=p.Character:FindFirstChildOfClass("Humanoid")
                            local pRoot=p.Character:FindFirstChild("HumanoidRootPart")
                            if hum and pRoot and hum.Health<=0 then
                                local d=(hrp.Position-pRoot.Position).Magnitude
                                if d<8 then
                                    local tool=Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                                    if tool then pcall(function() tool:Activate() end) end
                                else
                                    pcall(function() hrp.CFrame=pRoot.CFrame*CFrame.new(0,0,-3) end)
                                end
                            end
                        end
                    end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto Revive ON")
    else notify("Apocalypse","Auto Revive OFF") end
end)

-- ══ TELEPORT (AUTO-LOOP) ══
addLabel(aPage,"-- TELEPORT (loop terus/panah permanen)")

-- Auto TP Zombie: toggle → terus TP ke zombie terdekat
addToggle(aPage,"→ Auto TP Zombie (Loop)",false,function(on)
    sta_autoTPZombie=on
    if on then
        task.spawn(function()
            while sta_autoTPZombie do
                local hrp=sta_getHRP()
                if hrp then
                    local best,bd=nil,math.huge
                    for _,v in ipairs(sta_getDescendants()) do
                        if v:IsA("Script") and v.Name=="MobAI" and v.Parent then
                            local root=sta_getModelRoot(v.Parent)
                            if root then
                                local d=(hrp.Position-root.Position).Magnitude
                                if d<bd then bd=d; best=root end
                            end
                        end
                    end
                    if best then pcall(function() hrp.CFrame=best.CFrame*CFrame.new(0,4,-3) end) end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto TP Zombie ON")
    else notify("Apocalypse","Auto TP Zombie OFF") end
end)

-- Auto TP Scrap: toggle → terus TP ke scrap pile terdekat
addToggle(aPage,"→ Auto TP Scrap (Loop)",false,function(on)
    sta_autoTPScrap=on
    if on then
        task.spawn(function()
            while sta_autoTPScrap do
                local hrp=sta_getHRP()
                if hrp then
                    local best,bd=nil,math.huge
                    for _,v in ipairs(sta_getDescendants()) do
                        if v:IsA("Script") and v.Name=="ScrapServer" and v.Parent then
                            local root=v.Parent:FindFirstChild("PickUp") or sta_getModelRoot(v.Parent)
                            if root and root:IsA("BasePart") then
                                local d=(hrp.Position-root.Position).Magnitude
                                if d<bd then bd=d; best=root end
                            end
                        end
                    end
                    if best then pcall(function() hrp.CFrame=CFrame.new(best.Position+Vector3.new(0,3,0)) end) end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto TP Scrap ON")
    else notify("Apocalypse","Auto TP Scrap OFF") end
end)

-- Auto TP Crate: toggle → terus TP ke crate/ammo terdekat
addToggle(aPage,"→ Auto TP Crate & Ammo (Loop)",false,function(on)
    sta_autoTPCrate=on
    if on then
        task.spawn(function()
            local crateScripts={"CrateServer","AmmoCrateServer","BarrelServer"}
            while sta_autoTPCrate do
                local hrp=sta_getHRP()
                if hrp then
                    local best,bd=nil,math.huge
                    for _,v in ipairs(sta_getDescendants()) do
                        if v:IsA("Script") and v.Parent then
                            local ok=false
                            for _,cs in ipairs(crateScripts) do if v.Name==cs then ok=true; break end end
                            if ok then
                                local root=v.Parent:FindFirstChild("PickUp") or sta_getModelRoot(v.Parent)
                                if root and root:IsA("BasePart") then
                                    local d=(hrp.Position-root.Position).Magnitude
                                    if d<bd then bd=d; best=root end
                                end
                            end
                        end
                    end
                    if best then pcall(function() hrp.CFrame=CFrame.new(best.Position+Vector3.new(0,3,0)) end) end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto TP Crate ON")
    else notify("Apocalypse","Auto TP Crate OFF") end
end)

-- TP ke PowerPlant (sekali, tombol biasa)
addButton(aPage,"TP → PowerPlant (sekali)",function()
    local hrp=sta_getHRP(); if not hrp then return end
    local pp=Workspace:FindFirstChild("PowerPlant",true)
    if pp then
        local ref=pp:IsA("Model") and sta_getModelRoot(pp) or (pp:IsA("BasePart") and pp or nil)
        if ref then hrp.CFrame=ref.CFrame+Vector3.new(0,6,0); notify("Apocalypse","TP → PowerPlant") return end
    end
    notify("Apocalypse","PowerPlant tidak ditemukan")
end)

-- TP ke HealingPad terdekat (sekali)
addButton(aPage,"TP → Healing Pad (sekali)",function()
    local hrp=sta_getHRP(); if not hrp then return end
    local best,bd=nil,math.huge
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Script") and v.Name=="HealingPadScript" and v.Parent then
            local root=sta_getModelRoot(v.Parent)
            if root and root:IsA("BasePart") then
                local d=(hrp.Position-root.Position).Magnitude
                if d<bd then bd=d; best=root end
            end
        end
    end
    if best then hrp.CFrame=best.CFrame+Vector3.new(0,4,0); notify("Apocalypse","TP → Healing Pad")
    else notify("Apocalypse","Healing Pad tidak ditemukan") end
end)

-- ══ ESP ══
addLabel(aPage,"-- ESP")

local function sta_clearESP()
    for _,h in ipairs(sta_espHighlights) do pcall(function() h:Destroy() end) end
    sta_espHighlights={}
end

-- ESP Zombie: highlight model yang punya script MobAI
addToggle(aPage,"ESP Zombie (MobAI detect)",false,function(on)
    sta_espZombie=on
    if on then
        task.spawn(function()
            while sta_espZombie do
                sta_clearESP()
                for _,v in ipairs(Workspace:GetDescendants()) do
                    if v:IsA("Script") and v.Name=="MobAI" and v.Parent then
                        local mob=v.Parent
                        if not mob:FindFirstChild("_STAZombieHL") then
                            pcall(function()
                                local hl=Instance.new("Highlight",mob)
                                hl.Name="_STAZombieHL"
                                hl.FillColor=Color3.fromRGB(220,50,50)
                                hl.OutlineColor=Color3.fromRGB(255,100,100)
                                hl.FillTransparency=0.5; hl.OutlineTransparency=0
                                table.insert(sta_espHighlights,hl)
                            end)
                        end
                    end
                end
                task.wait(math.max(sta_scanInterval,1))
            end
        end)
        notify("Apocalypse","ESP Zombie ON")
    else
        sta_clearESP()
        notify("Apocalypse","ESP Zombie OFF")
    end
end)

-- ESP Loot: highlight Scrap Pile, Crate, AmmoCrate, Barrel
addToggle(aPage,"ESP Loot (Scrap/Crate/Ammo)",false,function(on)
    sta_espLoot=on
    if on then
        task.spawn(function()
            local lootNames={"ScrapServer","CrateServer","AmmoCrateServer","BarrelServer"}
            while sta_espLoot do
                for _,v in ipairs(Workspace:GetDescendants()) do
                    if v:IsA("Script") and v.Parent then
                        local isLoot=false
                        for _,ln in ipairs(lootNames) do if v.Name==ln then isLoot=true; break end end
                        if isLoot and not v.Parent:FindFirstChild("_STALootHL") then
                            pcall(function()
                                local hl=Instance.new("Highlight",v.Parent)
                                hl.Name="_STALootHL"
                                hl.FillColor=Color3.fromRGB(50,220,100)
                                hl.OutlineColor=Color3.fromRGB(100,255,150)
                                hl.FillTransparency=0.4; hl.OutlineTransparency=0
                                table.insert(sta_espHighlights,hl)
                            end)
                        end
                    end
                end
                task.wait(math.max(sta_scanInterval,2))
            end
        end)
        notify("Apocalypse","ESP Loot ON")
    else
        for _,v in ipairs(Workspace:GetDescendants()) do local h=v:FindFirstChild("_STALootHL"); if h then h:Destroy() end end
        notify("Apocalypse","ESP Loot OFF")
    end
end)

-- ══ UTILITIES ══
addLabel(aPage,"-- UTILITIES")

-- Fast Attack: Heartbeat (intentional — perlu tiap frame)
addToggle(aPage,"Fast Attack (Auto Tool Activate)",false,function(on)
    sta_fastAtk=on
    if Connections.staFastAtk then Connections.staFastAtk:Disconnect(); Connections.staFastAtk=nil end
    if on then
        Connections.staFastAtk=RunService.Heartbeat:Connect(function()
            if not sta_fastAtk then return end
            local tool=Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end)
        notify("Apocalypse","Fast Attack ON")
    else notify("Apocalypse","Fast Attack OFF") end
end)

-- Infinite Stamina: set attribute "Stamina" di Humanoid
addToggle(aPage,"Infinite Stamina",false,function(on)
    if on then
        task.spawn(function()
            while on do
                local hum=sta_getHum()
                if hum then
                    for _,attr in ipairs({"Stamina","stamina","Energy","energy","Sprint","Endurance"}) do
                        pcall(function()
                            if hum:GetAttribute(attr) ~= nil then
                                local maxAttr=hum:GetAttribute(attr.."Max") or hum:GetAttribute("Max"..attr) or 100
                                hum:SetAttribute(attr, maxAttr)
                            end
                        end)
                    end
                end
                task.wait(0.25)
            end
        end)
        notify("Apocalypse","Infinite Stamina ON")
    else notify("Apocalypse","Infinite Stamina OFF") end
end)

-- NoClip: Stepped (hanya karakter sendiri, ringan)
addToggle(aPage,"NoClip",false,function(on)
    if Connections.staNoClip then Connections.staNoClip:Disconnect(); Connections.staNoClip=nil end
    if on then
        Connections.staNoClip=RunService.Stepped:Connect(function()
            local c=Player.Character
            if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        end)
        notify("Apocalypse","NoClip ON")
    else notify("Apocalypse","NoClip OFF") end
end)

-- Damage 9999: set attribute Damage & NumberValue pada tool yang dipakai
-- (client-side: berlaku jika game baca attribute dari tool sebelum fire ke server)
addToggle(aPage,"Damage 9999 (Tool Override)",false,function(on)
    sta_damage9999=on
    if on then
        task.spawn(function()
            while sta_damage9999 do
                local char=Player.Character
                local backpack=Player:FindFirstChildOfClass("Backpack")
                local sources={}
                if char then table.insert(sources,char) end
                if backpack then table.insert(sources,backpack) end
                for _,src in ipairs(sources) do
                    for _,tool in ipairs(src:GetChildren()) do
                        if tool:IsA("Tool") then
                            pcall(function()
                                -- Set attribute langsung di tool
                                for _,aName in ipairs({"Damage","BaseDamage","DamageAmount","AttackDamage"}) do
                                    if tool:GetAttribute(aName) ~= nil then
                                        tool:SetAttribute(aName, 9999)
                                    end
                                end
                                -- Cari Configuration/Stats child
                                for _,child in ipairs(tool:GetDescendants()) do
                                    if child:IsA("Configuration") or child:IsA("Folder") then
                                        for _,aName in ipairs({"Damage","BaseDamage","DamageAmount"}) do
                                            if child:GetAttribute(aName) ~= nil then
                                                child:SetAttribute(aName, 9999)
                                            end
                                        end
                                    end
                                    -- NumberValue / IntValue bernama Damage
                                    if (child:IsA("NumberValue") or child:IsA("IntValue")) then
                                        local ln=child.Name:lower()
                                        if ln=="damage" or ln=="basedamage" or ln=="attackdamage" then
                                            child.Value=9999
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
        notify("Apocalypse","Damage 9999 ON")
    else notify("Apocalypse","Damage 9999 OFF") end
end)

-- Auto Loot (Tas): saat toggle ON & player punya tool 'bag/backpack',
-- otomatis TP ke PickUp part terdekat & tunggu (simulasi pickup)
addToggle(aPage,"Auto Loot (Pakai Tas)",false,function(on)
    sta_autoLootBag=on
    if on then
        task.spawn(function()
            while sta_autoLootBag do
                local hrp=sta_getHRP()
                if hrp then
                    -- Cek apakah player punya tool tipe bag
                    local hasBag=false
                    local char=Player.Character
                    local bp=Player:FindFirstChildOfClass("Backpack")
                    for _,src in ipairs({char,bp}) do
                        if src then
                            for _,t in ipairs(src:GetChildren()) do
                                if t:IsA("Tool") then
                                    local ln=t.Name:lower()
                                    if ln:find("bag",1,true) or ln:find("backpack",1,true) or ln:find("sack",1,true) then
                                        hasBag=true; break
                                    end
                                end
                            end
                        end
                        if hasBag then break end
                    end
                    if hasBag then
                        -- TP ke semua PickUp part dalam jarak 150 studs
                        local descs=sta_getDescendants()
                        for _,v in ipairs(descs) do
                            if not sta_autoLootBag then break end
                            if v:IsA("BasePart") and v.Name=="PickUp" then
                                local d=(hrp.Position-v.Position).Magnitude
                                if d<150 then
                                    pcall(function() hrp.CFrame=CFrame.new(v.Position+Vector3.new(0,2,0)) end)
                                    task.wait(0.2)  -- tunggu game proses pickup
                                end
                            end
                        end
                    else
                        -- Tidak ada tas: ingatkan user
                        notify("Apocalypse","Auto Loot: tidak ada tas di inventory!")
                        task.wait(5)
                    end
                end
                task.wait(sta_scanInterval)
            end
        end)
        notify("Apocalypse","Auto Loot Tas ON")
    else notify("Apocalypse","Auto Loot Tas OFF") end
end)

end -- end Apocalypse tab scope


-- ═══════════════════════════════════════
-- TOGGLE KEY
-- ═══════════════════════════════════════
local toggleKeyDown = false
UIS.InputBegan:Connect(function(input, gpe)
    if isBindingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            currentToggleKey = input.KeyCode; isBindingKey = false
            notify("Keybind", "Toggle key: " .. tostring(input.KeyCode.Name))
        end; return
    end
    if gpe then return end
    if (input.KeyCode == currentToggleKey or input.KeyCode == Enum.KeyCode.Insert) then
        if not toggleKeyDown then
            toggleKeyDown = true
            if minimized then minimized = false; Main.Size = UDim2.new(0,520,0,380); Main.BackgroundTransparency = 0; Main.Visible = true
            else Main.Visible = not Main.Visible end
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == currentToggleKey or input.KeyCode == Enum.KeyCode.Insert then toggleKeyDown = false end
end)

-- ═══════════════════════════════════════
-- INTRO
-- ═══════════════════════════════════════
Main.BackgroundTransparency = 0
Main.Size = UDim2.new(0, 520, 0, 380)
notify("VelxHub v1.5.3", "LeftCtrl = toggle | Fast Hit | Dance Presets | Spectate Search")
