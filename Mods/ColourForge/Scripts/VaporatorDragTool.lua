dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
-- Original Paint Studio implementation. No third-party mod code.
VaporatorDragTool = class()
local charAnim="$GAME_DATA/Character/Char_Male/Animations/char_male_tp_painttool.rend"
local tpAnim="$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool_tp_animlist.rend"
local fpAnim="$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool_fp_animlist.rend"
local model = "$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool.rend"
sm.tool.preloadRenderables({model,tpAnim,fpAnim,charAnim})
local function validHex(s) return type(s)=="string" and #s==6 and s:match("^%x+$") end
local function rgbHSV(hex)
 local r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
 local hi=math.max(r,g,b);local lo=math.min(r,g,b);local d=hi-lo;local h=0
 if d>0 then if hi==r then h=((g-b)/d)%6 elseif hi==g then h=(b-r)/d+2 else h=(r-g)/d+4 end;h=h/6 end
 return h,hi==0 and 0 or d/hi,hi
end
local function hsvHex(h,s,v)
 local c=v*s;local h6=(h%1)*6;local x=c*(1-math.abs(h6%2-1));local m=v-c;local r,g,b=0,0,0
 if h6<1 then r,g,b=c,x,0 elseif h6<2 then r,g,b=x,c,0 elseif h6<3 then r,g,b=0,c,x elseif h6<4 then r,g,b=0,x,c elseif h6<5 then r,g,b=x,0,c else r,g,b=c,0,x end
 return string.format("%02x%02x%02x",math.floor((r+m)*255+0.5),math.floor((g+m)*255+0.5),math.floor((b+m)*255+0.5))
end
function VaporatorDragTool.client_onCreate(self)
 print("[ColourForge 1.2] Original game paint gun / HSV picker / Q / RMB erase / MMB copy")
 self.colour="30e8dc"; self.scope="Shape"; self.palette=1
 self.equipped=false
end
function VaporatorDragTool.cl_open(self)
 if not self.tool:isLocal() then return end
 if not self.menu then
  self.menu=sm.json.open("$CONTENT_DATA/Gui/JsonGuis/Picker092.gui")
 end
 self.menuQDown=true
 self.widgets={}
 local function index(w) if w.Name then self.widgets[w.Name]=w end;for _,c in ipairs(w.Childs or {}) do index(c) end end
 index(self.menu)
 self.picker=sm.jsonGui.createGui({isInteractive=true,needsCursor=true,hidesHotbar=false})
 self:cl_renderPicker()
end
function VaporatorDragTool.cl_renderPicker(self)
 self:cl_tint(self.colour)
 local tick=sm.game.getCurrentTick()
 if not self.lastTintTick or tick-self.lastTintTick>=4 then self.network:sendToServer("sv_tint",self.colour);self.lastTintTick=tick end
 if not self.fromHSV then self.h,self.s,self.v=rgbHSV(self.colour) end
 self.fromHSV=false
 local rr,gg,bb=tonumber(self.colour:sub(1,2),16),tonumber(self.colour:sub(3,4),16),tonumber(self.colour:sub(5,6),16)
 self.widgets.Hex.Caption=self.colour:upper()
 self.widgets.Preview.Colour=string.format("%f %f %f 1",rr/255,gg/255,bb/255)
 for i,value in ipairs({rr,gg,bb}) do
  self.widgets["Value"..i].Caption=tostring(value)
  self.widgets["Slider"..i.."Cursor"].x=value/255*220-3
 end
 self.widgets.BrightnessCursor.x=self.v*220-3
 self.widgets.WheelImage.Colour=string.format("%f %f %f 1",self.v,self.v,self.v)
 self.widgets.WheelCursor.x=120+math.cos(self.h*math.pi*2)*self.s*118-7
 self.widgets.WheelCursor.y=120-math.sin(self.h*math.pi*2)*self.s*118-7
 self.widgets.HSV.Caption=string.format("H %d   S %d%%   V %d%%",math.floor(self.h*360+0.5),math.floor(self.s*100+0.5),math.floor(self.v*100+0.5))
 self.picker:render(self.menu)
end
function VaporatorDragTool.cl_pickerHex(self,name,text)
 text=text:gsub("#","")
 if validHex(text) then self.colour=text:lower();self:cl_renderPicker() end
end
function VaporatorDragTool.cl_number(self,name,text)
 local axis=tonumber(name:match("%d+"));local value=tonumber(text)
 if not axis or not value then return end
 local c={tonumber(self.colour:sub(1,2),16),tonumber(self.colour:sub(3,4),16),tonumber(self.colour:sub(5,6),16)}
 c[axis]=math.max(0,math.min(255,math.floor(value+0.5)))
 self.colour=string.format("%02x%02x%02x",c[1],c[2],c[3]);self:cl_renderPicker()
