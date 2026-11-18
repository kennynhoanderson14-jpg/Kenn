--// KENNEX LOADER
--// cola as URLs raw no array URLS (a ordem = prioridade)
local URLS={
"https://raw.githubusercontent.com/SEUUSER/SEUREPO/main/kenn.lua",
"https://pastebin.com/raw/TROQUE_AQUI",
}
local NAME="kenn"
local DIR="Kennex"
local CACHE=DIR.."/"..NAME..".lua"
local C={dim=Color3.fromRGB(150,140,175),txt=Color3.fromRGB(240,238,250),ok=Color3.fromRGB(74,222,128),err=Color3.fromRGB(248,113,113),bg=Color3.fromRGB(16,11,26),ac=Color3.fromRGB(139,92,246)}

local function mk(c,p)local o=Instance.new(c)for k,v in pairs(p)do pcall(function()o[k]=v end)end return o end
local function toast(txt,col)
pcall(function()
local g=mk("ScreenGui",{Name="KNXLoader",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1000000})
if not pcall(function()g.Parent=game:GetService("CoreGui")end)then g.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")end
local f=mk("Frame",{Size=UDim2.fromOffset(260,26),Position=UDim2.new(0.5,-130,1,-64),BackgroundColor3=C.bg,BorderSizePixel=0})
f.Parent=g
mk("UICorner",{CornerRadius=UDim.new(0,13)},f).Parent=f
mk("UIStroke",{Color=C.ac,Thickness=1,Transparency=0.4},f).Parent=f
local l=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=txt,Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=col or C.txt})
l.Parent=f
task.delay(2.2,function()pcall(function()g:Destroy()end)end)
end)
end

local function get(u)
local ok,r=pcall(function()return game:HttpGet(u,true)end)
if ok and type(r)=="string" and #r>400 then return r end
ok,r=pcall(function()return game:HttpGet(u)end)
if ok and type(r)=="string" and #r>400 then return r end
return nil
end

local function valid(s)
if type(s)~="string" or #s<400 then return false end
if s:sub(1,9):lower():find("<!doctype")then return false end
if s:find("<html",1,true)and#s<2000 then return false end
return s:find("KNX",1,true)~=nil or s:find("LocalPlayer",1,true)~=nil
end

local function cacheOn()return type(writefile)=="function"and type(readfile)=="function"end
local function cacheDir()
if not cacheOn()or type(makefolder)~="function"then return end
if type(isfolder)=="function"and not isfolder(DIR)then pcall(makefolder,DIR)end
end

local body,src
for i,u in ipairs(URLS)do
toast(("baixando %d/%d"):format(i,#URLS),C.dim)
local r=get(u)
if valid(r)then body=r src=u break end
end

if not body then
if cacheOn()and type(isfile)=="function"and isfile(CACHE)then
local ok,r=pcall(readfile,CACHE)
if ok and valid(r)then
body=r src="cache local"
toast("hosts fora · usando cache",C.err)
end
end
end

if not body then toast("falha no download",C.err)return end

if src~="cache local"and cacheOn()then
cacheDir()
pcall(writefile,CACHE,body)
end

local fn,err=loadstring(body,"=kenn")
if not fn then
toast("erro de sintaxe no arquivo",C.err)
warn("[KNX] "..tostring(err))
return end
pcall(setfenv,fn,getgenv()or _G)

toast("kenn carregado",C.ok)
local ok,e=pcall(fn)
if not ok then
toast("erro ao executar",C.err)
warn("[KNX] "..tostring(e))
end
