-- UniversalAnimHub / packs.lua (модуль; грузится через Loader.lua)
local Hub = ...
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local AES = game:GetService("AvatarEditorService")
local LocalPlayer = Players.LocalPlayer
local connect = Hub.connect
local Settings = Hub.Config.Settings
local SLOTS = Hub.Config.SLOTS

-- ================= БАЗА ПАКОВ (R15) =================
-- порядок: idle1, idle2, walk, run, jump, climb, fall, swim, swimidle
-- Классические паки сверены с официальной таблицей Roblox (create.roblox.com/docs/animation/using).
local Packs = {}
local function Add(name, removed, i1, i2, walk, run, jump, climb, fall, swim, swimidle, imported)
    local pack = {
        name = name,
        removed = removed,
        imported = imported,
        ids = {
            idle1 = i1, idle2 = i2, walk = walk, run = run, jump = jump,
            climb = climb, fall = fall, swim = swim, swimidle = swimidle,
        },
    }
    table.insert(Packs, pack)
    return pack
end

-- Стандартный пак Roblox (используется для пустых слотов конструктора)
Add("Default", false, "507766388", "507766666", "507777826", "507767714", "507765000", "507765644", "507767968", "507784897", "507785072")

-- Обычные паки
Add("Vampire", false, "1083445855", "1083450166", "1083473930", "1083462077", "1083455352", "1083439238", "1083443587", "1083464683", "1083467779")
Add("Toy", false, "782841498", "782845736", "782843345", "782842708", "782847020", "782843869", "782846423", "782844582", "782845186")
Add("Levitation", false, "616006778", "616008087", "616013216", "616010382", "616008936", "616003713", "616005863", "616011509", "616012453")
Add("Ninja", false, "656117400", "656118341", "656121766", "656118852", "656117878", "656114359", "656115606", "656119721", "656121397")
Add("Cartoony", false, "742637544", "742638445", "742640026", "742638842", "742637942", "742636889", "742637151", "742639220", "742639812")
Add("Zombie", false, "616158929", "616160636", "616168032", "616163682", "616161997", "616156119", "616157476", "616165109", "616166655")
Add("Superhero", false, "616111295", "616113536", "616122287", "616117076", "616115533", "616104706", "616108001", "616119360", "616120861")
Add("Astronaut", false, "891621366", "891633237", "891667138", "891636393", "891627522", "891609353", "891617961", "891639666", "891663592")
Add("Bubbly", false, "910004836", "910009958", "910034870", "910025107", "910016857", "909997997", "910001910", "910028158", "910030921")
Add("Elder", false, "845397899", "845400520", "845403856", "845386501", "845398858", "845392038", "845396048", "845401742", "845403127")
Add("Knight", false, "657595757", "657568135", "657552124", "657564596", "658409194", "658360781", "657600338", "657560551", "657557095")
Add("Mage", false, "707742142", "707855907", "707897309", "707861613", "707853694", "707826056", "707829716", "707876443", "707894699")
Add("Pirate", false, "750781874", "750782770", "750785693", "750783738", "750782230", "750779899", "750780242", "750784579", "750785176")
Add("Robot", false, "616088211", "616089559", "616095330", "616091570", "616090535", "616086039", "616087089", "616092998", "616094091")
Add("Stylish", false, "616136790", "616138447", "616146177", "616140816", "616139451", "616133594", "616134815", "616143378", "616144772")
Add("Werewolf", false, "1083195517", "1083214717", "1083178339", "1083216690", "1083218792", "1083182000", "1083189019", "1083222527", "1083225406")
Add("Rthro", false, "2510197257", "2510196951", "2510202577", "2510198475", "2510197830", "2510192778", "2510195892", "2510199791", "2510201162")
Add("Oldschool", false, "5319828216", "5319831086", "5319847204", "5319844329", "5319841935", "5319816685", "5319839762", "5319850266", "5319852613")

