import win32api
import pyautogui

from data_generator import key_bind, getPixel
from spells_data import warrior_binds
# from decorators import *

pyautogui.PAUSE = 0
pyautogui.MINIMUM_SLEEP = 0


def read_pixel(pix: int, key_state: hex) -> str or tuple:
    """Key_state - keybind to start reading pixel
    pix: what pixel to read"""
    if win32api.GetAsyncKeyState(key_state) < 0:
        key = key_bind(getPixel(pix), warrior_binds)
        if type(key) == str:
            pyautogui.press(key)
        elif type(key) == tuple:
            pyautogui.hotkey(*key)
