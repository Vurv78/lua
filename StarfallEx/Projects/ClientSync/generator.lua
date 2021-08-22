--@name SERVER->CLIENT Network Parity Generator
--@author Vurv
--@client

local DEFAULT_SERDE = { "writeAny(*)", "readAny()" } -- Unknown type
local TYPE_SERDE = setmetatable({
    ["number"] = { "writeF64(*)", "readF64()" },
    ["string"] = { "writeString(*)", "readString()" },
    ["bool"] = { "writeBool(*)", "readBool()" },
    ["table"] = { "writeTable(*)", "readTable()" }, -- Replace with bit.tabletostring impl later

    -- SF Types
    ["Vector"] = { "writeVector(*)", "readVector()" },
    ["Angle"] = { "writeAngle(*)", "readAngle()" },
    ["Color"] = { "writeColor(*)", "readColor()" },
    ["VMatrix"] = { "writeMatrix(*)", "readMatrix()" },

    ["Entity"] = { "writeEntity(*)", "readEntity()" },
    ["Npc"] = { "writeEntity(*)", "readEntity()" },

    -- Blocked types
    -- Have function parameters instead take string code which will be compiled on the client.
    ["function"] = { "writeString(*)", "loadstring(readString())" },
    ["thread"] = { "", "nil" }
}, {
    __index = function()
        return DEFAULT_SERDE
    end
})

local fmt = string.format

local file_meta = getMethods("File")
function file_meta:writef(...)
    return self:write( fmt(...) )
end

local function generateFunction(handle, name, fndata, id)
    local param_str = ""

    local fnparams, fnreturns = fndata.params, fndata.returns
    if fnparams then
        local p = {}
        for k, param in pairs(fnparams) do
            p[k] = param.name
        end
        param_str = table.concat(p, ", ")
    end


    handle:writef("\t\t['%s'] = function(%s)\n", name, param_str)
        -- Send function arguments -> Client
        handle:write("\t\t\tnetStart(BRIDGE_ID)\n")
        handle:writef("\t\t\twriteUInt(%d, BITS)\n", id)
            if fnparams then
                for k, param in pairs(fnparams) do
                    local serde = TYPE_SERDE[param.type]
                    if serde then
                        handle:writef("\t\t\t%s\n", string.replace(serde[1], "*", param.name) )
                    end
                end
            end

        handle:write("\t\t\tlocal self = curthread()\n")

        -- Receive return values from Client
        handle:write("\t\t\tnetReceive(BRIDGE_ID, function()\n")
            handle:write("\t\t\t\tnetReceive(BRIDGE_ID)\n")
            if fnreturns then
                local ret_readers = {}
                for k, ret in ipairs(fnreturns) do
                    ret_readers[k] = TYPE_SERDE[ret.type][2]
                end
                handle:writef( "\t\t\t\tresume(self, %s)\n", table.concat(ret_readers, ", ") )
            else
                handle:write("\t\t\t\tresume(self)\n")
            end
        handle:write("\t\t\tend)\n")

        handle:write("\t\t\tnetSend(TARGET, UNRELIABLE)\n")

        handle:write("\t\t\treturn sleep()\n")
    handle:write("\t\tend,\n")
end

local function containsClientFunction(lib)
    for _, m in pairs(lib.methods) do
        if m.realm == "client" then return true end
    end
    return false
end

local function generateServer(handle, docs)
    local id = 0
    handle:write("if SERVER then\n")
        handle:write("\tlocal TARGET = owner()\n")
        for libname, lib in pairs(docs.Libraries) do
            if not containsClientFunction(lib) then continue end
            handle:writef("\tENV.%s = {\n", libname)

            -- Library Methods
            for name, fn in pairs(lib.methods) do
                if fn.realm ~= "client" then continue end
                id = id + 1
                generateFunction(handle, name, fn, id)
            end
            handle:write("\t}\n\n")

            -- Todo: Fields maybe since we have access to them on client and we generate these on the client.
        end
    handle:write("end\n")
