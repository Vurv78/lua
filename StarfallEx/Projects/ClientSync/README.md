## ClientSync
Allows you to access functions from the client on the server. SERVER->CLIENT.  
*Credit to Jacbo for the idea as he made his own implementation for CLIENT->SERVER, opposite to this*  

This autogenerates bindings to interface with client functions from the server through networking using the typed SF Documentation. It is incredibly fast and takes ~30ms or 15 ms minimum just to call render.traceSurfaceColor on the server realm.

## Usage
This chip generates a file for you so you can stay updated even if SF adds more functions.  
Place this down and it'll generete a library named ``out.txt`` in your ``/sf_filedata/`` folder.  

Move that into your ``/starfall/`` folder and ``--@include`` + ``require`` it and you're good to go.

## Notes
There are configs at the top of your generated file that are useful if you dev in sf.

You need to use these functions inside of a coroutine. Here's a basic chip to get you started.

```lua
--@name Sync Test
--@author Vurv
--@shared
--@include include/sync.txt

require("include/sync.txt")

-- This runs on the SERVER of course 👍
if SERVER then
	hook.add("clientinitialized", "", function(ply)
		if ply ~= owner() then return end
		-- Owner loaded in.

		coroutine.wrap(function()
			-- Make a coroutine environment to run all of this in.
			local bench = timer.systime()
			while true do
				-- This works fine since internally using these functions calls coroutine.yield
				local a = render.traceSurfaceColor( owner():getPos(), owner():getPos() + owner():getAimVector() * 500 )
				print(a, "Hit Color!")
			end
		end)()
	end)
end
```