end
function VaporatorDragTool.cl_pickerDrag(self,name,x,y)
 local left,top=self.picker:getWidgetAbsolutePosition(name)
 local right,bottom=self.picker:getWidgetAbsolutePosition(name.."Edge")
 local u=math.max(0,math.min(1,(x-left)/math.max(right-left,1)))
 if name=="Wheel" then
  local v=math.max(0,math.min(1,(y-top)/math.max(bottom-top,1)))
  local dx,dy=u*2-1,v*2-1
  self.h=(math.atan2(-dy,dx)/(math.pi*2))%1;self.s=math.min(1,math.sqrt(dx*dx+dy*dy));self.fromHSV=true
  self.colour=hsvHex(self.h,self.s,self.v)
 elseif name=="Brightness" then self.v=u;self.fromHSV=true;self.colour=hsvHex(self.h,self.s,self.v)
 else
  local axis=tonumber(name:match("%d+"));if not axis then return end
  local c={tonumber(self.colour:sub(1,2),16),tonumber(self.colour:sub(3,4),16),tonumber(self.colour:sub(5,6),16)}
  c[axis]=math.floor(u*255+0.5);self.colour=string.format("%02x%02x%02x",c[1],c[2],c[3])
 end
 self:cl_renderPicker()
end
function VaporatorDragTool.cl_pickerButton(self,name)
 if name=="Done" then self.network:sendToServer("sv_tint",self.colour);self.picker:close();return end
 if name:sub(1,1)=="C" then self.colour=name:sub(2);self:cl_renderPicker() end
