dofile("$CONTENT_DATA/Scripts/ColourForgePaintball.lua")
ColourForgeGrenade = class(ColourForgePaintball)
local PAINT_SHAPE=sm.uuid.new("b0ce65d5-e911-4324-8b8e-c72d9ec8ef3e")
local SMOKE_SHAPE=sm.uuid.new("e3d67496-3e19-4480-87bf-23bb4fb06bb9")
local FP="$SURVIVAL_DATA/Character/Char_Cornade/char_cornade_fp_animlist.rend"
local FP_ARMS="$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_cornade.rend"
local TP="$SURVIVAL_DATA/Character/Char_Cornade/char_cornade_tp_animlist.rend"
local TP_ARMS="$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_cornade.rend"
local MASK=sm.physics.filter.staticBody+sm.physics.filter.dynamicBody+sm.physics.filter.character+sm.physics.filter.terrainSurface+sm.physics.filter.terrainAsset+sm.physics.filter.harvestable
local GRAVITY=sm.vec3.new(0,0,-10)
local function validColour(s)return type(s)=="string" and #s==6 and s:match("^%x+$")end
local function shapeEffect(uuid)
 local e=sm.effect.createEffect("ShapeRenderable");e:setParameter("uuid",uuid);e:setScale(sm.vec3.new(1,1,1));return e
end
function ColourForgeGrenade.client_onCreate(self)
 ColourForgePaintball.client_onCreate(self)
 self.grenades={};self.clouds={};self.throwCooldown=0;self.maxMarks=360
 if self.isSmoke then self.colour="ffffff" end
end
function ColourForgeGrenade.server_onCreate(self)
 self.sv={grenades={},nextId=0,cooldown=0,colour="ff28a6"}
end
function ColourForgeGrenade.cl_open(self)
 if not self.menu then self.menu=sm.json.open(self.isSmoke and "$CONTENT_DATA/Gui/JsonGuis/SmokePicker.gui" or "$CONTENT_DATA/Gui/JsonGuis/GrenadePicker.gui") end
 return ColourForgePaintball.cl_open(self)
end
function ColourForgeGrenade.cl_tint(self,hex)
 if self.isSmoke or not validColour(hex) then return end
 local colour=sm.color.new(hex.."ff")
 self.tool:setTpColor(colour)
 if self.tool:isLocal() then self.tool:setFpColor(colour)end
end
function ColourForgeGrenade.cl_colour(self,hex)
 if validColour(hex)then self.colour=hex;self:cl_tint(hex)end
end
function ColourForgeGrenade.client_onEquip(self)
 self.equipped=true
 local model="$CONTENT_DATA/Objects/Grenades/"..(self.isSmoke and "smoke" or "paint").."-held.rend"
 self.tool:setTpRenderables({model,TP,TP_ARMS})
 self.tpAnimations=createTpAnimations(self.tool,{idle={"cornade_idle",{looping=true}},throw={"cornade_throw",{nextAnimation="idle"}}})
 setTpAnimation(self.tpAnimations,"idle",5)
 if self.tool:isLocal() then
  self.tool:setFpRenderables({model,FP,FP_ARMS})
  self.fpAnimations=createFpAnimations(self.tool,{idle={"cornade_idle",{looping=true}},throw={"cornade_throw",{nextAnimation="idle"}}})
  setFpAnimation(self.fpAnimations,"idle",.1)
 end
 self:cl_tint(self.colour)
end
function ColourForgeGrenade.client_onUnequip(self)
 self.equipped=false;if self.picker then self.picker:close() end
end
function ColourForgeGrenade.client_onReload(self)return false end
function ColourForgeGrenade.client_onToggle(self)
 return ColourForgePaintball.client_onToggle(self)
end
function ColourForgeGrenade.client_onEquippedUpdate(self,primary,secondary)
 if self.picker and self.picker:isActive() then return true,true end
 sm.gui.setInteractionText("",self.isSmoke and "LMB throw smoke grenade  |  Q smoke colour" or "LMB throw paint grenade  |  Q colour")
 if primary==1 and self.throwCooldown<=0 then
  self.throwCooldown=1
  local owner=self.tool:getOwner();local direction=sm.camera.getDirection()
  self.network:sendToServer("sv_throw",{direction=direction,colour=self.colour})
 end
 return true,true
