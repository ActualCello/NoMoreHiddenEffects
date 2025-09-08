// No more hidden Effects: Finds all Effect items/blocks on a map and displays them

[Setting category="General" name="Show Block/Item Names" description="If you are experiencing lag, turn this off or reduce font size"] bool showNames = true;
[Setting category="General" name="Show Item Turbos/Reactors"] bool showBoosterItems = true;
[Setting category="General" name="Show Block Turbos/Reactors"] bool showBoosterBlocks = true;
[Setting category="General" name="Show Effect Blocks"] bool showEffectBlocks = true;
[Setting category="General" name="Show Car Switches"] bool showCarSwitches = true;
[Setting category="General" name="Dot Size" min=8 max=48] float dotSize = 8;
[Setting category="General" name="Font Size" min=10 max=32] float fontSize = 15;

array<vec3> effectPositions;
array<string> effectNames;
string MapUid = "";
string slowMoName = "";
int nextScanFrame = 1200;
bool mapChanged = false;

void Main() {
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    if (Math::Rand(0, 99) == 0){
        slowMoName = "Riolu";
    } else {
        slowMoName = "Slow-Motion";
    }

    RunScan();
    while (true) {
        sleep(nextScanFrame);
        DetectMapChange(app, network);
    }
}

void DetectMapChange(CTrackMania& app, CTrackManiaNetwork& network) {
    if (app.RootMap is null) {
        ClearBoosters();
        nextScanFrame = 1200;
        return;
    }
    if (MapUid != app.RootMap.MapInfo.MapUid) {
        MapUid = app.RootMap.MapInfo.MapUid;
        mapChanged = true;
        RunScan();
    }
    if (!mapChanged) {
        RunScan();
        nextScanFrame = 1200;
        return;
    }
    auto playground = cast<CGameManiaAppPlayground>(network.ClientManiaAppPlayground);
    if (playground is null || !playground.Playground.IsServerOrSolo) {
        nextScanFrame = 5000;
        return;
    }
}

void RunScan() {
    print("Scanning for boosters...");
    auto app = cast<CGameCtnApp>(GetApp());
    if (app is null || app.CurrentPlayground is null) { ClearBoosters(); MapUid = ""; return; }
    if (app.RootMap is null) { ClearBoosters(); MapUid = ""; return; }
    auto playground = cast<CGamePlayground>(app.CurrentPlayground);
    if (playground.GameTerminals.Length == 0 || playground.GameTerminals[0].UISequence_Current != CGamePlaygroundUIConfig::EUISequence::Playing) { ClearBoosters(); MapUid = ""; return; }
    ClearBoosters();
    array<string> boosterKeywords = { "turbo", "boost" };
    array<string> effectKeywords = { "noengine", "nobrake", "nosteering", "cruise", "reset", "fragile", "slowmotion" };
    array<string> carKeywords = { "gameplaystadium", "gameplaysnow", "gameplayrally", "gameplaydesert" };

    if (showBoosterBlocks) {
        for (uint i = 0; i < app.RootMap.Blocks.Length; i++) {
            auto block = app.RootMap.Blocks[i];
            if (block.BlockModel is null) continue;
            string name = block.BlockModel.Name;
            string lower = name.ToLower();
            bool added = false;
            if (showEffectBlocks) {
                for (uint k = 0; k < effectKeywords.Length; k++) {
                    if (lower.Contains(effectKeywords[k])) {
                        vec3 boosterPos = vec3(block.Coord.x * 32 + 16, block.Coord.y, block.Coord.z * 32 + 16);
                        effectPositions.InsertLast(boosterPos);
                        effectNames.InsertLast(name);
                        added = true;
                        break;
                    }
                }
            }
            if (!added && showCarSwitches) {
                for (uint k = 0; k < carKeywords.Length; k++) {
                    if (lower.Contains(carKeywords[k])) {
                        vec3 boosterPos = vec3(block.Coord.x * 32 + 16, block.Coord.y, block.Coord.z * 32 + 16);
                        effectPositions.InsertLast(boosterPos);
                        effectNames.InsertLast(name);
                        added = true;
                        break;
                    }
                }
            }
            if (!added) {
                for (uint k = 0; k < boosterKeywords.Length; k++) {
                    if (lower.Contains(boosterKeywords[k])) {
                        vec3 boosterPos = vec3(block.Coord.x * 32 + 16, block.Coord.y, block.Coord.z * 32 + 16);
                        effectPositions.InsertLast(boosterPos);
                        effectNames.InsertLast(name);
                        break;
                    }
                }
            }
        }
    }
    for (uint i = 0; i < app.RootMap.AnchoredObjects.Length; i++) {
        auto item = app.RootMap.AnchoredObjects[i];
        if (item.ItemModel is null) continue;
        string name = item.ItemModel.Name;
        string lower = name.ToLower();
        bool added = false;
        if (showBoosterItems && showEffectBlocks) {
            for (uint k = 0; k < effectKeywords.Length; k++) {
                if (lower.Contains(effectKeywords[k])) {
                    effectPositions.InsertLast(item.AbsolutePositionInMap);
                    effectNames.InsertLast(name);
                    added = true;
                    break;
                }
            }
        }
        if (showBoosterItems && !added && showCarSwitches) {
            for (uint k = 0; k < carKeywords.Length; k++) {
                if (lower.Contains(carKeywords[k])) {
                    effectPositions.InsertLast(item.AbsolutePositionInMap);
                    effectNames.InsertLast(name);
                    added = true;
                    break;
                }
            }
        }
        if (showBoosterItems && !added) {
            for (uint k = 0; k < boosterKeywords.Length; k++) {
                if (lower.Contains(boosterKeywords[k])) {
                    effectPositions.InsertLast(item.AbsolutePositionInMap);
                    effectNames.InsertLast(name);
                    break;
                }
            }
        }
    }
    print("Total boosters found: " + effectPositions.Length);
}

