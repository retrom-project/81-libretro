import ctypes as C,pathlib,sys
lib=C.CDLL(str(pathlib.Path(sys.argv[1]).resolve()))
class Var(C.Structure): _fields_=[('key',C.c_char_p),('value',C.c_char_p)]
class Game(C.Structure): _fields_=[('path',C.c_char_p),('data',C.c_void_p),('size',C.c_size_t),('meta',C.c_char_p)]
values={}; pollcounts={}; pressed=False; frame=b''; dims=(0,0)
@C.CFUNCTYPE(C.c_bool,C.c_uint,C.c_void_p)
def env(cmd,data):
 if cmd==16:
  v=C.cast(data,C.POINTER(Var));i=0
  while v[i].key:
   values[v[i].key]=v[i].value.split(b'; ',1)[1].split(b'|')[0];i+=1
  values[b'81_joypad_b']=b'new line';return True
 if cmd==15:
  v=C.cast(data,C.POINTER(Var));v[0].value=values.get(v[0].key);return bool(v[0].value)
 if cmd==17:C.cast(data,C.POINTER(C.c_bool))[0]=False;return True
 return cmd in [10,11,18,32,35,37]
@C.CFUNCTYPE(None,C.c_void_p,C.c_uint,C.c_uint,C.c_size_t)
def video(p,w,h,pitch):
 global frame,dims
 frame=b''.join(C.string_at(p+y*pitch,w*2) for y in range(h));dims=(w,h)
@C.CFUNCTYPE(C.c_size_t,C.c_void_p,C.c_size_t)
def audio(p,n):return n
@C.CFUNCTYPE(None)
def poll():pass
@C.CFUNCTYPE(C.c_int16,C.c_uint,C.c_uint,C.c_uint,C.c_uint)
def inp(port,device,index,id):
 k=(port,device,id);pollcounts[k]=pollcounts.get(k,0)+1
 return int(pressed and port==0 and id==0 and device==1)
lib.retro_set_environment(env);lib.retro_set_video_refresh(video);lib.retro_set_audio_sample_batch(audio);lib.retro_set_input_poll(poll);lib.retro_set_input_state(inp);lib.retro_init()
b=bytes(512);data=C.create_string_buffer(b);g=Game(b'fixture.p',C.cast(data,C.c_void_p),len(b),None)
lib.retro_set_controller_port_device(0,257);lib.retro_set_controller_port_device(1,259)
lib.retro_load_game.argtypes=[C.POINTER(Game)];assert lib.retro_load_game(C.byref(g))
for _ in range(3):lib.retro_run()
assert pollcounts.get((0,1,0),0)>0, "configured joypad must survive loading and query the base device"
assert pollcounts.get((1,3,13),0)>0, "independent keyboard must survive loading and query the base device"
lib.retro_deinit()
print("preconfigured controller input survives content loading")
