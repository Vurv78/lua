--@name RunSF
--@author Vurv
--@server
// Source -- https://github.com/Vurv78/starfallex-creations/blob/master/general/runsf
function runLua(S)
    xpcall(loadstring(S),function(ERROR)
        print("Code errored: "..tostring(ERROR))
    end)
end

hook.add("PlayerSay","",function(ply,text,teamchat)
    LS = string.split(text," ")
    if LS[1]=="?runsf" then
        function player()
            return ply
        end
        if player() ~= owner() then
            function say(S)
                concmd("say ["..S.."]")
            end
            function concmd()
                print("you don't have access to concmd")
            end
        end
        // player() is the client who init the command.
        local CODE = string.sub(text,8)
        
        print(ply:getName().." ran code")
        if string.sub(CODE,1,#"https://pastebin.com/raw/")=="https://pastebin.com/raw/" then
            // If is a pastebin link
            http.get(CODE,function(C)
                runLua(C)
            end)
        else
            // Attempt to run the rest of the user's text.
            runLua(CODE)
        end
    end
end)