void OnSettingsChanged() {
    RunScan();
}

void ClearBoosters() {
    effectPositions.Resize(0);
    effectNames.Resize(0);
}

void Render() {
    RenderMenu();
    auto app = cast<CGameCtnApp>(GetApp());
    if (app is null || app.RootMap is null) return;
    auto playground = cast<CGamePlayground>(app.CurrentPlayground);
    if (playground is null) return;
    auto cam = Camera::GetCurrent();
    if (cam is null) return;

    for (uint i = 0; i < effectPositions.Length; i++) {
        vec3 pos = effectPositions[i];
        vec3 screenPos = Camera::ToScreen(pos);
        if (screenPos.z > 0.0f) continue;
        if (screenPos.x < 0.0f || screenPos.x > Draw::GetWidth()) continue;
        if (screenPos.y < 0.0f || screenPos.y > Draw::GetHeight()) continue;

        string displayName = GetDisplayName(effectNames[i]);
        if (displayName == "Random Boost") {
            DrawRandomBoostDot(screenPos);
        } else if (
            displayName == "Engine off" || displayName == "No Brakes" || displayName == "No Steering" ||
            displayName == "Cruise Control" || displayName == "Reset" || displayName == "Fragile" || displayName == "Riolu" || displayName == "Slow-Motion"
        ) {
            DrawEffectDot(screenPos, GetDotColor(displayName));
        } else if (
            displayName == "Stadium Car" || displayName == "Snow Car" || displayName == "Rally Car" || displayName == "Desert Car"
        ) {
            DrawCarSwitchDot(screenPos, GetDotColor(displayName));
        } else {
            DrawBoosterDot(screenPos, GetDotColor(displayName));
        }
        if (showNames) DrawBoosterName(screenPos, displayName);
    }
}