-- Удалённые / платные паки
Add("Bold", true, "16738333868", "16738334710", "16738340646", "16738337225", "16738336650", "16738332169", "16738333171", "16738339158", "16738339817")
Add("Wicked Popular", true, "118832222982049", "76049494037641", "92072849924640", "72301599441680", "104325245285198", "131326830509784", "121152442762481", "99384245425157", "113199603178581")
Add("Sneaky", true, "1132473842", "1132477671", "1132510133", "1132494274", "1132489853", "1132461372", "1132469004", "1132500520", "1132506407")
Add("Confident", true, "1069977950", "1069987858", "1070017263", "1070001516", "1069984524", "1069946257", "1069973677", "1070009914", "1070012133")
Add("Patrol", true, "1149612882", "1150842221", "1151231493", "1150967949", "1150944216", "1148811837", "1148863382", "1151204998", "1151221899")
Add("Cowboy", true, "1014390418", "1014398616", "1014421541", "1014401683", "1014394726", "1014380606", "1014384571", "1014406523", "1014411816")
Add("Princess", true, "941003647", "941013098", "941028902", "941015281", "941008832", "940996062", "941000007", "941018893", "941025398")
Add("Popstar", true, "1212900985", "1212954651", "1212980338", "1212980348", "1212954642", "1213044953", "1212900995", "1212852603", "1212998578")
Add("Catwalk Glam", true, "133806214992291", "94970088341563", "109168724482748", "81024476153754", "116936326516985", "119377220967554", "92294537340807", "134591743181628", "98854111361360")
Add("Adidas Sports", true, "18537376492", "18537371272", "18537392113", "18537384940", "18537380791", "18537363391", "18537367238", "18537389531", "18537387180")
Add("NFL", true, "92080889861410", "74451233229259", "110358958299415", "117333533048078", "119846112151352", "134630013742019", "129773241321032", "132697394189921", "79090109939093")

-- Паки, импортированные из онлайн-каталога (сохраняются в файл настроек)
for name, ids in pairs(Settings.Imported) do
    if type(ids) == "table" and ids.walk then
        Add(name, true, ids.idle1, ids.idle2, ids.walk, ids.run, ids.jump, ids.climb, ids.fall, ids.swim, ids.swimidle, true)
    end
end

table.sort(Packs, function(a, b) return a.name < b.name end)

local function findPack(name)
    if not name then return nil end
    for _, p in ipairs(Packs) do
        if p.name == name then return p end
    end
end

-- применяем ранее найденные исправления перепутанных анимаций
for name, ids in pairs(Settings.Fixes) do
    local p = findPack(name)
    if p and type(ids) == "table" then p.ids = ids end
end

-- миграция со старой версии (Selected -> Slots)
if Settings.Selected and next(Settings.Slots) == nil and findPack(Settings.Selected) then
    for _, s in ipairs(SLOTS) do Settings.Slots[s.key] = Settings.Selected end
end
Settings.Selected = nil

local function hasCustom()
    return next(Settings.Slots) ~= nil
end

local function currentSelected()
    local name
    for _, s in ipairs(SLOTS) do
        local v = Settings.Slots[s.key]
        if not v then return nil end
        if name and name ~= v then return nil end
        name = v
    end
    return name
end

local function buildIds()
    local ids = {}
    local def = findPack("Default")
    for _, s in ipairs(SLOTS) do
        local pack = findPack(Settings.Slots[s.key]) or def
        if s.key == "idle" then
            ids.idle1, ids.idle2 = pack.ids.idle1, pack.ids.idle2
        elseif s.key == "swim" then
            ids.swim, ids.swimidle = pack.ids.swim, pack.ids.swimidle
        else
            ids[s.key] = pack.ids[s.key]
        end
    end
    return ids
end

return { list = Packs, Add = Add, find = findPack, hasCustom = hasCustom, currentSelected = currentSelected, buildIds = buildIds }
