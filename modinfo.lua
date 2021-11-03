name = "Chest Memory"
author = "sauktux"
version = "1.5"

forumthread = ""
description = "See what kind of items are inside a chest without reopening it." -- Keep the description short and simple. Thanks!

api_version = 10

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
dst_compatible = true

all_clients_require_mod = false
client_only_mod = true
server_filter_tags = {}

icon_atlas = "modicon.xml"
icon = "modicon.tex"

local function AddConfig(name,label,hover,options,default)
    return  {
        name = name,
        label = label,
        hover = hover,
        options = options,
        default = default,
        }
end
local function AddEmptySeperator(seperator)
    return {
  name = "",
  label = seperator,
  hover = "",
  options = {
    {description = "", data = 0},
  },
  default = 0,
  
}
end

local function AddOpt(desc,data,hover)
   return {description = desc, data = data, hover = hover} 
end

local bool_opt = {
    AddOpt("True",true),
    AddOpt("False",false),
}

local keys_opt = {
  AddOpt("None--",0),
  AddOpt("A",97),
  AddOpt("B",98),
  AddOpt("C",99),
  AddOpt("D",100),
  AddOpt("E",101),
  AddOpt("F",102),
  AddOpt("G",103),
  AddOpt("H",104),
  AddOpt("I",105),
  AddOpt("J",106),
  AddOpt("K",107),
  AddOpt("L",108),
  AddOpt("M",109),
  AddOpt("N",110),
  AddOpt("O",111),
  AddOpt("P",112),
  AddOpt("Q",113),
  AddOpt("R",114),
  AddOpt("S",115),
  AddOpt("T",116),
  AddOpt("U",117),
  AddOpt("V",118),
  AddOpt("W",119),
  AddOpt("X",120),
  AddOpt("Y",121),
  AddOpt("Z",122),
  AddOpt("--None--",0),
  AddOpt("Period",46),
  AddOpt("Slash",47),
  AddOpt("Semicolon",59),
  AddOpt("LeftBracket",91),
  AddOpt("RightBracket",93),
  AddOpt("F1",282),
  AddOpt("F2",283),
  AddOpt("F3",284),
  AddOpt("F4",285),
  AddOpt("F5",286),
  AddOpt("F6",287),
  AddOpt("F7",288),
  AddOpt("F8",289),
  AddOpt("F9",290),
  AddOpt("F10",291),
  AddOpt("F11",292),
  AddOpt("F12",293),
  AddOpt("Up",273),
  AddOpt("Down",274),
  AddOpt("Right",275),
  AddOpt("Left",276),
  AddOpt("PageUp",280),
  AddOpt("PageDown",281),
  AddOpt("Home",278),
  AddOpt("Insert",277),
  AddOpt("Delete",127),
  AddOpt("End",279),
  AddOpt("--None",0),
}

local special_buttons = {
    AddOpt("None--",0),
    AddOpt("RShift",303),
    AddOpt("LShift",304),
    AddOpt("LCtrl",306),
    AddOpt("RCtrl",305),
    AddOpt("RAlt",307),
    AddOpt("LAlt",308),
    AddOpt("--None",0),
  }
  
  local widget_displaytype = {
    AddOpt("Show All","All","All chest widgets will be displayed on screen(Can be laggy)"),
    AddOpt("On hover","Single","Chest widget will only be displayed when it's hovered over"),
      }
  
  local sizes = {}
  for i = 10,24 do
     sizes[i-9] = AddOpt(""..i/2,i/2)
  end
  
  local hightlight_sizes = {}
  for i = 3,20 do
      hightlight_sizes[i-2] = AddOpt(""..i/2,i/2)
  end
  
  local chest_toggle_types = {
      AddOpt("Default","default","Disable <=> Enable"),
      AddOpt("All Display Types","all_displays","Disable <=> Show On Hover <=> Show All"),
      AddOpt("All+Hide","all","Hidden/Disable(Special Key) <=> Show On Hover <=> Show All"),
  }
  

configuration_options = {
        AddConfig("highlight_onmouseover","Highlight Selected","Increase the widget display size for the chest that is moused over.",bool_opt,true),
        AddConfig("default_show","Default Show","Should the chest display widget be shown/enabled by default?",bool_opt,true),
        AddConfig("widget_toggle","Toggle Display","Press this button to hide or show the chest widget.\n(Warning: Can be laggy)",keys_opt,106), -- J
        AddConfig("widget_cycle","Toggle Display Type","Which options should the Toggle Display cycle through?",chest_toggle_types,"all"),
        AddConfig("highlight_activeitem","Highlight Active Item","Should chests, which contain the item you're holding, get hightlight coloured?",bool_opt,true),
        AddConfig("highlight_ingredient","Highlight Ingredient","Should chests, which contain the ingredient you're hovering over, get highlight coloured?",bool_opt,true),
        AddConfig("widget_displaytype","Display Type","How should the chest display be handled?",widget_displaytype,"Single"),
        AddConfig("widget_highlightsize","Highlight Scale","How much should the chests widget size get multiplied when highlighted?",hightlight_sizes,3),
        AddConfig("widget_scale","Widget Size","Size of the displayed chest widget.",sizes,5),
        AddConfig("highlightpause_button","Special Hold","The button that has to be held to be able to scroll through chest memory",special_buttons,308),
        AddConfig("include_icebox","Icebox Memory","Should an Icebox memory be shown too?", bool_opt,true),
        AddConfig("include_saltbox","Salt Memory","Should a Saltbox memory be shown too?", bool_opt,true),
    }