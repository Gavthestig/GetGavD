dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
ColourForgePaintball = class()
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

function ColourForgePaintball.cl_open(self)
 if not self.tool:isLocal() then return end
 self:cl_setAim(false)
 if not self.menu then
  self.menu=sm.json.open("$CONTENT_DATA/Gui/JsonGuis/PaintballPicker.gui")
 end
 self.menuQDown=true
 self.widgets={}
 local function index(w) if w.Name then self.widgets[w.Name]=w end;for _,c in ipairs(w.Childs or {}) do index(c) end end
 index(self.menu)
 self.picker=sm.jsonGui.createGui({isInteractive=true,needsCursor=true,hidesHotbar=false})
 self:cl_renderPicker()
end
function ColourForgePaintball.cl_renderPicker(self)
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
function ColourForgePaintball.cl_pickerHex(self,name,text)
 text=text:gsub("#","")
 if validHex(text) then self.colour=text:lower();self:cl_renderPicker() end
end
function ColourForgePaintball.cl_number(self,name,text)
 local axis=tonumber(name:match("%d+"));local value=tonumber(text)
 if not axis or not value then return end
 local c={tonumber(self.colour:sub(1,2),16),tonumber(self.colour:sub(3,4),16),tonumber(self.colour:sub(5,6),16)}
 c[axis]=math.max(0,math.min(255,math.floor(value+0.5)))
 self.colour=string.format("%02x%02x%02x",c[1],c[2],c[3]);self:cl_renderPicker()
end
function ColourForgePaintball.cl_pickerDrag(self,name,x,y)
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
function ColourForgePaintball.cl_pickerButton(self,name)
 if name=="Done" then self.network:sendToServer("sv_tint",self.colour);self.picker:close();return end
 if name:sub(1,1)=="C" then self.colour=name:sub(2);self:cl_renderPicker() end
end
function ColourForgePaintball.cl_closePicker(self)
 self.network:sendToServer("sv_tint",self.colour)
 self.picker:close();self.lastMenuClose=sm.game.getCurrentTick()
end
-- Paintballs are server-simulated, harmless, and independent of the ColourForge DLL.
local BALL = sm.uuid.new("afae6b7c-7825-45aa-8cf5-c9bf2cd7cbbc")
local SPLAT = sm.uuid.new("57bf01a3-a5fd-4a68-b8cf-bc83ce699049")
local MODEL = "$CONTENT_DATA/Objects/Paintball/gun.rend"
local FP = "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
local TP = "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
local ARMS = "$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend"
local CAPACITY, RELOAD, SPEED, COOLDOWN = 50, 2.4, 48, 0.15
local GRAVITY = sm.vec3.new(0,0,-6)
local HIT_MASK = sm.physics.filter.staticBody + sm.physics.filter.dynamicBody + sm.physics.filter.character + sm.physics.filter.terrainSurface + sm.physics.filter.terrainAsset + sm.physics.filter.harvestable
local MARK_LIFE, MAX_MARKS = 120, 180
sm.tool.preloadRenderables({MODEL,FP,TP,ARMS})

local function safeDestroy(effect) if effect then effect:destroy() end end
local function renderShape(uuid,colour,scale,firstPerson)
 local e=firstPerson and sm.effect.createEffectFirstPerson("ShapeRenderable") or sm.effect.createEffect("ShapeRenderable")
 e:setParameter("uuid",uuid);e:setParameter("color",sm.color.new(colour.."ff"))
 e:setScale(sm.vec3.new(scale,scale,scale));return e
end
local function finiteVector(v)
 return v and v.x==v.x and v.y==v.y and v.z==v.z and math.abs(v.x)<100000 and math.abs(v.y)<100000 and math.abs(v.z)<100000
end
local function charFrame(character)
 local direction=character.direction
 local f=sm.vec3.new(direction.x,direction.y,0)
 if f:length()<0.001 then f=sm.vec3.new(0,1,0) else f=f:normalize() end
 return sm.vec3.getRotation(sm.vec3.new(0,1,0),f)
