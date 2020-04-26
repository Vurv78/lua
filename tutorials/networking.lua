--@name Basic Networking Tutorial
--@author Vurv
--@shared

if SERVER then

    E = chip()
    timer.simple(0.5,function()
        // Putting this in a timer as sending stuff from server -> client is not always reliable
        // Due to clientside ping. half a second is good enough for most cases.
        // Could maybe adjust depending on who you're sending it to's ping... never tried it
        net.start("hello")
            net.writeEntity(E)
        net.send(owner())
    end)
    // If you specify someone in the brackets on the serverside, it'll only send it to
    // That person.
    
    Executions = 0
    net.receive("foo",function(len,ply)
        // ply is the player who is sending the request.
        // Len can be ignored here as well we aren't using UInts/numbers
        // Will execute the number of players on the server time as they are all sending net requests.
        SHUCKS = net.readString()
        DANG = net.readString()
        TWANG = net.readString()
        print(SHUCKS,DANG,TWANG)
        Executions = Executions + 1
    end)
    print("Foo will execute ["..#find.allPlayers().."] times!")
else
    // if Client
    
    net.receive("hello",function(len)
        // Can ignore len, only useful for nums and stuff
        print(net.readEntity() == chip() and "Received chip entity!" or "Something happened while trying to get the chip.")
        // Completely useless to network the chip, this is just so i dont have to spawn a prop im lazy
        // This receive function will never be called on other clients besides the owner, since
        // You only send it to the owner.
    end)
    
    
    net.start("foo")
        net.writeString("shucks")
        net.writeString("dang")
        net.writeString("twang")
    net.send()

end