end

local function generateClient(handle, docs)
    handle:write("if CLIENT then\n")

        handle:write("\tlocal handlers = {\n")
        local id = 0
        for libname, lib in pairs(docs.Libraries) do
            if not containsClientFunction(lib) then continue end
            for name, fn in pairs(lib.methods) do
                id = id + 1
                handle:write("\t\tfunction()\n")
                    local fnparams = fn.params
                    local arg_readers = {}
                    if fnparams then
                        for k, param in ipairs(fnparams) do
                            arg_readers[k] = TYPE_SERDE[param.type][2]
                        end
                    end

                    local rets = fn.returns
                    local ret_names = {}
                    if rets then
                        local ret_writers = {}
                        for k, ret in ipairs(rets) do
                            ret_writers[k] = TYPE_SERDE[ret.type][1]
                            ret_names[k] = fmt("_%d", k)
                        end
                        handle:writef("\t\t\tlocal %s = %s.%s(%s)\n", table.concat(ret_names, ", "), libname, name, table.concat(arg_readers, ", "))

                        for k, writer in ipairs(ret_writers) do
                            handle:writef("\t\t\t%s\n", string.replace(writer, "*", ret_names[k]) )
                        end
                    else
                        handle:writef("\t\t\t%s.%s(%s)\n", libname, name, table.concat(arg_readers, ", "))
                    end

                handle:write("\t\tend,\n")
            end
        end

        handle:write("\t}\n")

        handle:write("\tnetReceive(BRIDGE_ID, function(len)\n")
            handle:write("\t\tnetStart(BRIDGE_ID)\n")
            handle:write("\t\thandlers[net.readUInt(BITS)]()\n")
            handle:write("\t\tnetSend(nil, UNRELIABLE)\n")
        handle:write("\tend)\n\n")
    handle:writef("end\n")
end

local function getMethodCount(docs)
    local fn_counter = 0
    for _, lib in pairs(docs.Libraries) do
        for _, m in pairs(lib.methods) do
            if m.realm == "client" then
                fn_counter = fn_counter + 1
            end
        end
    end
    return fn_counter
end

local function generate(docs)
    docs = json.decode(docs)
    local handle = file.open("out.txt", "wb")
    handle:writef("-- Generated from SF Version %s\n", docs.Version)
    handle:write("-- Configs\n")
    handle:write( "local BRIDGE_ID = 'bridge' -- Bridge net message name\n" )
    handle:write( "local UNRELIABLE = true -- Whether to use the net unreliable channel\n" )
    handle:writef( "local BITS = %d\n", math.ceil( math.log(getMethodCount(docs), 2) ) )
    handle:write( "local ENV = _G\n\n")

    -- Localizing functions for speed
    -- Writes
    handle:write("local writeAny, writeUInt, writeF64, writeString, writeBool, writeTable, writeColor, writeAngle, writeVector, writeMatrix, writeEntity = net.writeType, net.writeUInt, net.writeDouble, net.writeString, net.writeBool, net.writeTable, net.writeColor, net.writeAngle, net.writeVector, net.writeMatrix, net.writeEntity\n")
    -- Reads
    handle:write("local readAny, readUInt, readF64, readString, readBool, readTable, readColor, readAngle, readVector, readMatrix, readEntity = net.readType, net.readUInt, net.readDouble, net.readString, net.readBool, net.readTable, net.readColor, net.readAngle, net.readVector, net.readMatrix, net.readEntity\n")
    -- Misc
    handle:write("local netStart, netSend, netReceive = net.start, net.send, net.receive\n")
    handle:write("local sleep, resume, curthread = coroutine.yield, coroutine.resume, coroutine.running\n\n")

    generateServer(handle, docs)
    generateClient(handle, docs)

    handle:write("return ENV")

    handle:close()
end

http.get("https://raw.githubusercontent.com/thegrb93/StarfallEx/gh-pages/sf_doc.json", generate, error)