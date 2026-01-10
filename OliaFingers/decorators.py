import time as t


def fps(func):
    def wrapper(*args):
        start = t.time()
        result = func(*args)
        end = t.time()
        time = end - start
        if time != 0:
            print(f'FPS: {1 / time}')
        result
    return wrapper