end
function ColourForgePaintball.client_onCreate(self)
 self.colour="ff28a6";self.equipped=false;self.ammo=CAPACITY;self.reloadTime=0
 self.aiming=false;self.aimWeight=0
 self.cooldown=0;self.balls={};self.marks={};self.pour={};self.age=0
end
function ColourForgePaintball.server_onCreate(self)
 self.sv={ammo=CAPACITY,reload=0,cooldown=0,shots={},nextId=0}
end
function ColourForgePaintball.sv_tint(self,hex,player)
 if self.tool:getOwner()~=player or not validHex(hex) then return end
 self.sv.colour=hex
 self.network:sendToClients("cl_colour",hex)
end
function ColourForgePaintball.cl_colour(self,hex)
 if validHex(hex) then self.colour=hex end
end
function ColourForgePaintball.cl_tint(self,hex)
 -- Gun keeps its model's original colours; only the ammunition and splats are tinted.
end
function ColourForgePaintball.client_onEquip(self)
 self.equipped=true
 self.tool:setTpRenderables({MODEL,TP,ARMS})
 self.tpAnimations=createTpAnimations(self.tool,{idle={"spudgun_idle",{looping=true}},shoot={"spudgun_shoot",{nextAnimation="idle"}},refill={"spudgun_pickup",{nextAnimation="idle"}}})
 setTpAnimation(self.tpAnimations,"idle",5)
 if self.tool:isLocal() then
  self.tool:setFpRenderables({MODEL,FP})
  self.fpAnimations=createFpAnimations(self.tool,{idle={"spudgun_idle",{looping=true}},shoot={"spudgun_shoot",{nextAnimation="idle"}},refill={"spudgun_pickup",{nextAnimation="idle"}},aimInto={"spudgun_aim_into",{nextAnimation="aimIdle"}},aimExit={"spudgun_aim_exit",{nextAnimation="idle"}},aimIdle={"spudgun_aim_idle",{looping=true}},aimShoot={"spudgun_aim_shoot",{nextAnimation="aimIdle"}}})
  setFpAnimation(self.fpAnimations,"idle",.2)
  self.network:sendToServer("sv_sync",{})
 end
end
function ColourForgePaintball.sv_sync(self,args,player)
 if player==self.tool:getOwner() then self.network:sendToClient(player,"cl_ammo",{ammo=self.sv.ammo,reload=self.sv.reload}) end
end
function ColourForgePaintball.client_onUnequip(self)
 self:cl_setAim(false)
 self.aimWeight=0
 if self.tool:isLocal() then self.tool:updateCamera(2.8,30,sm.vec3.new(.65,0,.05),0);self.tool:updateFpCamera(30,sm.vec3.new(0,0,0),0,1) end
 self.equipped=false
 if self.picker then self.picker:close() end
 for _,p in ipairs(self.pour) do safeDestroy(p) end;self.pour={}
end
function ColourForgePaintball.client_onDestroy(self)
 if self.picker then self.picker:close() end
 for _,b in pairs(self.balls or {}) do safeDestroy(b.effect) end
 for _,m in ipairs(self.marks or {}) do safeDestroy(m.effect) end
 for _,p in ipairs(self.pour or {}) do safeDestroy(p) end
end
function ColourForgePaintball.client_onToggle(self)
 if self.picker and self.picker:isActive() then self:cl_closePicker()
 elseif not self.lastMenuClose or sm.game.getCurrentTick()-self.lastMenuClose>2 then self:cl_open() end
 return true
end
function ColourForgePaintball.client_onReload(self)
 if self.tool:isLocal() and not (self.picker and self.picker:isActive()) then self.network:sendToServer("sv_reload",{}) end
 return true
end
function ColourForgePaintball.sv_reload(self,args,player)
 if self.tool:getOwner()~=player or self.sv.reload>0 or self.sv.ammo>=CAPACITY then return end
 self.sv.reload=RELOAD
 self.network:sendToClients("cl_reload",{colour=self.colour or "ff28a6"})
 self.network:sendToClient(player,"cl_ammo",{ammo=self.sv.ammo,reload=RELOAD})