void RenderMenu() {
    bool prevShowNames = showNames;
    bool prevshowBoosterBlocks = showBoosterBlocks;
    bool prevshowBoosterItems = showBoosterItems;
    bool prevshowEffectBlocks = showEffectBlocks;
    bool prevshowCarSwitches = showCarSwitches;
    if (UI::BeginMenu(Icons::Eye + "No More Hidden Effects")) {
        showNames = UI::Checkbox("Show Block/Items Names", showNames);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text('\\$ff0'+Icons::ExclamationTriangle + '\\$z If you are experiencing lag, turn this off or reduce font size');
            UI::EndTooltip();
        }
        showBoosterBlocks = UI::Checkbox("Show Block Turbos/Reactors", showBoosterBlocks);
        showBoosterItems = UI::Checkbox("Show Item Turbos/Reactors", showBoosterItems);
        showEffectBlocks = UI::Checkbox("Show Effect Blocks/Items", showEffectBlocks);
        showCarSwitches = UI::Checkbox("Show Car Switches", showCarSwitches);
        dotSize = UI::SliderFloat("Dot Size", dotSize, 8, 48);
        fontSize = UI::SliderFloat("Font Size", fontSize, 2, 32);
        UI::EndMenu();
    }
        if (SettingsChanged(prevShowNames, prevshowBoosterBlocks, prevshowBoosterItems, prevshowEffectBlocks, prevshowCarSwitches)) {
            RunScan();
        }
    }
    
    bool SettingsChanged(bool prevShowNames, bool prevshowBoosterBlocks, bool prevshowBoosterItems, bool prevshowEffectBlocks, bool prevshowCarSwitches) {
        return prevShowNames != showNames
            || prevshowBoosterBlocks != showBoosterBlocks
            || prevshowBoosterItems != showBoosterItems
            || prevshowEffectBlocks != showEffectBlocks
            || prevshowCarSwitches != showCarSwitches;
}

void DrawRandomBoostDot(const vec3 &in screenPos) {
    float blackRadius = dotSize + 2.0f;
    float rest = dotSize;
    float ringStep = rest / 3.0f;
    float lavenderRadius = dotSize;
    float blueRadius = lavenderRadius - ringStep;
    float yellowRadius = blueRadius - ringStep;
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), blackRadius);
    nvg::FillColor(vec4(0, 0, 0, 1.0)); 
    nvg::Fill();
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), lavenderRadius);
    nvg::FillColor(vec4(180.0/255.0, 86.0/255.0, 242.0/255.0, 1.0));
    nvg::Fill();
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), blueRadius);
    nvg::FillColor(vec4(92.0/255.0, 218.0/255.0, 244.0/255.0, 1.0));
    nvg::Fill();
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), yellowRadius);
    nvg::FillColor(vec4(239.0/255.0, 223.0/255.0, 80.0/255.0, 1.0)); 
    nvg::Fill();
}

void DrawRing(const vec3 &in screenPos, float radius, const vec4 &in color) {
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), radius);
    nvg::StrokeColor(color);
    nvg::StrokeWidth(4.0f);
    nvg::Stroke();
}

void DrawBoosterDot(const vec3 &in screenPos, const vec4 &in color) {
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), dotSize+2);
    nvg::FillColor(vec4(0, 0, 0, 1.0));
    nvg::Fill();
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), dotSize);
    nvg::FillColor(color);
    nvg::Fill();
}

void DrawEffectDot(const vec3 &in screenPos, const vec4 &in color) {
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), dotSize+2);
    nvg::FillColor(vec4(1, 1, 1, 1.0));
    nvg::Fill();
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), dotSize);
    nvg::FillColor(color);
    nvg::Fill();
}

void DrawCarSwitchDot(const vec3 &in screenPos, const vec4 &in color) {
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), dotSize+4);
    nvg::FillColor(color);
    nvg::Fill();
    nvg::BeginPath();
    nvg::Circle(vec2(screenPos.x, screenPos.y), dotSize-2);
    nvg::FillColor(vec4(0, 0, 0, 1.0));
    nvg::Fill();
}

