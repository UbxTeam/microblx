#!/usr/bin/env luajit -i

ffi = require("ffi")
ubx = require "ubx"
ubx_env = require "ubx_env"
bd = require("blockdiagram")
ts = tostring

function usage()
   print( [=[
microblx function blocks system launcher

usage ubx_launch OPTIONS -c <conf file>
   -c <conf_file.usc>		Configuration file to launch
   -nodename			Name to give to node
   -validate			Dont run, just validate configuration file
   -webif [port]		Create and start a webinterface block
   -d <deploy_conf.udc>		Load deploy conf file	
   -h				Show this.
]=])
end

local opttab=utils.proc_args(arg)
local nodename="node-"..os.date("%Y%m%d_%H%M%S")

if #arg==1 or opttab['-h'] then
   usage(); os.exit(1)
end

if not (opttab['-c'] and opttab['-c'][1]) then
   print("no configuration file given (-c option)")
   os.exit(1)
else
   conf_file = opttab['-c'][1]
end

local suc, model = pcall(dofile, conf_file)

if not suc then
   print(model)
   print("ubx_launch failed to load file "..ts(conf_file))
   os.exit(1)
end

if opttab['-nodename'] then
   if not opttab['-nodename'][1] then
      print("-nodename option requires a node name argument)")
      os.exit(1)
   else
      nodename = opttab['-nodename'][1]
   end
end

if opttab['-validate'] then
   model:validate(true)
   os.exit(1)
end

ni = model:launch{nodename=nodename, verbose=true}

if opttab['-webif'] then
   local port = opttab['-webif'][1] or 8888
   print("starting up webinterface block (port: "..ts(port)..")")
   ubx.load_module(ni, ubx_env.get_ubx_root().."std_blocks/webif/webif.so")
   local webif1=ubx.block_create(ni, "webif/webif", "webif1", { port=ts(port) })
   assert(ubx.block_init(webif1)==0)
   assert(ubx.block_start(webif1)==0)
end

-- Load deploy config
if ( opttab['-d'] ) then
  if (not opttab['-d'][1] ) then
    print("Deploy configuration file is not valid")
    os.exit(1)
  else
    dep_file = opttab['-d'][1]
    local suc, ops = pcall(dofile, dep_file)
    if ( suc ) then
      for i, v in ipairs(ops) do 
        if ( v["op"] == "start" ) then
          print("Starting "..v["name"])
          ubx.block_start (ubx.block_get(ni, v["name"] ))
        elseif ( v["op"] == "init" ) then
            print("Initialising "..v["name"])
            ubx.block_init  (ubx.block_get(ni, v["name"] ))
        elseif ( v["op"] == "cleanup" ) then
            print("Cleaning up "..v["name"])
            ubx.block_cleanup  (ubx.block_get(ni, v["name"] ))
        elseif ( v["op"] == "stop" ) then
            print("Stopping "..v["name"])
            ubx.block_stop  (ubx.block_get(ni, v["name"] ))
        end
      end
    else
      print(dep)
    end
  end
end