end
function ColourForgeGrenade.sv_throw(self,data,player)
 if self.tool:getOwner()~=player or not player.character or self.sv.cooldown>0 then return end
 if not data.direction or not validColour(data.colour) then return end
 local d=data.direction;local length=d:length()
 if length~=length or length<.5 or length>1.5 then return end
 local count=0;for _ in pairs(self.sv.grenades)do count=count+1 end;if count>=4 then return end
 d=d:normalize();self.sv.cooldown=1;self.sv.nextId=self.sv.nextId+1
 local character=player.character;local position=character.worldPosition+sm.vec3.new(0,0,.55)
 local g={id=self.sv.nextId,position=position,velocity=d*14+sm.vec3.new(0,0,2.5),colour=data.colour,age=0,world=character:getWorld()}
 self.sv.grenades[g.id]=g
 self.network:sendToClients("cl_throw",{id=g.id,position=g.position,velocity=g.velocity,colour=g.colour})
end
function ColourForgeGrenade.cl_throw(self,data)
 local e=shapeEffect(self.isSmoke and SMOKE_SHAPE or PAINT_SHAPE);if not self.isSmoke then e:setParameter("color",sm.color.new(data.colour.."ff"))end;e:setPosition(data.position);e:start()
 self.grenades[data.id]={effect=e,position=data.position,velocity=data.velocity,age=0,angle=0,resting=false}
 if self.tpAnimations then setTpAnimation(self.tpAnimations,"throw",8) end
 if self.tool:isLocal() and self.fpAnimations then setFpAnimation(self.fpAnimations,"throw",.08) end
end
function ColourForgeGrenade.cl_grenadeState(self,data)
 local g=self.grenades[data.id];if g then g.position=g.position*.4+data.position*.6;g.velocity=data.velocity;g.resting=data.resting end
end
function ColourForgeGrenade.sv_makeMark(self,result,colour)
 local normal=result.normalWorld
 if not normal or normal:length()<.001 then normal=sm.vec3.new(0,0,1) end
 local data={id=-1,position=result.pointWorld,normal=normal,colour=colour,surfaceType=result.type,size=.36}
 if result.type=="body" then
  local shape=result:getShape()
  if shape and sm.exists(shape) then
   data.body=shape.body;local inv=sm.quat.inverse(data.body.worldRotation)
   data.localPoint=inv*(data.position-data.body.worldPosition);data.localNormal=inv*normal
  end
 elseif result.type=="character" then
  local character=result:getCharacter()
  if character and sm.exists(character) then
   local f=character.direction;f=sm.vec3.new(f.x,f.y,0);if f:length()<.001 then f=sm.vec3.new(0,1,0)else f=f:normalize()end
   local rot=sm.vec3.getRotation(sm.vec3.new(0,1,0),f);data.character=character
   data.localPoint=sm.quat.inverse(rot)*(data.position-character.worldPosition);data.localNormal=sm.quat.inverse(rot)*normal
  end
 end
 return data
