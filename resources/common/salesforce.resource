*** Settings ***
Library            QForce
Library            DateTime
Library            String

Resource           secrets.resource
Resource           variables.resource

*** Keywords ***
Login
    [Documentation]  Logs in to Salesforce with preset credentials
    GoTo              ${login_url}
    
    IF    "preprod" in $login_url
        ${username}=    Set Variable    ${preprod_username}
        ${password}=    Set Variable    ${preprod_password}
    ELSE IF    "whitespace" in $login_url
        ${username}=    Set Variable    ${whitespace_username}
        ${password}=    Set Variable    ${whitespace_password}
    END

    TypeText    Username    ${username}
    TypeText    Password    ${password}
    ClickItem   Log In

    ${needs_mfa}=    IsText    Verify Your Identity    timeout=5
    IF    ${needs_mfa}
        ${mfa_code}    GetOtp    ${username}    ${mfa_secret}
        TypeText    Verification Code    ${mfa_code}
        ClickText    Verify    partial_match=False
    END

Set Record Prefix
    [Documentation]  Sets a suite variable containing a unique name for record creation
    ...  The variable is also returned for explicit assignment
    [Arguments]    ${test_case_identifier}
    ${timestamp}=    GetCurrentDate    exclude_millis=True
    ${short_ts}=    ConvertDate    ${timestamp}    result_format=%y%m%d-%H%M%S
    SetSuiteVariable    ${record_prefix}    CRT-${test_case_identifier}-${short_ts}
    [Return]    ${record_prefix}

Resolve Record Url From Id
    [Documentation]  Creates an url to a record with record id and record type
    ...  Example:
    ...  
    ...  ResolveRecordUrlFromId    0012300000iXZAmAAO    Account
    ...
    ...  returns:    https://algolia--preprod.sandbox.lightning.force.com/lightning/r/Account/0012300000iXZAmAAO/view
    [Arguments]    ${record_id}    ${record_type}
    ${url}=    SetVariable    ${login_url}/lightning/r/${record_type}/${record_id}/view
    [Return]    ${url}

Resolve Record Id From Url
    [Documentation]    Resolves record id from url with record type
    ...  Example:
    ...   
    ...  ResolveRecordIdFromUrl    https://algolia--preprod.sandbox.lightning.force.com/lightning/r/Account/0012300000iXZAmAAO/view    Account
    ...
    ...  returns: 0012300000iXZAmAAO
    [Arguments]    ${record_url}    ${record_type}
    ${a}=    SplitString    ${record_url}    ${record_type}/
    ${b}=    SplitString    ${a}[1]    /view
    [Return]    ${b}[0]

Navigate To Record With Id
    [Documentation]  Opens record page with record id and record type, optionally a text to verify after navigation can be also provided
    ...  Examples:
    ...  
    ...  NavigateToRecordWithId        0012300000iXZAmAAO    Account
    ...
    ...  # Verify that 'New Opportunity' is present on the navigated record page
    ...  NavigateToRecordWithId        0012300000iXZAmAAO    Account    New Opportunity  
    [Arguments]    ${record_id}    ${record_name}    ${verification_text}=${EMPTY}
    ${url}=    ResolveRecordUrlFromId    ${record_id}    ${record_name}
    Go To    ${url}

    IF    "${verification_text}" != "${EMPTY}"
        VerifyText    ${verification_text}
    END
    [Return]    ${url}

Open Records Related View
    [Documentation]  Opens records related record list view
    ...  Example: Open the list view containing accounts all opportunities
    ...
    ...  OpenRecordsRelatedView
    ...  ...  https://algolia--preprod.sandbox.lightning.force.com/lightning/r/Account/0012300000iXZAmAAO/view
    ...  ...  Opportunities
    [Arguments]    ${record_url}    ${related_view_name}
    ${related_view_url}=    ReplaceString    ${record_url}    /view    /related/${related_view_name}/view
    GoTo    ${related_view_url}
    [Return]    ${related_view_url}


Verify Picklist Selection
    [Documentation]    Confirms that picklist is set to expected value
    [Arguments]    ${label}    ${value}    ${timeout}=0.1
    ${lightning}=    IsElement    xpath=//lightning-combobox[./label[text()="${label}"]]//button[@data-value="${value}"]    timeout=${timeout}
    ReturnFromKeywordIf    ${lightning}
    VerifyElement    xpath=//div[./span[@data-aura-class="uiPicklistLabel" and contains(.,"${label}")]]//a[@class="select" and .="${value}"]    timeout=${timeout}

Verify Field Mandatory Indicator
    [Documentation]  Checks that a form field label contains an asterisk '*'
    [Arguments]    ${field_name}    ${timeout}=0.1
    ${found}=  IsElement    xpath=//label[./span[text()="*"] and ./span[text()="${field_name}"]]    timeout=${timeout}
    ReturnFromKeywordIf    ${found}
    VerifyElement    xpath=//span[./span[text()="*"] and ./span[text()="${field_name}"]]    timeout=${timeout}

