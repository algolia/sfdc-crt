*** Settings ***
Library            QForce
Library            DateTime
Library            String

Resource           ../common/error.resource
Resource           ../common/salesforce.resource

*** Keywords ***
CreateOpportunity
    [Documentation]    Creates an opportunity to an account, returns the url of created opportunity
    ...  ${account_id}: Id of the account under which the opportunity will be created
    ...  ${opportunity_name}: Name for the opportunity, optional
    ...  ${close_date}: Defaults to current date
    ...  ${days_to_close}: If ${close_date} is left empty then this can be used to set close date to n days from current date
    ...  ${amount}: Amount as a plain number, defaults to '100000'
    ...  ${lead_source}: Defaults to 'Website'
    ...  ${opportunity_type}: Defaults to 'New Business'
    ...  ${upgrade_from}: Required if ${opportunity_type} is 'Upgrade', defaults to 'V8 Standard Committed'
    ...  ${expansion_type}: Required if ${opportunity_type} is 'Upgrade', defaults to 'New Use Case'
    ...  ${current_search_tech}: Defaults to 'Amazon Cloud Search'
    ...  ${potential_plan}: Defaults to 'Standard Committed - V8'
    ...  ${use_cases}: One or many use cases separated by ';', defaults to "Online content / subscription"
    ...  ${price_book}: Defaults to 'Algolia V8 Pricing'
    ...  ${contact_name}: Opportunitys primary contact name
    ...  ${app_id}: If thhe account has multiple algolia apps available then the app name must be provided
    ...  ${opportunity_owner}: Who should be be set up as the owner of the opportunity after its creation
    ...  ${creator_id}: User Bryan Fraser has different mandatory fields than for example Justin Barth
    ...                 This argument is used for checking which fields should be present and filled
    [Arguments]    ${account_id}
    ...            ${opportunity_name}=${EMPTY}
    ...            ${close_date}=${EMPTY}
    ...            ${days_to_close_date}=0
    ...            ${amount}=100000
    ...            ${lead_source}=Website
    ...            ${opportunity_type}=New Business
    ...            ${upgrade_from}=V8 Standard Committed
    ...            ${expansion_type}=New Use Case
    ...            ${current_search_tech}=Amazon Cloud Search
    ...            ${potential_plan}=Standard Committed - V8
    ...            ${use_cases}=Online content / subscription
    ...            ${price_book}=Algolia V8 Pricing
    ...            ${contact_name}=${EMPTY}
    ...            ${buyer_type}=Champion
    ...            ${app_id}=${EMPTY}
    ...            ${opportunity_owner}=${EMPTY}
    ...            ${creator_id}=${primary_user}

    NavigateToRecordWithId    ${account_id}    Account
    CloseAllSalesConsoleTabs
    NavigateToRecordWithId    ${account_id}    Account
    # Second row tabs can mess up filling the opp form due to duplicate matches 
    CloseAllSubtabs

    # Open opportunity creation form
    ClickText    New Opportunity    anchor=Prospect    partial_match=False
    VerifyText    Opportunity Creation    timeout=60s

    # Resolve close date to set for the opp
    IF    "${close_date}" == "${EMPTY}"
          ${date}=    GetCurrentDate
          ${date}=    AddTimeToDate    ${date}    ${days_to_close_date} days
          ${date}=    ConvertDate    ${date}    result_format=%b %d, %Y   exclude_millis=True
    ELSE
          ${date}=    SetVariable    ${close_date}
    END

    # Clean-up amount
    ${amount}=    Replace String    ${amount}    $    ${EMPTY}
    ${amount}=    Replace String    ${amount}    ${SPACE}    ${EMPTY}
    # fill form
    TypeText          Amount                  ${amount}    delay=2
    PickList          Lead Source            ${lead_source}    
    PickList          Current Search Tech    ${current_search_tech}

    ${use_case_list}=    Split String    ${use_cases}    ;${SPACE}
    FOR    ${uc}    IN    @{use_case_list}
        MultiPickList    Use cases              ${uc}
    END
    TypeText          Close Date             ${date}
    PickList          Type                   ${opportunity_type}
    IF    "${opportunity_type}" == "Upgrade"
        UseModal    on
        Verify Text    Upgrade From
        Verify Text    Expansion Type
        PickList    Upgrade From    ${upgrade_from}
        PickList    Expansion Type    ${expansion_type}
        Sleep    1
        VerifyPicklistSelection    Upgrade From    ${upgrade_from}
        VerifyPicklistSelection    Expansion Type    ${expansion_type}
        ClickText    Confirm
        UseModal    off
        VerifyNoText    Expansion Type
    END
        
    # PickList has timing issues with field "potential plan"
    Custom Picklist    Potential Plan    ${potential_plan}

    # if user is Bryan Fraser
    IF    "${creator_id}" == "${primary_user}"
        PickList          Opportunity Stage      Interested
        TypeText          Next Step              Test automation
        RichTextInput    Identified Pain    Test Automation
        RichTextInput    Ability to buy    Test Automation
    END

    Custom Picklist         Contact Name    ${contact_name}    anchor=Buyer Type
    Custom Picklist         Select Buyer Type    ${buyer_type}
    PickList                Price Book    ${price_book}

    
    # Is there multiple AlgoliaApps to select from
    ${select_app}=    IsElement    xpath=//button[@aria-label="Algolia App, Select Algolia App" and @aria-required="true"]
    IF    ${select_app}
        ${value_not_selected}=    SetVariable    ${TRUE}
        # try opening the AlgoliaApp picklist and select the given value (for 5 times)
        WHILE    ${value_not_selected}    limit=5
            RunKeywordAndIgnoreError    ClickElement    xpath=//button[@aria-label="Algolia App, Select Algolia App"]    timeout=1
            Sleep              1
            ${value_present}=    IsElement    xpath=//lightning-base-combobox-item/span/span[contains(@title,"${app_id} (")]    timeout=1
            IF    ${value_present}
                RunKeywordAndIgnoreError    ClickElement    xpath=//lightning-base-combobox-item/span/span[contains(@title,"${app_id} (")]    timeout=1
                END
                Sleep              1
                ${value_not_selected}=    IsElement    xpath=//button[@aria-label="Algolia App, Select Algolia App"]    timeout=1
            END
    END
    
    Sleep    1
    # Finish opp creation, occasionally the click does not register or an error is thrown
    #   either of these events will block the opp creation and fail the tc
    ClickText    Create Opportunity
    ${on_opp_page}=    Is Text    Opportunity Information    timeout=60s
    IF    ${on_opp_page}
        # opp was created and no need for corrective actions
        NoOperation
    ELSE
        # Check if we are still on opp creation page
        ${on_creation_page}=    IsText    Opportunity Creation    timeout=1
        IF    ${on_creation_page}
            # Still on opp creation page, try reclicking the 'Create Opportunity' button
            ClickText    Create Opportunity
            VerifyText    Opportunity Information    timeout=60s
        ELSE
            # Not on the opp creation page, we might've landed on some other tab
            #    Try clicking the default opportunity name
            ClickText    ${opportunity_type}-${potential_plan}
            VerifyText    Opportunity Information   timeout=5
        END
    END
    
    # If opp name was provided as an argument then set it to the newly created opp
    IF    "${opportunity_name}" != "${EMPTY}"
        ${opportunity_name}=    Replace String    ${opportunity_name}    ${SPACE}${SPACE}    ${SPACE}
        ClickWhile    Edit Opportunity Name    Edit Opportunity Name    interval=15
        TypeText    Opportunity Name    ${opportunity_name}

        ${click_kwargs}=    Evaluate    {'partial_match':False}
        ClickTextAndRetryOnLockRowError
        ...    text_to_click=Save
        ...    text_to_wait=Edit Opportunity Name
        ...    click_kwargs=${click_kwargs}
    END

    # If opp owner was provided as an argument then set it to the newly created opp
    IF    "${opportunity_owner}" != "${EMPTY}"
        ClickUntil    Change Opportunity Owner    Change Owner    interval=15
        Sleep    1
        VerifyText    Change Opportunity Owner
        UseModal    On

        ${lb}=    SetConfig    LineBreak    None

        ${owner_selected}=  IsElement    xpath=//span[@class="pillText" and text()="${opportunity_owner}"]
        WHILE    not ${owner_selected}    limit=5
            ClickText    Change Opportunity Owner
            ClickElement    xpath=//input[@title="Search Users"]
            TypeText    locator=//input[@title="Search Users"]   input_text=${opportunity_owner}
            RunKeywordAndIgnoreError    ClickElement    xpath=//ul[contains(@class,"lookup__list")]/li[.//*[@title="${opportunity_owner}"]]    timeout=5
            ${owner_selected}=    IsElement    xpath=//span[@class="pillText" and text()="${opportunity_owner}"]    timeout=2
        END
        SetConfig    LineBreak    ${lb}

        Sleep    1
        ClickText    Change Owner    anchor=Cancel
        VerifyNoText    Change Opportunity Owner
        VerifyText    ${opportunity_owner} now owns the record
        UseModal    Off

        VerifyText    ${opportunity_owner}
        VerifyField    Opportunity Owner    ${opportunity_owner}    tag=a
    END
        
    ${url}=    GetUrl
    [Return]    ${url}
    