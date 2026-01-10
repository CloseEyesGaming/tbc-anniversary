import key_press
from key_press import read_pixel

if __name__ == '__main__':
    while True:
        read_pixel(1, 0x61)  # Num1 pressed in windowed mode
        read_pixel(1, 0x62)  # Num2 pressed in windowed mode
        read_pixel(1, 0x63)  # Num3 pressed in windowed mode
        read_pixel(1, 0x65)  # Num5 pressed in windowed mode