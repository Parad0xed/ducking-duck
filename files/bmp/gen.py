# converts image to Verilog HDL that infers a ROM using Xilinx Block RAM
# note: 12-bit color map word is r3, r2, r1, r0, g3, g2, g1, g0, b3, b2, b1, b0

# modified to -> .mem bitmap
# currently, 0 = transparent, 1 = default color

from scipy import misc
import imageio.v2 as iio
import math
import sys

# returns string of 12-bit color at row x, column y of image
def get_color_bits(im, y, x):
    # convert color components to byte string and slice needed upper bits
    b  = format(im[y][x][0], 'b').zfill(8)
    rx = b[0:4]
    b  = format(im[y][x][1], 'b').zfill(8)
    gx = b[0:4]
    b  = format(im[y][x][2], 'b').zfill(8)
    bx = b[0:4]

    # return concatination of RGB bits
    return str(rx+gx+bx)

# write to file Verilog HDL
# takes name of file, image array,
# pixel coordinates of background color to mask as 0
def rom_12_bit(name, im, mask=False, rem_x=-1, rem_y=-1):

    # get colorbyte of background color
    # if coordinates left at default, map all data without masking
    if rem_x == -1 or rem_y == -1:
        a = "000000000000"
        
    # else set mask compare byte
    else:
        a = get_color_bits(im, rem_x, rem_y)

    # make output filename from input
    file_name = "output.mem"

    # open file
    f = open(file_name, 'w')

    # get image dimensions
    y_max, x_max, z = im.shape

    # get width of row and column case words
    row_width = math.ceil(math.log(y_max-1,2))
    col_width = math.ceil(math.log(x_max-1,2))

    # loops through y rows and x columns
    for y in range(y_max):
        for x in range(x_max):
            
            if(get_color_bits(im, y, x) == "000000000000"):
                f.write("1 ")
            elif(get_color_bits(im, y, x) == "111111111111"):
                f.write("0 ")
                
        f.write("\n")
        
    # close file
    f.close()    

# driver function
def generate(name, rem_x=-1, rem_y=-1):
    im = iio.imread(name, pilmode = 'RGB')
    print("width: " + str(im.shape[1]) + ", height: " + str(im.shape[0]))
    rom_12_bit(name, im)

# generate rom from full bitmap image

if __name__ == "__main__":
    generate(sys.argv[1])

    