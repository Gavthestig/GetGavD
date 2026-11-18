
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <math.h>
#include <MinHook.h>
#pragma comment(lib,"user32.lib")
static uintptr_t applyRva,constructRva,updateRva,vtableRva,modeRva;
static uintptr_t base;static void* nativeContext;static int armedBody=-1;static HMODULE module;
struct Region{int body,type;float hit[3];int normal[3],a[3],b[3],pad[2];};static_assert(sizeof(Region)==64,"Region size");
using Apply=uintptr_t(*)(void*,Region*,uint32_t);static Apply originalApply;
using Pcall=int(*)(void*,int,int,int);static Pcall originalPcall;
static int(*gettop)(void*);static void(*settop)(void*,int);static void(*getfenv)(void*,int);static void(*getfield)(void*,int,const char*);static void(*setfield)(void*,int,const char*);static int(*type)(void*,int);static double(*tonumber)(void*,int);static void(*pushcclosure)(void*,int(*)(void*),int);static void(*pushboolean)(void*,int);static void(*pushstring)(void*,const char*);
static wchar_t logPath[MAX_PATH];
void log(const char* text){FILE* f;_wfopen_s(&f,logPath,L"a");if(f){fprintf(f,"%s\n",text);fclose(f);}}
uintptr_t observe(void* context,Region* region,uint32_t colour){nativeContext=context;armedBody=region?region->body:-1;log("Native gun used: bridge armed for this body.");return originalApply(context,region,colour);}
using Construct=void*(*)(void*);static Construct originalConstruct;
using Update=void(*)(void*,float);static Update originalUpdate;
void* hookedConstruct(void* object){void* result=originalConstruct(object);nativeContext=object;log("Native paint context captured automatically at construction.");return result;}
void hookedUpdate(void* object,float dt){originalUpdate(object,dt);if(nativeContext!=object){nativeContext=object;log("Native paint context captured automatically at update.");}}
bool validContext(){__try{return nativeContext&&*(uintptr_t*)nativeContext==base+vtableRva;}__except(EXCEPTION_EXECUTE_HANDLER){return false;}}
int reply(void* L,bool ok,const char* why){pushboolean(L,ok);pushstring(L,why);return 2;}
int paint(void* L){
 if(gettop(L)!=14)return reply(L,false,"Expected 14 region arguments");double v[14];for(int i=0;i<14;i++){if(type(L,i+1)!=3)return reply(L,false,"Region argument is not numeric");v[i]=tonumber(L,i+1);if(!isfinite(v[i]))return reply(L,false,"Invalid region argument");}
 char request[160];sprintf_s(request,"Custom region requested for Lua body=%d; armed native body=%d",(int)v[0],armedBody);log(request);
 // The audited engine routine uses the tool only for Survival ammo/player checks.
 // Outside those modes, it resolves body and paint permissions from world globals.
 int mode=*(int*)(base+modeRva);int submode=*(int*)(base+modeRva+4);
 bool needsTool=(mode==14)||(mode==15&&submode==3);
 if(needsTool&&!validContext())return reply(L,false,"Native paint context is not initialized");
 void* applyContext=validContext()?nativeContext:nullptr;
 Region r={};r.body=(int)v[0];r.type=1;int normals=0;
 for(int i=0;i<3;i++){r.hit[i]=(float)v[1+i];r.normal[i]=(int)v[4+i];if(abs(r.normal[i])>1)return reply(L,false,"Invalid face");normals+=abs(r.normal[i]);r.a[i]=(int)v[7+i];r.b[i]=(int)v[10+i];if(abs(r.a[i])>4096||abs(r.b[i])>4096||abs(r.a[i]-r.b[i])>31)return reply(L,false,"Selection exceeds 32 cubes per axis");}
 if(normals!=1)return reply(L,false,"Face must be axis aligned");
 uint32_t colour=(uint32_t)v[13];if(colour!=0&&(colour>>24)!=255)return reply(L,false,"Paint must be opaque or erase");
 uintptr_t result=originalApply(applyContext,&r,colour);char line[200];sprintf_s(line,"Custom request body=%d corners=(%d,%d,%d)-(%d,%d,%d) result=%u",r.body,r.a[0],r.a[1],r.a[2],r.b[0],r.b[1],r.b[2],(unsigned)(result&255));log(line);
 return reply(L,(result&255)!=0,"Native region request processed");
}
int pickPressed(void* L){
 DWORD pid=0;GetWindowThreadProcessId(GetForegroundWindow(),&pid);
 static bool wasDown=false;bool down=pid==GetCurrentProcessId()&&(GetAsyncKeyState(VK_MBUTTON)&0x8000)!=0;
 bool pressed=down&&!wasDown;wasDown=down;pushboolean(L,pressed);return 1;
}
int menuDown(void* L){ DWORD pid=0;GetWindowThreadProcessId(GetForegroundWindow(),&pid);pushboolean(L,pid==GetCurrentProcessId()&&(GetAsyncKeyState('Q')&0x8000)!=0);return 1; }
using Call=void(*)(void*,int,int);static Call originalCall;
void installInTable(void* L){
 if(type(L,-1)==5){pushcclosure(L,menuDown,0);setfield(L,-2,"paintStudioMenuDown");getfield(L,-1,"paintStudioRegion");bool missing=type(L,-1)!=6;settop(L,gettop(L)-1);if(missing){pushcclosure(L,paint,0);setfield(L,-2,"paintStudioRegion");log("Registered bridge in callback environment sm table.");}
 getfield(L,-1,"paintStudioPickPressed");bool noPicker=type(L,-1)!=6;settop(L,gettop(L)-1);if(noPicker){pushcclosure(L,pickPressed,0);setfield(L,-2,"paintStudioPickPressed");}}
}
void registerBridge(void* L,int nargs){
 int top=gettop(L);
 // Mod callbacks can carry a separate sandbox environment from LUA_GLOBALSINDEX.
 if(top>=nargs+1 && type(L,-nargs-1)==6){getfenv(L,-nargs-1);if(type(L,-1)==5){pushcclosure(L,menuDown,0);setfield(L,-2,"paintStudioMenuDown");getfield(L,-1,"sm");installInTable(L);}settop(L,top);}
 getfield(L,-10002,"sm");installInTable(L);settop(L,top);
}
int hookedPcall(void* L,int a,int b,int c){registerBridge(L,a);return originalPcall(L,a,b,c);}
void hookedCall(void* L,int a,int b){registerBridge(L,a);originalCall(L,a,b);}
DWORD WINAPI start(void*){
 wchar_t path[MAX_PATH];GetModuleFileNameW(module,path,MAX_PATH);wchar_t* slash=wcsrchr(path,L'\\');if(!slash)return 0;wcscpy_s(slash+1,MAX_PATH-(slash+1-path),L"ColourForge.log");wcscpy_s(logPath,path);
 base=(uintptr_t)GetModuleHandleW(0);auto dos=(IMAGE_DOS_HEADER*)base;auto nt=(IMAGE_NT_HEADERS64*)(base+dos->e_lfanew);if(nt->FileHeader.TimeDateStamp==1790011171&&nt->OptionalHeader.SizeOfImage==29507584){applyRva=0x429980;constructRva=0x422130;updateRva=0x424990;vtableRva=0x14d68a8;modeRva=0x19c9570;}
 else if(nt->FileHeader.TimeDateStamp==1794831492&&nt->OptionalHeader.SizeOfImage==29540352){applyRva=0x42ab10;constructRva=0x4232c0;updateRva=0x425b20;vtableRva=0x14dcac0;modeRva=0x19d1570;}
 else {log("Unsupported executable; bridge disabled");return 0;}
 const unsigned char expected[]={0x48,0x89,0x5c,0x24,0x20,0x55,0x56,0x57};if(memcmp((void*)(base+applyRva),expected,sizeof(expected))){log("Signature mismatch; bridge disabled");return 0;}
 HMODULE lua=GetModuleHandleW(L"lua51.dll");if(!lua){log("Lua runtime not loaded");return 0;}
#define LUA(name) name=(decltype(name))GetProcAddress(lua,"lua_" #name);if(!name)return 0;
 LUA(gettop) LUA(settop) LUA(getfenv) LUA(getfield) LUA(setfield) LUA(type) LUA(tonumber) LUA(pushcclosure) LUA(pushboolean) LUA(pushstring)
 if(MH_Initialize()!=MH_OK){log("Hook initialization failed");return 0;}
 if(MH_CreateHook((void*)(base+applyRva),observe,(void**)&originalApply)!=MH_OK){log("Native hook failed");return 0;}
 if(MH_CreateHook((void*)GetProcAddress(lua,"lua_pcall"),hookedPcall,(void**)&originalPcall)!=MH_OK){log("Lua hook failed");return 0;}
 if(MH_CreateHook((void*)GetProcAddress(lua,"lua_call"),hookedCall,(void**)&originalCall)!=MH_OK){log("Lua callback hook failed");return 0;}
 if(MH_CreateHook((void*)(base+constructRva),hookedConstruct,(void**)&originalConstruct)!=MH_OK){log("Native constructor hook failed");return 0;}
 if(MH_CreateHook((void*)(base+updateRva),hookedUpdate,(void**)&originalUpdate)!=MH_OK){log("Native update hook failed");return 0;}
 if(MH_EnableHook(MH_ALL_HOOKS)==MH_OK)log("ColourForge DLL loaded with automatic paint context. No normal-gun priming required. Supported audited builds: 1.0.6.889 / 1.0.7a.903. Multiplayer unverified.");return 0;
}
BOOL WINAPI DllMain(HMODULE h,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){module=h;DisableThreadLibraryCalls(h);HANDLE t=CreateThread(0,0,start,0,0,0);if(t)CloseHandle(t);}return TRUE;}
