## PNGWriter by Vurv (Originally by Wyozi)

This is a lua library to write PNG files in RGB or RGBA format.
It includes a lot of helper functions to make the process go smoothly.

### Warning
This does not allow you to write floating point numbers for rgb(a) data, that is why all of the functions that aren't "Fast" floor the numbers.

Example code: See test.png for the output
```lua
--@name PNG Library Example
--@author Vurv
--@client
--@include pnglib.txt

if player() ~= owner() then return end

local createPNG = require("pnglib.txt") -- Or whatever you stored the file in your starfall folder.

local png = createPNG(2,2,"rgba") -- Create a 2x2 rgba image

png:write{255,255,255,255} -- white
png:writeRGBA(255,150.2124214,0,255) -- orange
png:writeRGBAFast(0,255,0,255) -- green, uses writeRGBAFast instead of writeRGBA, do not give unrounded / floating point numbers to this.
-- png:write{0,0,255,255/2} -- This will corrupt the image, don't do this! Use writeRGBA or any non-"Fast" function to write floating point nums so they're floored.
png:writeRGBA(0,0,255,255/2)

png:export("test.png") -- writes to sf_filedata/test.png
```

## Differences from wyozi's
I tried to make this library pretty much the same thing as what I did for my Expression2 one, [found here](https://github.com/Vurv78/expression2-public-e2s/tree/master/E2Libraries/PNGLib)  
So it adds a lot of helper functions to write data and automatically floor it.  
See the helper functions below.

The difference between the "Fast" functions and the other functions is that they don't check if the numbers are properly rounded.  
If you pass floating point numbers into the image, it'll break.
All by default write 255, 255, 255 (255)

## Helper functions
### createImage(number width, number height, string image_type)
* Make sure image_type is either ``"rgb"`` or ``"rgba"``
* Returns a PNG struct. See the PNG functions below.

### PNG:export(string path)
* Writes the image data to the file path given in sf_filedata. Remember to set the image to nil after to save memory

## RGBA Functions
### PNG:writeVector(vector rgba)
* Mode: PNG_RGBA

### PNG:writeVectorFast(vector rgba)
* Mode: PNG_RGBA

### PNG:writeColor(color rgba)
* Mode: PNG_RGBA

### PNG:writeColorFast(color rgba)
* Mode: PNG_RGBA
* Note: This is the same as doing PNG:write(Color). Should be fine though, since all numbers have data by default.

### PNG:writeRGBA(number r, number g, number b, number a)
* Mode: PNG_RGBA

### PNG:writeRGBAFast(number r, number g, number b, number a)
* Mode: PNG_RGBA

## RGB Functions
### PNG:writeRGB(number r, number g, number b)
* Mode: PNG_RGB

### PNG:writeRGBFast(number r, number g, number b)
* Mode: PNG_RGB

### PNG:writeVectorRGB(vector rgb)
* Mode: PNG_RGB

### PNG:writeVectorRGBFast(vector rgb)
* Mode: PNG_RGB

### PNG:writeColorRGB(color rgb)
* Mode: PNG_RGB

### PNG:writeColorRGBFast(color rgb)
* Mode: PNG_RGB