void DrawBoosterName(const vec3 &in screenPos, const string &in displayName) {
    nvg::FontSize(fontSize);
    nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);

    array<vec2> offsets = {
        vec2(-1, 0), vec2(1, 0), vec2(0, -1), vec2(0, 1),
        vec2(-1, -1), vec2(-1, 1), vec2(1, -1), vec2(1, 1)
    };

    nvg::FillColor(vec4(0, 0, 0, 1.0));
    for (uint i = 0; i < offsets.Length; i++) {
        nvg::Text(screenPos.x + offsets[i].x, screenPos.y - 28 + offsets[i].y, displayName);
    }

    if (displayName == "Random Boost") {
        nvg::FillColor(vec4(1, 0.8, 0.2, 1.0));
    } else {
        nvg::FillColor(GetDotColor(displayName));
    }
    nvg::Text(screenPos.x, screenPos.y - 28, displayName);
}

string GetDisplayName(const string &in rawName) {
    string lower = rawName.ToLower();
    if (lower.Contains("noengine")) return "Engine off";
    if (lower.Contains("nobrake")) return "No Brakes";
    if (lower.Contains("nosteering")) return "No Steering";
    if (lower.Contains("cruise")) return "Cruise Control";
    if (lower.Contains("reset")) return "Reset";
    if (lower.Contains("fragile")) return "Fragile";
    if (lower.Contains("slowmotion")) {
        return slowMoName;
    }
    if (lower.Contains("gameplaystadium")) return "Stadium Car";
    if (lower.Contains("gameplaysnow")) return "Snow Car";
    if (lower.Contains("gameplayrally")) return "Rally Car";
    if (lower.Contains("gameplaydesert")) return "Desert Car";
    if (lower.Contains("roulette")) return "Random Boost";
    if (lower.Contains("boost2")) return "Super Reactor";
    if (lower.Contains("boost")) return "Reactor";
    if (lower.Contains("turbo2")) return "Super Turbo";
    if (lower.Contains("turbo")) return "Turbo";
    return rawName;
}

vec4 GetDotColor(const string &in displayName) {
    if (displayName == "Engine off") return vec4(243.0/255.0, 42.0/255.0, 48.0/255.0, 1.0); 
    if (displayName == "No Brakes") return vec4(245.0/255.0, 192.0/255.0, 53.0/255.0, 1.0); 
    if (displayName == "No Steering") return vec4(185.0/255.0, 56.0/255.0, 211.0/255.0, 1.0);
    if (displayName == "Cruise Control") return vec4(54.0/255.0, 124.0/255.0, 248.0/255.0, 1.0);
    if (displayName == "Reset") return vec4(144.0/255.0, 242.0/255.0, 71.0/255.0, 1.0); 
    if (displayName == "Fragile") return vec4(255.0/255.0, 139.0/255.0, 33.0/255.0, 1.0);
    if (displayName == "Slow-Motion") return vec4(238.0/255.0, 231.0/255.0, 222.0/255.0, 1.0);
    if (displayName == "Riolu") return vec4(238.0/255.0, 231.0/255.0, 222.0/255.0, 1.0); 
    if (displayName == "Stadium Car") return vec4(24.0/255.0, 215.0/255.0, 119.0/255.0, 1.0); 
    if (displayName == "Snow Car") return vec4(208.0/255.0, 4.0/255.0, 3.0/255.0, 1.0); 
    if (displayName == "Rally Car") return vec4(255.0/255.0, 149.0/255.0, 14.0/255.0, 1.0); 
    if (displayName == "Desert Car") return vec4(255.0/255.0, 234.0/255.0, 65.0/255.0, 1.0); 
    if (displayName == "Super Reactor") return vec4(216.0/255.0, 145.0/255.0, 93.0/255.0, 1.0); 
    if (displayName == "Reactor") return vec4(189.0/255.0, 251.0/255.0, 64.0/255.0, 1.0);
    if (displayName == "Turbo") return vec4(244.0/255.0, 220.0/255.0, 77.0/255.0, 1.0); 
    if (displayName == "Super Turbo") return vec4(200.0/255.0, 80.0/255.0, 74.0/255.0, 1.0); 
    if (displayName == "Random Boost") return vec4(1.0, 1.0, 1.0, 0.0);
    return vec4(1.0, 0.3, 0.0, 1.0);
}