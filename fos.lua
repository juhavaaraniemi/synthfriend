-- friend of synths
--
-- 16 ccs total
-- 4 in each bank
--
-- e1     scale
-- e2     cc1
-- e3     cc2
-- k1+e2  cc3
-- k1+e3  cc4
-- k2     bank down
-- k3     bank up



--
-- LIBRARIES
--
pattern_time = require 'pattern_time'
musicutil = require 'musicutil'

--
-- DEVICES
--
g = grid.connect()
m = midi.connect()

--
-- VARIABLES
--
bank = 1
bank_size = 4
bank_start = 0
cc = 1
cc_value = {}
active_midi_notes = {}
grid_dirty = false
screen_dirty = false
for i=1,64 do
  cc_value[i] = 0
end
scale_names = {}
for i = 1, #musicutil.SCALES do
  table.insert(scale_names, musicutil.SCALES[i].name)
end



--
-- INIT FUNCTIONS
--
function init_parameters()
  params:add{
    type="number",
    id="note_channel",
    name="midi note channel",
    min=1,
    max=16,
    default=1
  }
  params:add{
    type="number",
    id="cc_channel",
    name="midi cc channel",
    min=1,
    max=16,
    default=2
  }
  params:add{
    type="option",
    id="scale",
    name="scale",
    options=scale_names,
    default=41,
    action=function()
      build_scale()
    end
  }
  params:add{
    type="number",
    id="root_note",
    name="root note",
    min=0,
    max=127,
    default=24,
    formatter=function(param)
      return musicutil.note_num_to_name(param:get(),true)
    end,
    action=function(value)
      build_scale()
    end
  }
  params:add{
    type="number",
    id="velocity",
    name="note velocity",
    min=0,
    max=127,
    default=100
  }
  params:add{
    type="number",
    id="row_interval",
    name="row interval",
    min=1,
    max=12,
    default=5,
    action=function(value)
      build_scale()
    end
  }
end

function init_grid()
  momentary = {}
  for x = 1,16 do
    momentary[x] = {}
    for y = 1,7 do
      momentary[x][y] = false
    end
  end
end

function init_pattern_recorders()
  cc1_pattern = pattern_time.new()
  cc1_pattern.process = parse_cc1_pattern
  
  grid_pattern = pattern_time.new()
  grid_pattern.process = parse_grid_pattern
  
--  grid_pattern = {}
--  for i=1,7 do
--    grid_pattern[i] = pattern_time.new()
--      grid_pattern[i].process = parse_grid_pattern..i
--  end
end

function init()
  init_parameters()
  init_grid()
  build_scale()
  init_pattern_recorders()
  grid_redraw()
  redraw()
  clock.run(grid_redraw_clock)
  clock.run(redraw_clock)
end


--
-- CLOCK FUNCTIONS
--
function grid_redraw_clock()
  while true do
    clock.sleep(1/30) -- refresh at 30fps.
    if grid_dirty then
      grid_redraw()
      grid_dirty = false
    end
  end
end

function redraw_clock()
  while true do
    clock.sleep(1/30) -- refresh at 30fps.
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
end


--
-- PATTERN RECORDER FUNCTIONS
--
function record_cc1_value()
  cc1_pattern:watch(
    {
      ["value"] = cc_value[1]
    }
  )
end

function record_grid_value()
  grid_pattern:watch(
    {
      ["value"] = cc_value[1]
    }
  )
end

function parse_cc1_pattern(data)
  cc_value[1] = data.value
end


--
-- MIDI FUNCTIONS
--
function note_on(note_num, vel, chan)
  m:note_on(note_num, vel, chan)
  if active_midi_notes[note_num] == nil then
    active_midi_notes[note_num] = true
  end
  print("note_on:"..musicutil.note_num_to_name(note_num,true))
end

function note_off(note_num, chan)
  m:note_off(note_num, chan)
  active_midi_notes[note_num] = nil
  --print("note_off:"..musicutil.note_num_to_name(note_num,true))
end

function build_scale()
  if params:get("scale") ~= 41 then
    note_nums = musicutil.generate_scale_of_length(params:get("root_note"),params:get("scale"),112)
  else
    note_nums = {}
    for i=1,112 do
      note_nums[i] = nil
    end
  end

  row_start_note = params:get("root_note")
  midi_note = {}
  for row = 7,1,-1 do
    note_value = row_start_note
    midi_note[row] = {}
    for col = 1,16 do
      midi_note[row][col] = {}
      midi_note[row][col].value = note_value
      for i=1,112 do
        if midi_note[row][col].value == note_nums[i] then
          midi_note[row][col].in_scale = true
        end
      end
      note_value = note_value + 1
    end
    row_start_note = row_start_note + params:get("row_interval")
  end
  grid_dirty = true
end

--
-- UI FUNCTIONS
--
function key(n,z)
  if n == 1 then
    shifted = z == 1
  elseif shifted and n == 2 and z == 1 then
    print("RECORD")
    cc1_pattern:rec_start()
    record_cc1_value()
  elseif shifted and n == 3 and z == 1 then
    print("STOP REC AND PLAY")
    cc1_pattern:rec_stop()
    cc1_pattern:start()
  elseif n == 2 and z == 1 then
    bank = util.clamp(bank - 1,1,4)
    bank_start = (bank-1)*bank_size
  elseif n == 3 and z == 1 then
    bank = util.clamp(bank + 1,1,4)
    bank_start = (bank-1)*bank_size
  end
  screen_dirty = true
end

function enc(n,d)
  if n > 1 then
    if shifted then
      cc = n+1+bank_start
    else
      cc = n-1+bank_start
    end
    cc_value[(cc)] = util.clamp(cc_value[(cc)] + d,0,127)
    record_cc1_value()
    m:cc((cc),cc_value[(cc)],params:get("cc_channel"))
  elseif shifted and n == 1 then
    params:delta("root_note",d)
  elseif n == 1 then
    params:delta("scale",d)
  end
  screen_dirty = true
end

function g.key(x,y,z)
  --momentary[x][y] = z == 1 and true or false
  if z == 1 then
    momentary[x][y] = true
    note_on(midi_note[y][x].value,params:get("velocity"),params:get("note_channel"))
  else
    momentary[x][y] = false
    note_off(midi_note[y][x].value,params:get("note_channel"))
  end
  grid_dirty = true
end

--
-- REDRAW FUNCTIONS
--
function redraw()
  screen.clear()
  screen.level(15)
  k = 0
  x = 0
  y = 0
  for i=0,3 do
    for j=1,7,2 do
      x = i*32
      y = j*5
      k = k+1
      screen.move(x,y)
      screen.text("cc"..k..":"..cc_value[k])
    end
  end
  
  screen.move(0,50)
  screen.text("bank: "..bank)
  screen.move(0,60)
  screen.text("scale: "..scale_names[params:get("scale")])
  screen.move(85,50)
  screen.text("root: "..musicutil.note_num_to_name(params:get("root_note"), true))
  screen.update()
end

function grid_redraw()
  g:all(0)
  for x = 1,16 do
    for y = 7,1,-1 do
      -- scale notes
      if midi_note[y][x].in_scale == true then
        g:led(x,y,4)
      end
      -- root notes
      if (midi_note[y][x].value - params:get("root_note")) % 12 == 0 then
        g:led(x,y,8)
      end
      -- lit when pressed
      if momentary[x][y] then
        g:led(x,y,15)
      end
    end
  end
  g:refresh()
end