end
function ColourForgePaintball.cl_reload(self,data)
 self:cl_setAim(false)
 self.reloadTime=RELOAD
 if self.tpAnimations then setTpAnimation(self.tpAnimations,"refill",5) end
 if self.tool:isLocal() and self.fpAnimations then setFpAnimation(self.fpAnimations,"refill",.12) end
 for _,p in ipairs(self.pour) do safeDestroy(p) end;self.pour={}
 self.pourIsFp=self.tool:isLocal() and self.tool:isInFirstPersonView()
 for i=1,12 do self.pour[i]=renderShape(BALL,self.colour,.025,self.pourIsFp) end
end
function ColourForgePaintball.cl_ammo(self,data)
 self.ammo=data.ammo;self.reloadTime=data.reload
end
function ColourForgePaintball.cl_setAim(self,aiming)
 if self.aiming==aiming then return end
 self.aiming=aiming
 if self.tool:isLocal() then
  self.tool:setMovementSlowDown(aiming)
  if self.fpAnimations then setFpAnimation(self.fpAnimations,aiming and "aimInto" or "aimExit",.12) end
 end
end
function ColourForgePaintball.cl_gunFrame(self)
 if self.tool:isLocal() and self.tool:isInFirstPersonView() then
  return self.tool:getFpBonePos("root_spudgun"),self.tool:getFpBoneRot("root_spudgun")
 end
 return self.tool:getTpBonePos("root_spudgun"),self.tool:getTpBoneRot("root_spudgun")
end
function ColourForgePaintball.cl_updateAim(self,dt)
 if not self.tool:isLocal() or not self.equipped then return end
 local target=self.aiming and 1 or 0
 self.aimWeight=self.aimWeight+(target-self.aimWeight)*(1-math.exp(-10*dt))
 self.tool:updateCamera(2.8,30,sm.vec3.new(.65,0,.05),self.aimWeight)
 self.tool:updateFpCamera(30,sm.vec3.new(0,0,0),self.aimWeight,self.aiming and .12 or 1)
end
function ColourForgePaintball.client_onEquippedUpdate(self,primary,secondary)
 if self.picker and self.picker:isActive() then self:cl_setAim(false);return true,true end
 self:cl_setAim((secondary==1 or secondary==2) and self.reloadTime<=0)
 local label=self.reloadTime>0 and "Refilling hopper..." or ("Paintballs "..self.ammo.." / "..CAPACITY)
 sm.gui.setInteractionText("",label.."  |  R refill  |  Q colours")
 if (primary==1 or primary==2) and self.cooldown<=0 and self.reloadTime<=0 then
  self.cooldown=COOLDOWN
  if self.ammo<=0 then self.network:sendToServer("sv_reload",{});return true,true end
  local camera=sm.camera.getPosition();local direction=sm.camera.getDirection()
  local hit,result=sm.localPlayer.getRaycast(100)
  local target=hit and result.pointWorld or camera+direction*100
  local gunPosition,gunRotation=self:cl_gunFrame()
  local origin=gunPosition+gunRotation*sm.vec3.new(0,.1375,.735)
  local aim=target-origin
  if aim:length()>0.01 then aim=aim:normalize() else aim=direction end
  self.network:sendToServer("sv_fire",{origin=origin,direction=aim,colour=self.colour})
 end
 return true,true
end
function ColourForgePaintball.sv_fire(self,data,player)
 if self.tool:getOwner()~=player or not player.character or not self.sv then return end
 if self.sv.cooldown>0 or self.sv.reload>0 or self.sv.ammo<=0 then return end
 if not validHex(data.colour) or not finiteVector(data.origin) or not finiteVector(data.direction) then return end
 if (data.origin-player.character.worldPosition):length()>3 then return end
 local length=data.direction:length();if length<.5 or length>1.5 then return end
 -- Never start past a wall immediately in front of the character.
 local head=player.character.worldPosition+sm.vec3.new(0,0,.5)
 local obstructed,block=sm.physics.raycast(head,data.origin,player.character,HIT_MASK,player.character:getWorld())
 local origin=obstructed and block.pointWorld-data.direction*.03 or data.origin
 self.sv.cooldown=COOLDOWN;self.sv.ammo=self.sv.ammo-1;self.sv.nextId=self.sv.nextId+1
 local shot={id=self.sv.nextId,position=origin,velocity=data.direction:normalize()*SPEED,colour=data.colour,age=0}
 self.sv.shots[shot.id]=shot
 self.network:sendToClients("cl_shot",shot)
 self.network:sendToClient(player,"cl_ammo",{ammo=self.sv.ammo,reload=0})
