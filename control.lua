local mod_gui = require("mod-gui")
local blueprint_editor_surface_size = 2
local blueprint_editor_original_position = {0,0}
local original_blueprint_string = ''

function debug_print(text)
  --game.print(text)
end

local e_name = 'bp-editor-surface'


local map_settings = 
  {
    seed = 666,
    width = 32*blueprint_editor_surface_size,
    height = 32*blueprint_editor_surface_size,
    
    autoplace_controls = {
      coal = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      ["copper-ore"] = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      ["crude-oil"] = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      ["enemy-base"] = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      ["iron-ore"] = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      stone = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      trees = {
        frequency = 1,
        richness = 1,
        size = 0
      },
      ["uranium-ore"] = {
        frequency = 1,
        richness = 1,
        size = 0
      }
    },

    autoplace_settings = {},
    cliff_settings = {
      cliff_elevation_0 = 10,
      cliff_elevation_interval = 40,
      name = "cliff",
      richness = 0
    },
    peaceful_mode = false,
    property_expression_names = {},
    starting_area = 1,
    starting_points = {
      {
        x = 0,
        y = 0
      }
    },
    terrain_segmentation = 1,
    water = 0,

  }

function migrate_inventory(source, destination)
  for item_name, item_count in pairs(source.get_inventory[1]) do
    destination.insert{name = item_name, count = item_count}
  end
end

function generate_lab_tile_surface(player, surface_name, surface_size)
  if game.surfaces[surface_name] then
    debug_print('Edit surface found.')
    edit_surface = game.surfaces[surface_name]
  else
    debug_print('Edit surface not found, creating...')
    edit_surface = game.create_surface(surface_name, map_settings)
    
    edit_surface.request_to_generate_chunks( {0,0} , surface_size)
    edit_surface.force_generate_chunk_requests()
    player.force.chart_all()
    
    local old_tiles = edit_surface.find_tiles_filtered({})
    local new_tiles = {}
    for _, t in pairs(old_tiles) do
      local coord_test = (t.position.x + t.position.y)%2
      local tile_name = 'lab-white'
      if (coord_test==0) then
        tile_name = 'lab-dark-1'
      else
        tile_name = 'lab-dark-2'
      end  
      table.insert(new_tiles, {name = tile_name, position=t.position})
    end
    edit_surface.set_tiles(new_tiles)
    debug_print('Generated lab tiles.')
    
    edit_surface.destroy_decoratives({invert=true})
    debug_print('Destroyed decoratives.')
  end

  return edit_surface
end

local function toggle_editor_and_teleport(player, destination_surface_name, original_position, editor_on)
  if editor_on == true then  
    player.teleport({0,0}, destination_surface_name)
      if player.controller_type ~= 4 then
        player.toggle_map_editor()
      end
  else
    player.teleport(blueprint_editor_original_position, destination_surface_name)
    if player.controller_type == 4 then
      player.toggle_map_editor()
    end
  end
end

local function clear_entities(target_surface)
  local entity_list = target_surface.find_entities()
  for _, ent in pairs(entity_list) do
    ent.destroy()
  end
  debug_print('Destroyed entities.')
end

local function build_blueprint(player, blueprint_string, target_surface)
  player.cursor_stack.import_stack(original_blueprint_string)

  local ghosts = player.cursor_stack.build_blueprint{surface = target_surface.name, position = {0,0}, force = 'player' }
  player.cursor_stack.clear()
  debug_print('Built blueprint.')

  local ghost_trains = {}
  for _,ghost in pairs(ghosts) do
    if ghost.ghost_name == 'locomotive' or ghost.ghost_name == 'cargo-wagon' or ghost.ghost_name == 'fluid-wagon' or ghost.ghost_name == 'artillery-wagon' then
      table.insert(ghost_trains, ghost)
    else
      debug_print(ghost.ghost_name)
      ghost.silent_revive()
    end
  end
  debug_print('Revived ghosts.')

  for _,ghost in pairs(ghost_trains) do
    debug_print(ghost.ghost_name)
    ghost.silent_revive()
  end
  debug_print('Revived train ghosts.')
end

local function revert_blueprint_editing(player, original_blueprint_string, edit_surface)
  clear_entities(edit_surface)
  build_blueprint(player, original_blueprint_string, edit_surface)
end

local function enter_blueprint_editing(player)
  if player.cursor_stack.valid_for_read then
    if player.cursor_stack.is_blueprint_setup() == true then
      if player.cursor_stack.name == 'blueprint' then --if player.cursor_stack.name == 'blueprint' or player.cursor_stack.name == 'blueprint-book' then
        create_bp_editor_popup(player)
        visibility_bp_editor_popup(player, true)
        visibility_bp_editor_button(player, false)

        blueprint_editor_original_label = player.cursor_stack.label
        blueprint_editor_original_blueprint_icons = player.cursor_stack.blueprint_icons
        original_blueprint_string = player.cursor_stack.export_stack()

        clear_entities(edit_surface)
        toggle_editor_and_teleport(player, e_name, {0,0}, true)
        build_blueprint(player, original_blueprint_string, edit_surface)
      else
        game.print('Item in cursor is not a blueprint.')
      end
    else
      game.print('Blueprint in cursor is empty.')
    end
  else
    game.print('No blueprint in cursor.')
  end
end

