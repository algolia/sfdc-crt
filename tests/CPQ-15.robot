*** Settings ***
Library            QForce
Library            ../resources/python/ImpersonationUtils.py

Resource           ../resources/records/account.resource
Resource           ../resources/records/contact.resource
Resource           ../resources/records/opportunity.resource

Variables          ../resources/test_data/cpq-15.yaml

Suite Setup        SuiteSetupActions
Suite Teardown     CloseAllBrowsers

*** Test Cases ***
Prospect Account Currency - V8 Standard
    [Tags]    cpq-15    account    currency    v8-standard
    Change Prospect Account Currency    ${v8_standard}

Customer Account Currency - V8 Standard
    [Tags]    cpq-15    account    currency    v8-standard
    Change Customer Account Currency    ${v8_standard}

Prospect Account Currency - V8.5 Elevate Ecomm
    [Tags]    cpq-15    account    currency    v8.5-elevate-ecomm
    Change Prospect Account Currency    ${v85_elevate_ecomm}

Customer Account Currency - V8.5 Elevate Ecomm
    [Tags]    cpq-15    account    currency    v8.5-elevate-ecomm
    Change Customer Account Currency    ${v85_elevate_ecomm}


*** Keywords ***
Suite Setup Actions
    SetConfig    DefaultTimeout    30s
    OpenBrowser    about:blank    ${browser}
    Login
    ${record_prefix}=    SetRecordPrefix    CPQ-15

Change Prospect Account Currency
    [Arguments]    ${data_dict}
    ImpersonateWithUid    ${primary_user_2}
    CloseAllSalesConsoleTabs

    ${acc_url}    ${opp_url}=    Create Account And Opportunity For Currency Change    Prospect    EUR - Euro    ${data_dict}[potential_plan]    ${data_dict}[price_book]
    Change Opportunity Currency    ${opp_url}    ${primary_user_2}    new_currency=USD - U.S. Dollar
    
    # Verify Account currency
    GoTo    ${acc_url}
    VerifyText    New FE Support Request
    VerifyField    Account Currency    USD - U.S. Dollar

Change Customer Account Currency
    [Arguments]    ${data_dict}
    ImpersonateWithUid    ${primary_user_2}
    CloseAllSalesConsoleTabs

    ${acc_url}    ${opp_url}=    Create Account And Opportunity For Currency Change    Customer    EUR - Euro    ${data_dict}[potential_plan]    ${data_dict}[price_book]
    Change Account Currency    ${acc_url}    ${primary_user_2}    should_fail=${TRUE}    new_currency=USD - U.S. Dollar
    
# Record owner is able to change opportunity currency
    # Change Opportunity Currency    ${opp_url}    ${primary_user_2}    should_fail=${TRUE}    new_currency=USD - U.S. Dollar
    Change Account Currency    ${acc_url}    ${deal_desk_user}    should_fail=${FALSE}    new_currency=USD - U.S. Dollar

Create Account And Opportunity For Currency Change
    [Arguments]    ${acc_type}    ${acc_currency}    ${potential_plan}    ${price_book}
    ${acc_url}=    CreateAccount    ${record_prefix}-${acc_type}    ${acc_type}    EUR - Euro
    ${acc_id}=    Resolve Record Id From Url    ${acc_url}    Account
    ${contact_url}=    CreateContact    ${acc_url}    ${record_prefix}    ${acc_type}-User    EUR - Euro
    ${opp_url}=    CreateOpportunity    
    ...  ${acc_id}    
    ...  contact_name=${record_prefix} ${acc_type}-User
    ...  opportunity_name=${record_prefix}-${acc_type}-Opp
    ...  creator_id=${primary_user_2}
    ...  potential_plan=${potential_plan}
    ...  price_book=${price_book}

    [return]    ${acc_url}    ${opp_url}

Change Account Currency    
    [Arguments]    ${acc_url}    ${user_id}    ${should_fail}=${FALSE}    ${new_currency}=USD - U.S. Dollar
    ImpersonateWithUid    ${user_id}
    CloseAllSalesConsoleTabs

    GoTo    ${acc_url}
    VerifyText    New FE Support Request

    # Open records edit mode
    ClickText    Edit Account Name
    VerifyNoText    Edit Account Name
    PickList    Account Currency    ${new_currency}
    ClickText    Save    partial_match=False

    IF    ${should_fail}
        VerifyText    We hit a snag.
        VerifyText    The Account's currency can not be changed. Please reach out to Deal Desk if you require assistance.
        # Close records edit mode
        ClickText    Cancel    anchor=Save
    END

    VerifyText    Edit Account Name

Change Opportunity Currency
    [Arguments]    ${opp_url}    ${user_id}    ${should_fail}=${FALSE}    ${new_currency}=USD - U.S. Dollar
    ImpersonateWithUid    ${user_id}
    CloseAllSalesConsoleTabs

    Go To    ${opp_url}
    VerifyText    Edit Opportunity Name
    ClickText    Edit Opportunity Name
    VerifyNoText    Edit Opportunity Name

    PickList    Opportunity Currency    ${new_currency}

    ${click_kwargs}=    Evaluate    {'anchor':'Cancel', 'partial_match':False}
    IF    ${should_fail}
        # Close records edit mode
        ClickTextAndRetryOnLockRowError
        ...    text_to_click=Save
        ...    text_to_wait=We hit a snag.
        ...    click_kwargs=${click_kwargs}
        ClickText    Cancel    anchor=Save
        VerifyText    Edit Account Name
    ELSE
        ClickTextAndRetryOnLockRowError
        ...    text_to_click=Save
        ...    text_to_wait=Edit Opportunity Name
        ...    click_kwargs=${click_kwargs}
    END