end
function ColourForgePaintball.cl_shot(self,data)
 local e=renderShape(BALL,data.colour,.045);e:setPosition(data.position);e:start()
 self.balls[data.id]={effect=e,position=data.position,velocity=data.velocity,age=0}
 if self.tpAnimations then setTpAnimation(self.tpAnimations,"shoot",10) end
 if self.tool:isLocal() and self.fpAnimations then setFpAnimation(self.fpAnimations,self.aiming and "aimShoot" or "shoot",.08) end
 sm.audio.play("PotatoRifle - Shoot",data.position)
end
function ColourForgePaintball.server_onFixedUpdate(self,dt)
 if not self.sv then return end
 self.sv.cooldown=math.max(0,self.sv.cooldown-dt)
 if self.sv.reload>0 then
  self.sv.reload=math.max(0,self.sv.reload-dt)
  if self.sv.reload==0 then
   self.sv.ammo=CAPACITY
   local owner=self.tool:getOwner();if owner then self.network:sendToClient(owner,"cl_ammo",{ammo=CAPACITY,reload=0}) end
  end
 end
 for id,b in pairs(self.sv.shots) do
  local nextPos=b.position+b.velocity*dt+GRAVITY*(.5*dt*dt)
  local owner=self.tool:getOwner();local ignore=owner and owner.character or nil
  local world=ignore and ignore:getWorld() or nil
  local hit,result=sm.physics.spherecast(b.position,nextPos,.0225,ignore,HIT_MASK,world)
  b.age=b.age+dt
  if hit then
   local normal=result.normalWorld
   if not normal or normal:length()<.001 then normal=-b.velocity:normalize() else normal=normal:normalize() end
   if normal:dot(b.velocity)>0 then normal=-normal end
   local data={id=id,position=result.pointWorld,normal=normal,colour=b.colour,life=MARK_LIFE,surfaceType=result.type}
   print("[ColourForge Paintball] impact",result.type,data.position,data.normal)
   if result.type=="body" then
    local shape=result:getShape()
    if shape and sm.exists(shape) then
     data.body=shape.body;data.anchor=data.body.worldPosition
     data.localPoint=sm.quat.inverse(data.body.worldRotation)*(data.position-data.anchor)
     data.localNormal=sm.quat.inverse(data.body.worldRotation)*data.normal
    end
   elseif result.type=="character" then
    local character=result:getCharacter()
    if character and sm.exists(character) then
     data.character=character;local rot=charFrame(character)
     data.localPoint=sm.quat.inverse(rot)*(data.position-character.worldPosition)
     data.localNormal=sm.quat.inverse(rot)*data.normal
    end
   end
   self.network:sendToClients("cl_impact",data);self.sv.shots[id]=nil
  elseif b.age>3 then
   self.network:sendToClients("cl_expire",{id=id});self.sv.shots[id]=nil
  else b.position=nextPos;b.velocity=b.velocity+GRAVITY*dt end
 end
end
function ColourForgePaintball.cl_expire(self,data)
 local b=self.balls[data.id];if b then safeDestroy(b.effect);self.balls[data.id]=nil end
