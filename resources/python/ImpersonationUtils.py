from robot.libraries.BuiltIn import BuiltIn, RobotNotRunningError
from robot.api.deco import keyword, not_keyword

import time

class ImpersonationUtils():
    ''' ${login_url} must be defined as a variable in RFW
    '''
    def __init__(self):
        self.qforce = None
        try:
            self.qforce = BuiltIn().get_library_instance("QForce")
        # QEditor LSP will explode without this handling
        except RobotNotRunningError:
            pass
    
    @keyword
    def impersonate_with_uid(self, uid: str, timeout: float=10):
        '''Impersonates user with the given uid
        Uid can be acquired with keyword 'Get Uid With Name    username    rest=${False}'

        If impersonation with given the uid is on going then this does nothing.
        Stops on going impersonation if impersonating someone else 
        then proceeds to impersonate with the given uid
        '''
        qf = self.qforce

        if self.is_impersonating(uid):
            return
        elif self.is_impersonating():
            self.stop_impersonation(timeout)
        
        user_url_1 = "/lightning/setup/ManageUsers/page?address=%2F"
        user_url_3 = "%3Fnoredirect%3D1%26isUserEntityOverride%3D1"
        qf.go_to(self.baseurl() + user_url_1 + uid[0:-3] + user_url_3)
        
        qf.verify_text("Freeze")
        on_user_page = True
        while on_user_page:
            qf.click_element('(//input[@title="Login"])[1]')
            on_user_page = not qf.is_no_text("Freeze")

        start_time = time.time()
        end_time = start_time + timeout
        while time.time() < end_time:
            try:
                impersonating = self.is_impersonating(uid)
            except: # QWebDriverError, importing this is hacky at best so just ignore all exceptions 
                impersonating = False
            if not impersonating:
                time.sleep(1)
            else:
                break
        else:
            BuiltIn().fail(f"Impersonation of uid '{uid}' failed, uid from cookie '{self.get_short_uid_from_rsid_cookie()}' (last 3 characters of record uid have been stripped out)")

    @keyword
    def is_impersonating(self, uid="") -> bool:
        '''Checks if impersonation is active by checking the short uid from 'RSID' cookie
        If the 'uid' parameter is given then it is checked against the 'RSID' short uid
        '''
        short_uid = self.get_short_uid_from_rsid_cookie()
        if short_uid == "":
            return False
        elif uid == "":
            return True
        elif self.shorten_uid(uid) == short_uid:
            return True
        else:
            return False

    @keyword
    def stop_impersonation(self, timeout: float=10):
        '''Stops user impersonation with a JS script

        If there is no impersonation going then this kw does nothing
        If SFDC acts up and kicks the impersonator completely out it gets reported as a failure
        '''
        qf = self.qforce

        if not self.is_impersonating():
            return
    
        qf.execute_javascript('document.location.href = "/secur/logout.jsp"')
        if qf.get_url() == self.baseurl():
            BuiltIn().fail(f"Completely logged out from Salesforce instead of just ending impersonation")

        start_time = time.time()
        end_time = start_time + timeout
        while time.time() < end_time:
            short_uid = self.get_short_uid_from_rsid_cookie()
            if short_uid != "":
                time.sleep(1)
            else:
                break
        else:
            BuiltIn().fail(f"Still impersonating uid '{short_uid}' (last 3 characters of record uid have been stripped out)")

    @keyword
    def get_uid_with_name(self, username: str, rest: bool=False) -> str:
        '''Returns users uid (user record id) either by 
        opening said users user detail page and scraping it from the url
        or retrieving it with a REST API query.

        Using the rest option requires that QForce.Authenticate has succesfully passed
        before using this keyword

        username is generally in format 'FirstName LastName'
        -> 'Tom Price'
        '''
        qf = self.qforce

        if rest:
            r = qf.query_records(query=f"SELECT id FROM user WHERE name='{username}'")
            return r['records'][0]['Id']

        qf.go_to(self.baseurl() + "/lightning/setup/SetupOneHome/home")

        # default linebreak TAB takes the focus off and the results never load
        linebreak = qf.set_config('LineBreak', '')
        # adding 'user' at the end of the search massively speeds up the search 
        qf.type_text("Search Setup", f"{username} user")
        # set linebreak back to what it was
        qf.set_config('LineBreak', linebreak)

        qf.click_element(f'//a//div[@data-aura-class="uiOutputRichText" and text()="{username}"]')
        qf.verify_text("Freeze")

        url = qf.get_url()
        return self.get_uid_from_user_details_url(url)

    @not_keyword
    def baseurl(self):
        '''Helper for getting de facto standard $login_url from rfw
        Libraries are often loaded before resources/variables 
        so it's more convenient to always retrieve it from rfw
        instead of checking if the variable exists so that we can assign
        it as a class property.
        '''
        try:
            return BuiltIn().get_variable_value("$login_url", None).rstrip("/")
        except AttributeError as e:
            BuiltIn().fail("ImpersonationUtils.py requires that the variable '${login_url}' is set.")
    
    @not_keyword
    def shorten_uid(self, uid:str) -> str:
        '''Strips the last 3 characters of an uid so that
        it can be checked against short uid found from rsid cookie.
        
        uid:       0057Q000005CtJTQA0
        rsid uid:  0057Q000005CtJT
        '''
        return uid[0:-3]
    
    @not_keyword
    def get_uid_from_user_details_url(self, url) -> str:
        '''Does what it says.

        https://copado41-dev-ed.lightning.force.com/lightning/setup/ManageUsers/page?address=%2F0057Q000005CtJTQA0%3Fnoredirect...
        uid:       0057Q000005CtJTQA0
        rsid uid:  0057Q000005CtJT
        '''
        return url.split("%2F")[1].split("%3F")[0]
    
    @not_keyword
    def get_short_uid_from_rsid_cookie(self) -> str:
        ''' Iterates through cookies looking for 'RSID' named cookie
        Once the RSID is found then an empirically determined string slice
        containing the uid is returned

        00D7Q0000093zQu0057Q000006pOfueyJlbmMiOiJBM...
        00D7Q0000093zQu 0057Q000006pOfu eyJlbmMiOiJBM...
        rsid uid:       0057Q000006pOfu
        uid:            0057Q000006pOfuQAE
        '''
        for cookie in self.qforce.list_cookies():
            if cookie['name'] == 'RSID':
                return cookie['value'][15:30]
        else: return ""
