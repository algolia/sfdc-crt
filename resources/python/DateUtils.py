from __future__ import annotations
from datetime import datetime
from dateutil.relativedelta import relativedelta

import platform
from robot.libraries.BuiltIn import BuiltIn

def get_date_zero_strip_char() -> str:
    """Returns a character for stripping leading zeros from dates
    Removing leading zeros from a date requires that 
    a platform specific strip character is provided when formatting the date
    
    Some date fields require that date has no leading zeros for months and days
    Date with leading zeros       31/03/2023
    Date without leading zeros    9/3/2023

    On Windows the strip character is '#'
    On POSIX compliant systems the strip character is '-'
    """
    if platform.system().lower() == "windows":
        strip_char = "#"
    else:
        strip_char = "-"
    return strip_char

def relative_date(years: int, months: int, days: int, format: str = "%m/%d/%Y") -> str:
    """ Takes in years, months, days, adds them to todays date and returns the date string
    format parameter allows changing the returned date: https://docs.python.org/3/library/datetime.html#strftime-and-strptime-format-codes
    """
    date = datetime.now() + relativedelta(years=int(years), months=int(months), days=int(days))
    return date.strftime(format)