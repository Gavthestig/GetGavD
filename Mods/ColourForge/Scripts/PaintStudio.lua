dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
-- Original Paint Studio implementation. No third-party mod code.
PaintStudio = class()
local charAnim="$GAME_DATA/Character/Char_Male/Animations/char_male_tp_painttool.rend"
local tpAnim="$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool_tp_animlist.rend"
local fpAnim="$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool_fp_animlist.rend"
local model = "$CONTENT_DATA/Objects/Vaporator/vaporator.rend"
sm.tool.preloadRenderables({model,tpAnim,fpAnim,charAnim})
local function validHex(s) return type(s)=="string" and #s==6 and s:match("^%x+$") end
function PaintStudio.client_onCreate(self)
 self.colour="30e8dc"; self.scope="Shape"; self.palette=1
 self.equipped=false
end
function PaintStudio.cl_open(self)
 if not self.tool:isLocal() then return end
 if not self.menu then
  self.menu=sm.json.open("$CONTENT_DATA/Gui/JsonGuis/Picker.gui")
 end
 self.widgets={}
 local function index(w) if w.Name then self.widgets[w.Name]=w end;for _,c in ipairs(w.Childs or {}) do index(c) end end
 index(self.menu)
 self.picker=sm.jsonGui.createGui({isInteractive=true,needsCursor=true,hidesHotbar=false})
 self:cl_renderPicker()
end
function PaintStudio.cl_renderPicker(self)
 self:cl_tint(self.colour)
 self.network:sendToServer("sv_tint",self.colour)
 local rr,gg,bb=tonumber(self.colour:sub(1,2),16),tonumber(self.colour:sub(3,4),16),tonumber(self.colour:sub(5,6),16)
 self.widgets.Hex.Caption=self.colour:upper()
 self.widgets.Preview.Colour=string.format("%f %f %f 1",rr/255,gg/255,bb/255)
 for i,v in ipairs({rr,gg,bb}) do self.widgets["Value"..i].Caption=tostring(v) end
 self.picker:render(self.menu)
end
function PaintStudio.cl_pickerHex(self,name,text)
 text=text:gsub("#","")
 if validHex(text) then self.colour=text:lower();self:cl_renderPicker() end
end
function PaintStudio.cl_pickerButton(self,name)
 if name=="Done" then self.picker:close();return end
 if name:sub(1,1)=="C" then self.colour=name:sub(2);self:cl_renderPicker();return end
 local axis,delta=name:match("^([123])([+-])$")
 if axis then
  local c={tonumber(self.colour:sub(1,2),16),tonumber(self.colour:sub(3,4),16),tonumber(self.colour:sub(5,6),16)}
  c[tonumber(axis)]=math.max(0,math.min(255,c[tonumber(axis)]+(delta=="+" and 1 or -1)))
  self.colour=string.format("%02x%02x%02x",c[1],c[2],c[3]);self:cl_renderPicker()
 end

