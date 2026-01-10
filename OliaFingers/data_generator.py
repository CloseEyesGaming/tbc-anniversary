import win32gui
import win32ui
from ctypes import windll
from PIL import Image
import math


def getPixel(pix: int) -> list:
    """
    Reads pixel on screen with game window handle.
    Currently, reads pixels in corners, depends on pix argument:
    pix == 1: TopLeft
    pix == 2: TopRight
    pix == 3: BottomLeft
    pix == 4: BottomRight
    """
    hwnd = win32gui.FindWindow(None, 'World of Warcraft')
    windll.user32.SetProcessDPIAware()
    # Change the line below depending on whether you want the whole window
    # or just the client area.
    left, top, right, bot = win32gui.GetClientRect(hwnd)
    # left, top, right, bot = win32gui.GetWindowRect(hwnd)
    w = 0
    h = 0
    pilGetPixelCoord = ()
    # topleft pixel cal:
    if pix == 1:
        w = 1
        h = 1
        pilGetPixelCoord = (0, 0)
    # topRight pixel calc:
    elif pix == 2:
        w = right
        h = 1
        pilGetPixelCoord = (right - 1, 0)
    # botLeft pixel calc:
    elif pix == 3:
        w = 1
        h = bot
        pilGetPixelCoord = (0, bot - 1)
    # botRight pixel calc:
    elif pix == 4:
        w = right
        h = bot
        pilGetPixelCoord = (right - 1, bot - 1)
    # topleft pixel + 1 cal:
    elif pix == 5:
        w = right
        h = bot
        pilGetPixelCoord = (1, 0)

    hwndDC = win32gui.GetWindowDC(hwnd)
    mfcDC = win32ui.CreateDCFromHandle(hwndDC)
    saveDC = mfcDC.CreateCompatibleDC()

    saveBitMap = win32ui.CreateBitmap()
    saveBitMap.CreateCompatibleBitmap(mfcDC, w, h)
    saveDC.SelectObject(saveBitMap)
    # Change the line below depending on whether you want the whole window
    # or just the client area.
    # result = windll.user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), 1)
    # result = windll.user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), 0)
    result = windll.user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), 3)

    bmpinfo = saveBitMap.GetInfo()

    bmpstr = saveBitMap.GetBitmapBits(True)

    im = Image.frombuffer(
        'RGB',
        (bmpinfo['bmWidth'], bmpinfo['bmHeight']),
        bmpstr, 'raw', 'BGRX', 0, 1)
    # get pixel color
    r, g, b = im.getpixel(pilGetPixelCoord)
    win32gui.DeleteObject(saveBitMap.GetHandle())
    saveDC.DeleteDC()
    mfcDC.DeleteDC()
    win32gui.ReleaseDC(hwnd, hwndDC)

    # if result == 1:
    #     # PrintWindow Succeeded
    #     im.save("test.png")

    r_dec, g_dec, b_dec = round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)
    # print(r_dec, g_dec, b_dec)
    return [r_dec, g_dec, b_dec]



def string2colorArr(data: str) -> list:
    """ Convert string to color coordinates """
    result = []
    counter = 1
    long = len(data)
    for i in range(1, long + 1, 3):
        try:
            val1 = ord(data[i])
        except:
            val1 = long - i + 256

        try:
            val2 = ord(data[i+1])
        except:
            val2 = long - i + 256

        counter = math.fmod(counter * 8161, 4294967279) + (ord(data[i-1]) * 16776193) + (val1 * 8372226) + (val2 * 3932164)
    _hash = math.fmod(counter, 4294967291)

    #  RGB to RGB Normalized decimal
    a = (_hash // 10 ** (int(math.log(_hash, 10)) - 1))  # take 2 first numbers from hash
    b = _hash % 100  # take last 2 numbers from hash
    c = int(math.log10(_hash)+1)  # get length of hash
    result.insert(0, round(a / 255, 4))
    result.insert(1, round(b / 255, 4))
    result.insert(2, round(c / 255, 4))
    return result


def key_bind(screenColor: list, spell_data: dict) -> str or tuple:
    """ Returns value (Key bind) from dict if matched color on screen and converted key from dict """
    for spell in spell_data:
        spell_color = string2colorArr(spell)
        if screenColor == spell_color:
            return spell_data[spell]