end
function ColourForgeGrenade.sv_burstPaint(self,g)
 local marks={};local centre=g.position+sm.vec3.new(0,0,.12)
 -- Fibonacci directions cover walls, floor, objects and characters, with line-of-sight.
 for i=0,239 do
  local z=1-2*(i+.5)/240;local r=math.sqrt(1-z*z);local angle=i*2.39996323
  local d=sm.vec3.new(math.cos(angle)*r,math.sin(angle)*r,z)
  local hit,result=sm.physics.raycast(centre,centre+d*4,nil,MASK,g.world)
  if hit then marks[#marks+1]=self:sv_makeMark(result,g.colour) end
 end
 -- Explicit character samples avoid missing narrow players/animals between radial rays.
 local contacts=sm.physics.getSphereContacts(centre,4,g.world,sm.physics.filter.character)
 local sampled=0
 for _,character in ipairs(contacts.characters)do
  if sm.exists(character) and sampled<16 then
   local target=character.worldPosition+sm.vec3.new(0,0,.25)
   local delta=target-centre
   if delta:length()>.01 then
    local hit,result=sm.physics.raycast(centre,target+delta:normalize()*.3,nil,MASK,g.world)
    if hit and result.type=="character" and result:getCharacter()==character then marks[#marks+1]=self:sv_makeMark(result,g.colour)end
   end
   sampled=sampled+1
  end
 end
 self.network:sendToClients("cl_paintBurst",{position=g.position,colour=g.colour,marks=marks})
end
function ColourForgeGrenade.cl_paintBurst(self,data)
 for _,mark in ipairs(data.marks)do self:cl_impact(mark)end
end
function ColourForgeGrenade.server_onFixedUpdate(self,dt)
 if not self.sv then return end
 self.sv.cooldown=math.max(0,self.sv.cooldown-dt)
 for id,g in pairs(self.sv.grenades)do
  g.age=g.age+dt
  if not g.resting then
  local nextPos=g.position+g.velocity*dt+GRAVITY*(.5*dt*dt)
  local owner=self.tool:getOwner();local ignore=g.age<.35 and owner and owner.character or nil
  local hit,result=sm.physics.spherecast(g.position,nextPos,.055,ignore,MASK,g.world)
  if hit then
   local n=result.normalWorld
   if n and n:length()>.001 then
    g.position=result.pointWorld+n*.065
    g.velocity=(g.velocity-n*(2*g.velocity:dot(n)))*.38
    if n.z>.55 and g.velocity:length()<1 then g.velocity=sm.vec3.new(0,0,0);g.resting=true end
   else g.position=nextPos;g.velocity=sm.vec3.new(0,0,0) end
  else g.position=nextPos;g.velocity=g.velocity+GRAVITY*dt end
  end
  if g.age>=2.5 then
   self.network:sendToClients("cl_detonate",{id=id,position=g.position,colour=g.colour})
   if not self.isSmoke then self:sv_burstPaint(g) end
   self.sv.grenades[id]=nil
  elseif math.floor(g.age*10)~=math.floor((g.age-dt)*10)then
   self.network:sendToClients("cl_grenadeState",{id=id,position=g.position,velocity=g.velocity,resting=g.resting})
  end
 end
end
function ColourForgeGrenade.cl_smokeEffectName(self,hex)
 if not validColour(hex) then hex="ffffff" end
 local channels={}
 for i=1,5,2 do
  local value=tonumber(hex:sub(i,i+1),16)
  local level=math.floor(value*7/255+.5)
  channels[#channels+1]=math.floor(level*255/7+.5)
 end
 return string.format("ColourForge Cover Smoke %02x%02x%02x",channels[1],channels[2],channels[3])
end
function ColourForgeGrenade.cl_detonate(self,data)
 local g=self.grenades[data.id];if g then g.effect:destroy();self.grenades[data.id]=nil end
 if self.isSmoke then
  local e=sm.effect.createEffect(self:cl_smokeEffectName(data.colour));e:setPosition(data.position);e:start()
  self.clouds[#self.clouds+1]={effect=e,age=0}
  if #self.clouds>4 then self.clouds[1].effect:destroy();table.remove(self.clouds,1) end
 end
end
function ColourForgeGrenade.client_onUpdate(self,dt)
 self.throwCooldown=math.max(0,self.throwCooldown-dt)
 if self.tpAnimations then updateTpAnimations(self.tpAnimations,self.equipped,dt) end
 if self.fpAnimations and self.tool:isLocal() then updateFpAnimations(self.fpAnimations,self.equipped,dt) end
 for _,g in pairs(self.grenades)do
  if not g.resting then
   g.position=g.position+g.velocity*dt+GRAVITY*(.5*dt*dt);g.velocity=g.velocity+GRAVITY*dt
   g.angle=g.angle+math.rad(160)*dt
  end
  g.age=g.age+dt
  g.effect:setPosition(g.position);g.effect:setRotation(sm.quat.angleAxis(g.angle,sm.vec3.new(1,0,0)))
 end
 self:cl_updateMarks(dt)
 for i=#self.clouds,1,-1 do local c=self.clouds[i];c.age=c.age+dt;if c.age>=16 then c.effect:destroy();table.remove(self.clouds,i)end end
 if self.tool:isLocal() and self.picker and self.picker:isActive() and sm.paintStudioMenuDown then
  local down=sm.paintStudioMenuDown();if down and not self.menuQDown then self:cl_closePicker()end;self.menuQDown=down
 end
end
function ColourForgeGrenade.client_onDestroy(self)
 ColourForgePaintball.client_onDestroy(self)
 for _,g in pairs(self.grenades or {})do g.effect:destroy()end
 for _,c in ipairs(self.clouds or {})do c.effect:destroy()end
end