Go To Url With Link
    [Documentation]  Parses url reference from a link element and navigates to the url
    ...  Used when needed to avoid opening new SFDC tabs
    ...  Arguments:
    ...  ${locator}: The text that the link contains
    [Arguments]    ${locator}
    ${url}=    SetVariable    javascript:void(0);
    WHILE    ${TRUE}    limit=10
        ${url}=    GetAttribute    ${locator}    href    tag=a  element_type=item  anchor=item
        IF    "${url}"=="javascript:void(0);"
            Sleep    2
        ELSE
            GoTo    ${url}
            BREAK
        END
    END
        
Close All Sales Console Tabs
    [Documentation]  Closes all tabs from Lightning Sales Console app
    VerifyText    Lightning Sales Console
    ClickUntilNoElements    xpath=//li[./a[@role="tab" and not(contains(@data-tabid, "_"))]]//button[contains(@title, "Close")]

Close All Subtabs
    [Documentation]  Closes all subtabs from Lightning Sales Console app
    ...  Subtabs mean the second row of tabs which might be present
    VerifyText    Lightning Sales Console
    ClickUntilNoElements    xpath=//li[./a[@role="tab" and (contains(@data-tabid, "_"))]]//button[contains(@title, "Close")]

Click Until No Elements
    [Documentation]    Clicks the element for given xpath until no such elements exist
    [Arguments]    ${xpath}
    ${tabs_present}=    IsElement    ${xpath}    timeout=5
    WHILE    ${tabs_present}    limit=5
        @{tabs_open}=        GetWebelement    locator=${xpath}
        FOR                  ${elem}    IN    @{tabs_open}
            RunKeywordAndIgnoreError    ClickElement     ${elem}    js=${TRUE}    timeout=2
        END
        Sleep    1
        ${tabs_present}=    IsElement    ${xpath}    timeout=5
    END
    
Reload Record List Until Record Count Is
    [Documentation]  Keeps reloading the current page (record list view) until the amount of records is the expected count
    ...  Pre-requisite: Must be on a record list view
    ...
    ...  Arguments:
    ...  ${table_name}: Unique text present in the table, practically always one of the table headers
    ...  ${expected_count}: How many records should be present
    ...  ${limit}: How many times the page will be reloaded
    [Arguments]    ${table_name}    ${expected_count}    ${limit}=20
    TRY
        UseTable    ${table_name}
    EXCEPT
        IF    $expected_count == 0
            VerifyText    Nothing to see here
            Return From Keyword
        END
        ${no_records}    IsText    Nothing to see here    timeout=10
        WHILE    ${no_records}    limit=${limit}
            Sleep    6
            RefreshPage
            ${no_records}    IsText    Nothing to see here    timeout=10
        END
        UseTable    ${table_name}
    END

    ${rows}=     GetTableRow    //last
    
    ${expected}=        ConvertToInteger    ${expected_count}
    ${expected_rows}=   SetVariable    ${expected + 1}
    WHILE    "${rows}" != "${expected_rows}"    limit=${limit}
        Sleep    6
        RefreshPage
        UseTable    ${table_name}
        ${rows}=     GetTableRow    //last
    END

Custom Picklist
    [Documentation]    Some Picklists do not work reliably with the QForce keyword `Picklist`
    ...  This is a workaround keyword for such cases
    [Arguments]    ${label}    ${value}    ${anchor}=1
    ${value_not_selected}=    SetVariable    ${TRUE}
    WHILE    ${value_not_selected}    limit=5
        RunKeywordAndIgnoreError    ClickText    ${label}    timeout=1
        Sleep              1
        ${value_present}=    IsText    ${value}    anchor=${anchor}    timeout=1
        IF    ${value_present}
            RunKeywordAndIgnoreError    ClickText    ${value}    anchor=${anchor}        timeout=1
        END
        Sleep              1
        ${value_not_selected}=    IsNoText    ${value}    anchor=${anchor}    timeout=1
    END

Custom Combobox
    [Documentation]    Some Comboboxes do not work reliably with the QForce keyword `Combobox`
    ...  This is a workaround keyword for such cases
    [Arguments]    ${label}    ${value}    ${selection_delay}=1
    ${linebreak}=    SetConfig    LineBreak    ${EMPTY}
    TypeText    ${label}    ${value}
    VerifyElement   xpath=//lightning-grouped-combobox[./label[text()="${label}"]]//lightning-base-combobox-formatted-text[@title="${value}"] | //div[contains(@class, "uiInput") and .//label/span[.="${label}"]]//li//div[@title="${value}"]
    Sleep    ${selection_delay}
    ClickElement    xpath=//lightning-grouped-combobox[./label[text()="${label}"]]//lightning-base-combobox-formatted-text[@title="${value}"] | //div[contains(@class, "uiInput") and .//label/span[.="${label}"]]//li//div[@title="${value}"]
    SetConfig    LineBreak    ${linebreak}

RichText Input
    [Documentation]    RichText fields do not work with the basic TypeText keyword
    [Arguments]    ${label}    ${text}
    # disable element highlighting
    ${previous_value}=    SetConfig    SearchMode      None
    ClickElement      xpath=//lightning-quill[contains(.,"${label}")]//div[@class="slds-rich-text-editor__textarea slds-grid"]
    # sets generated <p> elements innerText with js
    TypeText          locator=//lightning-quill[contains(.,"${label}")]//p    input_text=${text}
    #Execute Javascript  script=document.querySelectorAll('p')[0].innerText='Test Automation'
    # set element highlighting back to what it was
    SetConfig    SearchMode      ${previous_value}
