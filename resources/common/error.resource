*** Settings ***    
Library    QForce

*** Keywords ***
Click Text And Retry On Lock Row Error
    [Documentation]    Clicks a text and waits that a specific text appears after the click
    ...  If the text to appear does not appear then a generic Lock row error text is sought from the viewport
    ...  If the error text exists then the click text-verify text combination is retried
    ...  If the error text did not appear but neither did the text to verify then the keyword will fail
    ...
    ...  Arguments:
    ...  ${click_text}: The text to click
    ...  ${text_to_wait}: The text that should appear after click
    ...  ${click_kwargs}: Dictionary containing named arguments for the Click Text -keyword
    ...  ${click_kwargs}: Dictionary containing named arguments for the Verify Text -keyword
    ...
    ...  Example: Clicks text 'Save' on QLE and waits for text 'Quote Details' to appear
    ...           In general the argument dictionaries have been created with 'Evaluate' but 'CreateDictionary' could also be used
    ...
    ...  ${click_kwargs}=    Evaluate    {'partial_match':False}
    ...  ${wait_kwargs}=    Evaluate    {'timeout':60}
    ...  ClickTextAndRetryOnLockRowError
    ...  ...  text_to_click=Save
    ...  ...  text_to_wait=Quote Details
    ...  ...  click_kwargs=${click_kwargs}
    ...  ...  wait_kwargs=${wait_kwargs}
    ...
    ...
    ...  Same example with Create Dictionary
    ...
    ...  ${click_kwargs}=    CreateDictionary    partial_match=${False}
    ...  ${wait_kwargs}=    CreateDictionary    timeout=60
    ...  ClickTextAndRetryOnLockRowError
    ...  ...  text_to_click=Save
    ...  ...  text_to_wait=Quote Details
    ...  ...  click_kwargs=${click_kwargs}
    ...  ...  wait_kwargs=${wait_kwargs}

    [Arguments]    ${text_to_click}    ${text_to_wait}    ${click_kwargs}=${NONE}    ${wait_kwargs}=${NONE}
    ${default_timeout}=    GetConfig    DefaultTimeout
    IF    ${click_kwargs}==${NONE}
        ${click_kwargs}=    CreateDictionary    timeout=${default_timeout}
    END
    IF    ${wait_kwargs}==${NONE}
        ${wait_kwargs}=    CreateDictionary    timeout=${default_timeout}
    END

    ClickText       ${text_to_click}    &{click_kwargs}
    ${no_error}=    IsText    ${text_to_wait}    &{wait_kwargs}
    
    IF    ${no_error}
        ReturnFromKeyword
    END

    ${is_error}=    IsText    unable to obtain exclusive access    timeout=5
    IF    ${is_error}
        ClickText     ${text_to_click}    &{click_kwargs}
        VerifyText    ${text_to_wait}    &{wait_kwargs}
    ELSE
        LogScreenshot
        Fail    No lock row error was found but the text to wait '${text_to_wait}' did not appear
    END

    