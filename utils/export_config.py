#!/usr/bin/env python3

import os, sys, configparser, shlex

def __read_usable_config() -> str:
    """
    Check if a file specified in command line arguments exists.
    If not, iterate through a list of fallbacks.
    Bail if no usable configuration file found.

    Returns
    -------
    str
        Usable configuration file path

    Raises
    ------
    FileNotFoundError
        If unable to find a configuration file that exists.

    """
    try:
        if os.path.exists((argv_path := sys.argv[1])):
            return argv_path
        raise FileNotFoundError(
                f"{argv_path} does not exist!"
                )
    except IndexError:
        for p in (checked_paths := ["simple_router.ini", "/etc/simple_router.ini"]):
            if os.path.exists(p):
                return p
        raise FileNotFoundError(
            f"Unable to find a usable configuration file in: {', '.join(checked_paths)}"
                )

if __name__ == "__main__":
    c = configparser.ConfigParser()
    c.read(__read_usable_config())

    for section in c.sections():
        for k, v in c[section].items():
            print(shlex.quote(f'{section}__{k}={v}'))