local function finish_blueprint_editing(player, blueprint_editor_original_position, surface_size, discard_changes)
  if discard_changes == false then
    player.cursor_stack.set_stack('blueprint')
    local result_blueprint_string  = ''
    if game.surfaces['bp-editor-surface'] then
      player.cursor_stack.create_blueprint({
        surface = 'bp-editor-surface',
        force = 'player',
        area = {{-32*surface_size, -32*surface_size},{32*surface_size,32*surface_size}},
        always_include_tiles = true,
        include_entities = true,
        include_modules = true,
        include_trains = true,
        include_station_names = true
      })
      result_blueprint_string = player.cursor_stack.export_stack()
    else
      game.print('Blueprint editor surface not found.')
    end
    toggle_editor_and_teleport(player, 'nauvis', blueprint_editor_original_position, false)
    player.cursor_stack.import_stack(result_blueprint_string)
    player.cursor_stack.label = blueprint_editor_original_label
    player.cursor_stack.blueprint_icons = blueprint_editor_original_blueprint_icons
  else
    player.cursor_stack.import_stack(original_blueprint_string)
    toggle_editor_and_teleport(player, 'nauvis', blueprint_editor_original_position, false)
  end
  visibility_bp_editor_popup(player, false)
  visibility_bp_editor_button(player, true)
end

function visibility_bp_editor_button(player, visibility)
  if mod_gui.get_button_flow(player)['blueprint-edit-button'] then
    mod_gui.get_button_flow(player)['blueprint-edit-button'].visible = visibility
  end
end
function visibility_bp_editor_popup(player, visibility)
  if player.gui.center['bp-editor-popup-flow']['bp-editor-popup-frame'] then
    player.gui.center['bp-editor-popup-flow']['bp-editor-popup-frame'].visible = visibility
  end
end
function clear_bp_editor_button(player)
  if mod_gui.get_button_flow(player)['blueprint-edit-button'] then
    mod_gui.get_button_flow(player)['blueprint-edit-button'].destroy()
  end
end
function clear_bp_editor_popup(player)
  if player.gui.center['bp-editor-popup-frame'] then
    player.gui.center['bp-editor-popup-frame'].destroy()
  end
  if player.gui.center['bp-editor-popup-flow'] then
    player.gui.center['bp-editor-popup-flow'].destroy()
  end
end
function create_top_button(player)
  clear_bp_editor_button(player)
  mod_gui.get_button_flow(player).add
  {
    type = "sprite-button",
    name = "blueprint-edit-button",
    sprite = "blueprint-editor-button-1",
    style = mod_gui.button_style
  }
end
function create_bp_editor_popup(player)
  clear_bp_editor_popup(player)

  local flow = player.gui.center.add({
    type = 'flow',
    name = 'bp-editor-popup-flow',
    direction = 'vertical'
  })
  flow.style.height = player.display_resolution.height*0.8/player.display_scale
  flow.style.vertical_align = 'bottom'
  flow.style.horizontal_align = 'center'

  local frame = flow.add({
    type = 'frame',
    name = 'bp-editor-popup-frame',
    direction = 'horizontal',
    caption = 'Blueprint editor'
  })
  frame.style.vertically_stretchable = false
  frame.ignored_by_interaction = false
  
  local button_exit = frame.add
  {
    type = "button",
    name = "blueprint-edit-button-discard",
    caption = 'Discard',
    tooltip = 'Discard changes and exit the editor.',
    style = 'red_back_button'
  }
  local button_revert = frame.add
  {
    type = "button",
    name = "blueprint-edit-button-revert",
    caption = 'Revert',
    tooltip = 'Revert changes and keep editing.',
    style = 'dialog_button'
  }
  local button_discard = frame.add
  {
    type = "button",
    name = "blueprint-edit-button-finish",
    caption = 'Finish',
    tooltip = 'Confirm changes and exit the editor.',
    style = 'confirm_button'
  }

  return frame
end

script.on_event(defines.events.on_player_cursor_stack_changed ,
  function(event)
    local player = game.get_player(event.player_index)
    create_top_button(player)
    generate_lab_tile_surface(player, 'bp-editor-surface', blueprint_editor_surface_size )
  end
)

script.on_event(defines.events.on_player_created ,
  function(event)
    local player = game.get_player(event.player_index)
    create_top_button(player)
    generate_lab_tile_surface(player, 'bp-editor-surface', blueprint_editor_surface_size )
  end
)

script.on_event(defines.events.on_gui_click ,
  function(event)
    if event.element.name == "blueprint-edit-button" then
      local player = game.get_player(event.player_index)
      blueprint_editor_original_position = player.position
      enter_blueprint_editing(player)
    end

    if event.element.name == "blueprint-edit-button-finish" then
      local player = game.get_player(event.player_index)
      finish_blueprint_editing(player, blueprint_editor_original_position, blueprint_editor_surface_size, false)
    end
    if event.element.name == "blueprint-edit-button-revert" then
      local player = game.get_player(event.player_index)
      revert_blueprint_editing(player, original_blueprint_string, edit_surface)
    end
    if event.element.name == "blueprint-edit-button-discard" then
      local player = game.get_player(event.player_index)
      finish_blueprint_editing(player, blueprint_editor_original_position, blueprint_editor_surface_size, true)
    end
  end
)