end
function PaintStudio.cl_refresh(self)
 local p=self.palettes[self.palette]
 self.gui:setText("Palette",p.name.." / "..self.palette.." of "..#self.palettes)
 self.gui:setText("Hex",self.colour)
 self.gui:setText("Scope","Target: "..self.scope)
 self.gui:setColor("Preview",sm.color.new(self.colour.."ff"))
 for i,c in ipairs(p.colours) do self.gui:setColor("Chip"..i,sm.color.new(c.."ff")) end
end
function PaintStudio.cl_swatch(self,name)
 local i=tonumber(name:match("%d+")); if not i then return end
 self.colour=self.palettes[self.palette].colours[i]; self:cl_refresh()
end
function PaintStudio.cl_hex(self,name,text)
 text=text:gsub("#","")
 if validHex(text) then self.colour=text:lower(); self.gui:setColor("Preview",sm.color.new(text.."ff"));self.gui:setText("Status","Colour ready")
 else self.gui:setText("Status","Enter six hex digits, e.g. FF8800") end
end
function PaintStudio.cl_button(self,name)
 if name=="Previous" then self.palette=(self.palette-2)%#self.palettes+1
 elseif name=="Next" then self.palette=self.palette%#self.palettes+1
 elseif name=="Scope" then self.scope=({Shape="Matching type",["Matching type"]="Creation",Creation="Shape"})[self.scope]
 elseif name=="Undo" then self.network:sendToServer("sv_undo",{});return
 elseif name=="Close" then self.gui:close();return end
 self:cl_refresh()
end
function PaintStudio.client_onEquip(self)
 self.equipped=true
 self.tool:setTpRenderables({model,tpAnim,charAnim})
 self.tpAnimations=createTpAnimations(self.tool,{idle={"painttool_idle",{looping=true}},paint={"painttool_paint",{nextAnimation="idle"}}})
 setTpAnimation(self.tpAnimations,"idle",10)
 if self.tool:isLocal() then self.tool:setFpRenderables({model,fpAnim})
 self.fpAnimations=createFpAnimations(self.tool,{idle={"painttool_idle",{looping=true}},paint={"painttool_paint",{nextAnimation="idle",blendNext=0.1}}})
 setFpAnimation(self.fpAnimations,"idle",0.2) end
 self:cl_tint(self.colour)
end
function PaintStudio.client_onUnequip(self) self.equipped=false; self.drag=nil;self:cl_hideSelection(); if self.picker then self.picker:close() end end
function PaintStudio.client_onDestroy(self) if self.selectionEffect then self.selectionEffect:destroy() end; if self.picker then self.picker:close() end end
function PaintStudio.client_onReload(self) self.drag=nil;self:cl_hideSelection();self:cl_open();return true end
-- Native-region prototype: no whole-shape painting fallback.
function PaintStudio.cl_traceCube(self)
 local hit,result=sm.localPlayer.getRaycast(7.5)
 if not hit or result.type~="body" then return nil end
 local shape=result:getShape()
 if not shape or not sm.exists(shape) or not shape.isBlock then return nil end
 local normal=sm.vec3.closestAxis(result.normalLocal)
 local q=result.pointLocal*4-normal*0.01
 local cell=sm.vec3.new(math.floor(q.x),math.floor(q.y),math.floor(q.z))
 return {shape=shape,body=shape.body,bodyId=shape.body.id,cell=cell,normal=normal,point=result.pointWorld}
end
function PaintStudio.cl_hideSelection(self)
 if self.selectionEffect then self.selectionEffect:stop() end
end
function PaintStudio.cl_showSelection(self,trace,a,b)
 if not self.selectionEffect then
  self.selectionEffect=sm.effect.createEffect("ShapeRenderable")
  self.selectionEffect:setParameter("uuid",sm.uuid.new("a6c6ce30-dd47-4587-b475-085d55c6a3b4"))
  self.selectionEffect:setParameter("visualization",true)
 end
 local lo=sm.vec3.new(math.min(a.x,b.x),math.min(a.y,b.y),math.min(a.z,b.z))
 local hi=sm.vec3.new(math.max(a.x,b.x),math.max(a.y,b.y),math.max(a.z,b.z))
 local size=(hi-lo+sm.vec3.new(1,1,1))*0.25
 local centre=(lo+hi+sm.vec3.new(1,1,1))*0.125
 self.selectionEffect:setPosition(trace.body:transformPoint(centre))
 self.selectionEffect:setRotation(trace.body.worldRotation)
 self.selectionEffect:setScale(size+sm.vec3.new(0.006,0.006,0.006))
 if not self.selectionEffect:isPlaying() then self.selectionEffect:start() end
end
function PaintStudio.client_onEquippedUpdate(self,primary,secondary)
 if self.picker and self.picker:isActive() then self.drag=nil;self:cl_hideSelection();return true,true end
 local trace=self:cl_traceCube()
 sm.gui.setInteractionText("","LMB: drag selection, release to paint | RMB / R: colours")
 if primary==1 then
  self.drag=trace and {trace=trace,a=trace.cell,b=trace.cell} or nil
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
  if primary==3 then
   if sm.paintStudioRegion then
    local t=drag.trace;local a=drag.a;local b=drag.b;local n=t.normal;local point=t.point
    local rr=tonumber(self.colour:sub(1,2),16);local gg=tonumber(self.colour:sub(3,4),16);local bb=tonumber(self.colour:sub(5,6),16)
    local ok,message=sm.paintStudioRegion(t.bodyId,point.x,point.y,point.z,n.x,n.y,n.z,a.x,a.y,a.z,b.x,b.y,b.z,4278190080+bb*65536+gg*256+rr)
    if not ok then sm.gui.displayAlertText(message or "Native bridge rejected selection",4) end
   else sm.gui.displayAlertText("Native drag bridge is not attached; no paint applied",4) end
   self.drag=nil;self:cl_hideSelection()
  end
 elseif trace then self:cl_showSelection(trace,trace.cell,trace.cell)
 else self:cl_hideSelection() end
 if secondary==1 then self.drag=nil;self:cl_hideSelection();self:cl_open() end
 return true,true
end
function PaintStudio.sv_message(self,player,text) self.network:sendToClient(player,"cl_message",text) end
function PaintStudio.cl_message(self,text) sm.gui.displayAlertText(text,3) end
function PaintStudio.sv_paint(self,data,player)
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
function PaintStudio.sv_undo(self,_,player)
 if self.tool:getOwner()~=player or not self.undo or self.undo.player~=player then return end
 for _,c in ipairs(self.undo.changes) do
  if sm.exists(c.shape) and c.shape.body:isPaintable() and c.shape:getColor()==c.after then c.shape:setColor(c.before) end
 end
 self.undo=nil;self:sv_message(player,"Last paint action undone")
end

function PaintStudio.client_onUpdate(self,dt)
 if self.tpAnimations then updateTpAnimations(self.tpAnimations,self.equipped,dt) end
 if self.fpAnimations and self.tool:isLocal() then updateFpAnimations(self.fpAnimations,self.equipped,dt) end
end

function PaintStudio.cl_painted(self,data)
 -- Trigger only after the server has actually changed a shape.
 sm.effect.playEffect("Paintcharacter - Small",data.position,nil,nil,nil,{Color=sm.color.new(data.colour.."ff")})
 if self.tpAnimations then setTpAnimation(self.tpAnimations,"paint",10) end
 if self.tool:isLocal() and self.fpAnimations then setFpAnimation(self.fpAnimations,"paint",0.08) end
end

function PaintStudio.cl_tint(self,hex)
 if not validHex(hex) then return end
 local colour=sm.color.new(hex.."ff")
 self.tool:setTpColor(colour)
 if self.tool:isLocal() then self.tool:setFpColor(colour) end
end
function PaintStudio.sv_tint(self,hex,player)
 if self.tool:getOwner()~=player or not validHex(hex) then return end
 self.network:sendToClients("cl_tint",hex)
end