end
function ColourForgePaintball.cl_impact(self,data)
 self:cl_expire(data)
 if not data.normal or data.normal:length()<.001 then data.normal=sm.vec3.new(0,0,1) end
 data.offset=(data.surfaceType=="body" or data.surfaceType=="character") and .008 or .035
 data.effect=renderShape(SPLAT,data.colour,data.size or .23);data.age=0
 data.effect:setPosition(data.position+data.normal*data.offset)
 data.effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0,0,1),data.normal));data.effect:start()
 self.marks[#self.marks+1]=data
 if #self.marks>(self.maxMarks or MAX_MARKS) then safeDestroy(self.marks[1].effect);table.remove(self.marks,1) end
end
function ColourForgePaintball.cl_updateMarks(self,dt)
 for i=#self.marks,1,-1 do
  local m=self.marks[i];m.age=m.age+dt;local remove=m.age>=MARK_LIFE
  if m.body then
   if sm.exists(m.body) then m.position=m.body.worldPosition+m.body.worldRotation*m.localPoint;m.normal=m.body.worldRotation*m.localNormal else remove=true end
  elseif m.character then
   if sm.exists(m.character) then local rot=charFrame(m.character);m.position=m.character.worldPosition+rot*m.localPoint;m.normal=rot*m.localNormal else remove=true end
  end
  if remove then safeDestroy(m.effect);table.remove(self.marks,i)
  else
   m.effect:setPosition(m.position+m.normal*(m.offset or .035));m.effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0,0,1),m.normal))
   if m.age>MARK_LIFE-2 then local size=(m.size or .23)*math.max(0,(MARK_LIFE-m.age)/2);m.effect:setScale(sm.vec3.new(size,size,size)) end
  end
 end
end
function ColourForgePaintball.cl_updatePour(self)
 if self.reloadTime<=0 or not self.equipped then
  for _,p in ipairs(self.pour) do safeDestroy(p) end;self.pour={};return
 end
 if #self.pour==0 then return end
 local first=self.tool:isLocal() and self.tool:isInFirstPersonView()
 if first~=self.pourIsFp then
  for _,e in ipairs(self.pour) do safeDestroy(e) end
  self.pour={};self.pourIsFp=first
  for i=1,12 do self.pour[i]=renderShape(BALL,self.colour,.025,first) end
 end
 -- FP effects and raw FP bone transforms use the same camera/render pass as the gun.
 local gunPosition,gunRotation
 if first then gunPosition=self.tool:getFpBonePos("root_spudgun",false);gunRotation=self.tool:getFpBoneRot("root_spudgun",false)
 else gunPosition=self.tool:getTpBonePos("root_spudgun");gunRotation=self.tool:getTpBoneRot("root_spudgun") end
 -- The rear top opening is centred at GLB (0.001,0.271,-0.171), not the hopper centre.
 local hopper=gunPosition+gunRotation*sm.vec3.new(.001,.38,-.091)
 for i,e in ipairs(self.pour) do
  local phase=((RELOAD-self.reloadTime)*2.3+i/12)%1
  local spread=(1-phase)*.04
  e:setPosition(hopper+gunRotation*sm.vec3.new(math.sin(i*2.4)*spread,.32*(1-phase*phase),math.cos(i*2.4)*spread))
  if not e:isPlaying() then e:start() end
 end
end
function ColourForgePaintball.client_onUpdate(self,dt)
 self.age=self.age+dt;self.cooldown=math.max(0,self.cooldown-dt);self.reloadTime=math.max(0,self.reloadTime-dt)
 if self.tpAnimations then updateTpAnimations(self.tpAnimations,self.equipped,dt) end
 if self.fpAnimations and self.tool:isLocal() then updateFpAnimations(self.fpAnimations,self.equipped,dt) end
 for id,b in pairs(self.balls) do
  b.position=b.position+b.velocity*dt+GRAVITY*(.5*dt*dt);b.velocity=b.velocity+GRAVITY*dt;b.age=b.age+dt
  if b.age>3.5 then safeDestroy(b.effect);self.balls[id]=nil else b.effect:setPosition(b.position) end
 end
 self:cl_updateMarks(dt);self:cl_updatePour();self:cl_updateAim(dt)
 if self.tool:isLocal() and self.picker and self.picker:isActive() and sm.paintStudioMenuDown then
  local down=sm.paintStudioMenuDown();if down and not self.menuQDown then self:cl_closePicker() end;self.menuQDown=down
 end
end
