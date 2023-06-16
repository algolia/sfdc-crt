*** Settings    
Library    QForce
Library    DateTime
Library    ../python/ImpersonationUtils.py

Resource   ../common/error.resource
Resource   ../common/variables.resource
Resource   ../common/salesforce.resource

*** Keywords ***
Create Account
    [Documentation]  Creates a new account and returns an url to it
    ...  Arguments
    ...  ${name}: The name of the new account
    ...  ${type}: Account type, valid types: 'Prospect', 'Customer', defaults to 'Prospect'
    ...  ${currency}: Accounts currency type, valid types: 'USD - U.S. Dollar', 'EUR - Euro', defaults to 'USD - U.S. Dollar'
    [Arguments]    ${name}
    ...            ${type}=Prospect               # Customer
    ...            ${currency}=USD - U.S. Dollar  # EUR - Euro

    GoTo   ${login_url}/lightning/o/Account/list
    VerifyText    Discover Companies
    ClickText   New    anchor=Discover Companies    partial_match=False
    VerifyNoText    Discover Companies

    # Check that we are on a account creation page
    ${on_new_account_page}=  IsElement    xpath=//a[@role="tab" and @title="New Account" and @aria-selected="true"]    timeout=10
    IF  ${on_new_account_page} == ${FALSE}
        # Not on new account page, try clicking tab 'New Account'
        Sleep    1
        ClickText    New Account
        Sleep    1
        RefreshPage
    END

    # Select account base type, always Customer
    VerifyText  Partner  anchor=Customer    partial_match=False
    ClickText    Customer    anchor=Cancel    partial_match=False
    ClickText    Next    anchor=Cancel

    # Set account details
    VerifyText  New Account: Customer

    TypeText    Account Name    ${name}
    PickList    Account Currency    ${currency}
    PickList    Type    ${type}    partial_match=False

    # Address is always the same
    PickList    Billing Country    United States
    TypeText    Billing Street    10th Avenue
    TypeText    Billing City    New York
    PickList    Billing State/Province    New York
    TypeText    Billing Zip/Postal Code    10001

    ClickCheckbox    Copy from Billing Address    on

    ClickText    Save    partial_match=False
    # Occasionally account creation hangs and fails after few minutes with msg:
    #     "Review the errors on this page."
    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False, 'timeout':150}
    ${wait_kwargs}=    Evaluate    {'timeout':150}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=New Opportunity
    ...    click_kwargs=${click_kwargs}
    ...    wait_kwargs=${wait_kwargs}

    ${url}=    Get Url
    [Return]    ${url}

Create App To Account
    [Documentation]  Creates a new AlgoliaApp to an account so that the opportunities of the account can be closed
    ...  Arguments:
    ...  ${acc_url}: Url to the account to which the app will be created to
    ...  ${app_name}: Name of the app, must be globally unique!
    ...  ${contact_name}: Full bame of the apps contact
    [Arguments]    ${acc_url}    ${app_name}    ${contact_name}
    GoTo    ${acc_url}
    VerifyText    New Opportunity
    ClickText    Apps and Invoices
    VerifyText    AlgoliaApps
    ClickElement    xpath=//li[@data-target-selection-name="sfdc:StandardButton.AlgoliaApp__c.New"]
    
    # Is AlgoliaApp creation page open
    VerifyText    New AlgoliaApp
    TypeText    APPID    ${app_name}
    ComboBox  Contact  ${contact_name}
    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    ClickTextAndRetryOnLockRowError
    ...    text_to_click=Save
    ...    text_to_wait=" was created.
    ...    click_kwargs=${click_kwargs}

    
