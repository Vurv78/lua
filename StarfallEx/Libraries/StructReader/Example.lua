--@name Deserialize
--@author Vurv
--@include libs/structreader.txt
--@shared

local SSBuilder = require("libs/structreader.txt")

local sampleHeader = SSBuilder:new [[
    greeting: cstr, gaming: i32 -- You can have comments in here too, pretty neat
    // C-Style comments too
    arr: [i32; 2]
    float: f32
]]

-- Let's create some example data that fits the header.
local sampleData = bit.stringstream()

-- cstr 'greeting'
sampleData:writeString("hello world!")

-- i32 'gaming'
sampleData:writeInt32(69)

-- [i32; 2] 'arr'
sampleData:writeInt32(120)
sampleData:writeInt32(240)

-- Float 'float'
sampleData:writeFloat(1241249)

local data = sampleHeader:parse( sampleData:getString() )

assert(data.gaming == 69, "Deserialization failed!")

printTable(data)

