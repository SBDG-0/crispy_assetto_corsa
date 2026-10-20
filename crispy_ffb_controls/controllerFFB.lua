-- FFB settings page based on x4fab's Controller Tweaks 1.1.
-- Shared config/reset helpers keep all tabs editing the same native values.
local M = {}
local function header(text) ui.offsetCursorY(4); ui.header(text) end
function M.draw(ctx)
  local c,s,t,p = ctx.configs.controls,ctx.configs.system,ctx.configs.tweaks,ctx.configs.post
  local slider = ctx.slider
  ui.header('Car FFB gain:'); ctx.carGain()
  header('FFB:')
  slider(c,'STEER','FF_GAIN',0,200,100,'Gain: %.0f%%','Overall FFB intensity')
  slider(c,'STEER','FILTER_FF',0,100,100,'Filter: %.0f%%','Increase to smooth out FFB')
  slider(c,'FF_SKIP_STEPS','VALUE',0,10,1,'Skip steps: %.0f',string.format('FFB refresh rate: %.0f Hz',333/(1+math.max(0,c.data.FF_SKIP_STEPS.VALUE))))
  header('FFB tweaks:')
  slider(c,'FF_TWEAKS','MIN_FF',0,100,100,'Minimum force: %.0f%%','Minimum force sent to the wheel')
  slider(c,'FF_TWEAKS','CENTER_BOOST_GAIN',0,1000,100,'Center boost gain: %.0f%%','Optional force increase around steering centre')
  slider(c,'FF_TWEAKS','CENTER_BOOST_RANGE',0,100,100,'Center boost range: %.0f%%','Width of centre boost')
  header('FFB enhancements:')
  for _,v in ipairs({{'CURBS','Curbs'},{'ROAD','Road'},{'SLIPS','Slips'},{'ABS','ABS'}}) do
    slider(c,'FF_ENHANCEMENT',v[1],0,200,100,v[2] .. ': %.0f%%','Additional vibration effect')
  end
  slider(c,'FF_ENHANCEMENT_2','UNDERSTEER',0,200,100,'Understeer: %.0f%%','Hidden Controller Tweaks understeer effect')
  ctx.gyro(false)
  header('Low speed FFB reduction:')
  slider(s,'LOW_SPEED_FF','SPEED_KMH',0,30,1,'Speed threshold: %.0f km/h','FFB reduction below this speed')
  slider(s,'LOW_SPEED_FF','MIN_VALUE',0,100,100,'Force multiplier: %.0f%%','FFB multiplier below speed threshold')
  -- Damper settings are global and remain useful regardless of gyro selection.
  header('FFB damper:')
  slider(s,'FF_EXPERIMENTAL','DAMPER_GAIN',0,200,100,'Gain: %.0f%%','Damping gain')
  slider(s,'FF_EXPERIMENTAL','DAMPER_MIN_LEVEL',0,200,100,'Min level: %.0f%%','Damping remaining at speed')
  header('FFB post-processing:')
  if not t.data.BASIC.ENABLED then
    ui.textWrapped('FFB Tweaks module is disabled.')
    if ui.button('Enable FFB Tweaks') then t:set('BASIC','ENABLED',true) end
  end
  slider(t,'POSTPROCESSING','RANGE_COMPRESSION',50,400,100,'Range compression: %.0f%%','Higher values compress force and increase smaller forces')
  ctx.checkbox(t,'POSTPROCESSING','RANGE_COMPRESSION_ASSIST','Range compression assist')
  local function mode(data) return data.HEADER.ENABLED and (data.HEADER.TYPE=='GAMMA' and 2 or 3) or 1 end
  local current,original = mode(p.data),mode(p.original)
  ui.setNextItemWidth(ui.availableSpaceX()-24)
  local selected,changed=ui.combo('##postMode',current,ui.ComboFlags.None,{'Disabled','Gamma','LUT'})
  if ctx.reset('postMode',selected~=original,'Restore original post-processing mode') then selected,changed=original,true end
  if changed then
    p:set('HEADER','ENABLED',selected~=1)
    if selected~=1 then p:set('HEADER','TYPE',selected==2 and 'GAMMA' or 'LUT') end
    current=selected
  end
  if current==2 then
    slider(p,'GAMMA','VALUE',30,300,100,'Gamma value: %.0f%%','Below 100% boosts small forces; above 100% attenuates them')
  elseif current==3 then
    ui.setNextItemWidth(ui.availableSpaceX()-24)
    local file=p.data.LUT.CURVE
    ui.combo('##lutFile',file~='' and file or 'None',ui.ComboFlags.None,function()
      for _,name in ipairs(io.scanDir(ac.getFolder(ac.FolderID.Cfg),'*.lut')) do
        if ui.selectable(name,name==file) then p:set('LUT','CURVE',name) end
      end
    end)
    if ctx.reset('lutFile',p.data.LUT.CURVE~=p.original.LUT.CURVE,'Restore original LUT selection') then p:set('LUT','CURVE',p.original.LUT.CURVE) end
    ui.textWrapped('LUT files are loaded from Documents/Assetto Corsa/cfg. LUT creation/import utilities remain in Controller Tweaks.')
  end
end
return M