end
function VaporatorDragTool.cl_refresh(self)
 local p=self.palettes[self.palette]
 self.gui:setText("Palette",p.name.." / "..self.palette.." of "..#self.palettes)
 self.gui:setText("Hex",self.colour)
 self.gui:setText("Scope","Target: "..self.scope)
 self.gui:setColor("Preview",sm.color.new(self.colour.."ff"))
 for i,c in ipairs(p.colours) do self.gui:setColor("Chip"..i,sm.color.new(c.."ff")) end
end
function VaporatorDragTool.cl_swatch(self,name)
 local i=tonumber(name:match("%d+")); if not i then return end
 self.colour=self.palettes[self.palette].colours[i]; self:cl_refresh()
end
function VaporatorDragTool.cl_hex(self,name,text)
 text=text:gsub("#","")
 if validHex(text) then self.colour=text:lower(); self.gui:setColor("Preview",sm.color.new(text.."ff"));self.gui:setText("Status","Colour ready")
 else self.gui:setText("Status","Enter six hex digits, e.g. FF8800") end
end
function VaporatorDragTool.cl_button(self,name)
 if name=="Previous" then self.palette=(self.palette-2)%#self.palettes+1
 elseif name=="Next" then self.palette=self.palette%#self.palettes+1
 elseif name=="Scope" then self.scope=({Shape="Matching type",["Matching type"]="Creation",Creation="Shape"})[self.scope]
 elseif name=="Undo" then self.network:sendToServer("sv_undo",{});return
 elseif name=="Close" then self.gui:close();return end
 self:cl_refresh()
end
function VaporatorDragTool.client_onEquip(self)
 self.equipped=true
 self.traceReported=false
 self.tool:setTpRenderables({model,tpAnim,charAnim})
 self.tpAnimations=createTpAnimations(self.tool,{idle={"painttool_idle",{looping=true}},paint={"painttool_paint",{nextAnimation="idle"}}})
 setTpAnimation(self.tpAnimations,"idle",10)
 if self.tool:isLocal() then self.tool:setFpRenderables({model,fpAnim})
 self.fpAnimations=createFpAnimations(self.tool,{idle={"painttool_idle",{looping=true}},paint={"painttool_paint",{nextAnimation="idle",blendNext=0.1}}})
 setFpAnimation(self.fpAnimations,"idle",0.2) end
 self:cl_tint(self.colour)
end
function VaporatorDragTool.client_onUnequip(self) self.equipped=false; self.drag=nil;self:cl_hideSelection(); if self.picker then self.picker:close() end end
function VaporatorDragTool.client_onDestroy(self) for _,effect in ipairs(self.selectionCells or {}) do effect:destroy() end; if self.picker then self.picker:close() end end
function VaporatorDragTool.cl_closePicker(self)
 self.network:sendToServer("sv_tint",self.colour)
 self.picker:close();self.lastMenuClose=sm.game.getCurrentTick()
end
function VaporatorDragTool.client_onToggle(self)
 self.drag=nil;self:cl_hideSelection()
 if self.picker and self.picker:isActive() then self:cl_closePicker()
 elseif not self.lastMenuClose or sm.game.getCurrentTick()-self.lastMenuClose>2 then self:cl_open() end
 return true
end
function VaporatorDragTool.client_onReload(self) return false end
-- Native-region prototype: no whole-shape painting fallback.
function VaporatorDragTool.cl_traceCube(self)
 local hit,result=sm.localPlayer.getRaycast(7.5)
 if not hit or result.type~="body" then return nil end
 local shape=result:getShape()
 if not shape or not sm.exists(shape) or not shape.isBlock then return nil end
 local normal=sm.vec3.closestAxis(result.normalLocal)
 local q=result.pointLocal*4-normal*0.01
 local cell=sm.vec3.new(math.floor(q.x),math.floor(q.y),math.floor(q.z))
 return {shape=shape,body=shape.body,bodyId=shape.body.id,cell=cell,normal=normal,point=result.pointWorld}
end
function VaporatorDragTool.cl_hideSelection(self)
 for _,effect in ipairs(self.selectionCells or {}) do effect:stop() end
end
function VaporatorDragTool.cl_showSelection(self,trace,a,b)
 self.selectionCells=self.selectionCells or {}
 local lo=sm.vec3.new(math.min(a.x,b.x),math.min(a.y,b.y),math.min(a.z,b.z))
 local hi=sm.vec3.new(math.max(a.x,b.x),math.max(a.y,b.y),math.max(a.z,b.z))
 local count=(hi.x-lo.x+1)*(hi.y-lo.y+1)*(hi.z-lo.z+1)
 if count>256 then self:cl_hideSelection();return end
 local index=0
 for x=lo.x,hi.x do for y=lo.y,hi.y do for z=lo.z,hi.z do
  index=index+1;local effect=self.selectionCells[index]
  if not effect then
   effect=sm.effect.createEffect("ShapeRenderable")
   effect:setParameter("uuid",sm.uuid.new("a6c6ce30-dd47-4587-b475-085d55c6a3b4"))
   effect:setParameter("visualization",true)
   effect:setParameter("visualizationColor","Hand Place Valid")
   self.selectionCells[index]=effect
  end
  local centre=sm.vec3.new(x+0.5,y+0.5,z+0.5)*0.25
  effect:setPosition(trace.body:transformPoint(centre))
  effect:setRotation(trace.body.worldRotation)
  effect:setScale(sm.vec3.new(0.252,0.252,0.252))
  if not effect:isPlaying() then effect:start() end
 end end end
 for i=index+1,#self.selectionCells do self.selectionCells[i]:stop() end
end
function VaporatorDragTool.client_onEquippedUpdate(self,primary,secondary)
 if self.picker and self.picker:isActive() then self.drag=nil;self:cl_hideSelection();return true,true end
 local trace=self:cl_traceCube()
 if not self.traceReported then print("[VaporatorDrag 0.6] raycast cube",trace~=nil,"bridge",sm.paintStudioRegion~=nil);self.traceReported=true end
 sm.gui.setInteractionText("","LMB paint | RMB erase | Q colours | MMB copy colour")
 if sm.paintStudioPickPressed and sm.paintStudioPickPressed() then
  local hit,result=sm.localPlayer.getRaycast(7.5)
  local shape=hit and result.type=="body" and result:getShape() or nil
  if shape and sm.exists(shape) then
   self.colour=tostring(shape:getColor()):gsub("#",""):sub(1,6):lower()
   self:cl_tint(self.colour);self.network:sendToServer("sv_tint",self.colour)
   sm.gui.displayAlertText("Copied #"..self.colour:upper(),2)
  end
 end
 if primary==1 or secondary==1 then
  self.drag=trace and {trace=trace,a=trace.cell,b=trace.cell,erase=secondary==1} or nil
 end
 local drag=self.drag
 if drag then
  if not sm.exists(drag.trace.body) then self.drag=nil;self:cl_hideSelection();return true,true end
  if trace and trace.body==drag.trace.body then
   local a=drag.a;local b=trace.cell;local n=drag.trace.normal
   b=sm.vec3.new(n.x~=0 and a.x or math.max(a.x-31,math.min(a.x+31,b.x)),n.y~=0 and a.y or math.max(a.y-31,math.min(a.y+31,b.y)),n.z~=0 and a.z or math.max(a.z-31,math.min(a.z+31,b.z)))
   drag.b=b;drag.trace.point=trace.point
  end
  self:cl_showSelection(drag.trace,drag.a,drag.b)
  if (drag.erase and secondary==3) or (not drag.erase and primary==3) then
   if sm.paintStudioRegion then
    local t=drag.trace;local a=drag.a;local b=drag.b;local n=t.normal;local point=t.point
    local rr=tonumber(self.colour:sub(1,2),16);local gg=tonumber(self.colour:sub(3,4),16);local bb=tonumber(self.colour:sub(5,6),16)
    local ok,message=sm.paintStudioRegion(t.bodyId,point.x,point.y,point.z,n.x,n.y,n.z,a.x,a.y,a.z,b.x,b.y,b.z,drag.erase and 0 or (4278190080+bb*65536+gg*256+rr))
    if not ok then sm.gui.displayAlertText(message or "Native bridge rejected selection",4) end
   else sm.gui.displayAlertText("Native drag bridge is not attached; no paint applied",4) end
   self.drag=nil;self:cl_hideSelection()
  end
 elseif trace then
  self:cl_hideSelection()
  sm.visualization.setBlockVisualization(trace.cell,false,trace.shape)
 else self:cl_hideSelection() end
 return true,true
end
function VaporatorDragTool.sv_message(self,player,text) self.network:sendToClient(player,"cl_message",text) end
function VaporatorDragTool.cl_message(self,text) sm.gui.displayAlertText(text,3) end
function VaporatorDragTool.sv_paint(self,data,player)
 if type(data)~="table" or not validHex(data.colour) then return end
 if data.scope~="Shape" and data.scope~="Matching type" and data.scope~="Creation" then return end
 local owner=self.tool:getOwner();if owner~=player or not player.character then return end
 local tick=sm.game.getCurrentTick();if self.lastTick and tick-self.lastTick<8 then return end;self.lastTick=tick
 local character=player.character;local start=character.worldPosition+sm.vec3.new(0,0,0.5)
 local hit,result=sm.physics.raycast(start,start+character.direction*12,character)
 if not hit or result.type~="body" then return end
 local target=result:getShape();if not target or not sm.exists(target) then return end
 local shapes=data.scope=="Shape" and {target} or target.body:getCreationShapes()
 if #shapes>2000 then self:sv_message(player,"Creation too large (maximum 2000 shapes)");return end
 local changes={};local colour=sm.color.new(data.colour.."ff")
 for _,shape in ipairs(shapes) do
  if not shape.body:isPaintable() then self:sv_message(player,"Creation contains protected shapes");return end
  if data.scope~="Matching type" or shape.uuid==target.uuid then if shape:getColor()~=colour then changes[#changes+1]={shape=shape,before=shape:getColor(),after=colour} end end
 end
 if #changes==0 then return end
 for _,c in ipairs(changes) do c.shape:setColor(colour) end
 self.undo={player=player,changes=changes}
 self.network:sendToClients("cl_painted",{position=result.pointWorld,colour=data.colour})
end
function VaporatorDragTool.sv_undo(self,_,player)
 if self.tool:getOwner()~=player or not self.undo or self.undo.player~=player then return end
 for _,c in ipairs(self.undo.changes) do
  if sm.exists(c.shape) and c.shape.body:isPaintable() and c.shape:getColor()==c.after then c.shape:setColor(c.before) end
 end
 self.undo=nil;self:sv_message(player,"Last paint action undone")
end

function VaporatorDragTool.client_onUpdate(self,dt)
 if self.tool:isLocal() and self.picker and self.picker:isActive() and sm.paintStudioMenuDown then
  local down=sm.paintStudioMenuDown()
  if down and not self.menuQDown then self:cl_closePicker() end
  self.menuQDown=down
 end
 if self.tpAnimations then updateTpAnimations(self.tpAnimations,self.equipped,dt) end
 if self.fpAnimations and self.tool:isLocal() then updateFpAnimations(self.fpAnimations,self.equipped,dt) end
end

function VaporatorDragTool.cl_painted(self,data)
 -- Trigger only after the server has actually changed a shape.
 sm.effect.playEffect("Paintcharacter - Small",data.position,nil,nil,nil,{Color=sm.color.new(data.colour.."ff")})
 if self.tpAnimations then setTpAnimation(self.tpAnimations,"paint",10) end
 if self.tool:isLocal() and self.fpAnimations then setFpAnimation(self.fpAnimations,"paint",0.08) end
end

function VaporatorDragTool.cl_tint(self,hex)
 if not validHex(hex) then return end
 local colour=sm.color.new(hex.."ff")
 self.tool:setTpColor(colour)
 if self.tool:isLocal() then self.tool:setFpColor(colour) end
end
function VaporatorDragTool.sv_tint(self,hex,player)
 if self.tool:getOwner()~=player or not validHex(hex) then return end
 self.network:sendToClients("cl_tint",hex)
end
