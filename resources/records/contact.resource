*** Settings    
Library    QForce

Resource           ../common/variables.resource
Resource           ../common/salesforce.resource

*** Keywords ***
Create Contact
    [Documentation]  Creates a contact to an account
    ...  Arguments:
    ...  ${account_url}: Url to the account to which the contact will be created to
    ...  ${first_name}: First name of the contact
    ...  ${last_name}: Last name of the contact
    ...  ${currency}: Contacts currency type, valid options: 'USD - U.S. Dollar', 'EUR - Euro', defaults to 'USD - U.S. Dollar'
    [Arguments]    ${account_url}
    ...            ${first_name}
    ...            ${last_name}
    ...            ${currency}=USD - U.S. Dollar  # EUR - Euro

    OpenRecordsRelatedView    ${account_url}    Contacts
    VerifyText    Add to Campaign
    ClickText   New    partial_match=False

    # Is contact creation view open
    VerifyText  New Contact  anchor=Contact Information

    TypeText    First Name    ${first_name}
    TypeText    Last Name    ${last_name}
    TypeText     Email        ${first_name}.${last_name}@algolia.com.invalid
    PickList    Contact Currency    ${currency}

    ClickText    Save    partial_match=False
    VerifyText    ${first_name} ${last_name}    anchor=Account Name    partial_match=False    tag=a    timeout=60
    VerifyField    Name    ${first_name} ${last_name}

    ${url}=    GetUrl
    [Return]    ${url}
