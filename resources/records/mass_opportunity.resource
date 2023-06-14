*** Settings ***
Library            QForce
Library            DateTime
Library            String

Resource           ../common/error.resource
Resource           ../common/salesforce.resource

*** Keywords ***
CreateMassOpportunity
    [Documentation]    This keyword should only be used for creating opportunities from an excel file
    [Arguments]    ${account_id}
    ...            ${opportunity_name}=${EMPTY}
    ...            ${close_date}=15/09/2023
    ...            ${days_to_close_date}=0
    ...            ${amount}=100000
    ...            ${lead_source}=Sales Outbound
    ...            ${opportunity_type}=Upgrade
    ...            ${current_search_tech}=Algolia
    ...            ${potential_plan}=Elevate v8.5
    ...            ${use_cases}=${EMPTY}
    ...            ${price_book}=Algolia v8.5 Elevate Pricing
    ...            ${contact_name}=${EMPTY}
    ...            ${buyer_type}=Communicator
    ...            ${app_id}=${EMPTY}
    ...            ${opportunity_owner}=${EMPTY}

    NavigateToRecordWithId    ${account_id}    Prospect
    CloseAllSalesConsoleTabs
    NavigateToRecordWithId    ${account_id}    Prospect
    # Second row tabs can mess up filling the opp form due to duplicate matches 
    CloseAllSubtabs

    # Open opportunity creation form
    ClickText    New Opportunity    anchor=Prospect    partial_match=False
    VerifyText    Opportunity Creation    timeout=60s

    # Resolve close date to set for the opp
    IF    "${close_date}" == "${EMPTY}"
          ${date}=    GetCurrentDate
          ${date}=    AddTimeToDate    ${date}    ${days_to_close_date} days
          ${date}=    ConvertDate    ${date}    result_format=%d-%b-%Y   exclude_millis=True
    ELSE
          ${date}=    SetVariable    ${close_date}
    END

    # Clean-up amount
    ${amount}=    Replace String    ${amount}    $    ${EMPTY}
    ${amount}=    Replace String    ${amount}    ${SPACE}    ${EMPTY}
    # fill form
    TypeText          Amount                  ${amount}
    PickList          *Lead Source            ${lead_source}    
    PickList          *Current Search Tech    ${current_search_tech}

    ${use_case_list}=    Split String    ${use_cases}    ;${SPACE}
    FOR    ${uc}    IN    @{use_case_list}
        MultiPickList    *Use cases              ${uc}
    END
    TypeText          *Close Date             ${date}
    PickList          *Type                   ${opportunity_type}
    IF    "${opportunity_type}" == "Upgrade"
        UseModal    on
        Verify Text    Upgrade From
        Verify Text    Expansion Type
        PickList    Upgrade From    Enterprise
        PickList    Expansion Type    New Product
        Sleep    1
        VerifyPicklistSelection    Upgrade From    Enterprise
        VerifyPicklistSelection    Expansion Type    New Product
        ClickText    Confirm
        UseModal    off
        VerifyNoText    Expansion Type
    END
        
    # PickList has timing issues with field "potential plan"
    Custom Picklist    Potential Plan    ${potential_plan}

    Custom Picklist         *Contact Name    ${contact_name}    anchor=Buyer Type
    Custom Picklist         Select Buyer Type    ${buyer_type}
    PickList                Price Book    ${price_book}

    # Is there multiple AlgoliaApps to select from
    ${select_app}=    IsElement    xpath=//button[@aria-label="Algolia App, Select Algolia App" and @aria-required="true"]
    IF    ${select_app}
        ${value_not_selected}=    SetVariable    ${TRUE}
        # try opening the AlgoliaApp picklist and select the given value for 5 times
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

    # Change the opportunitys owner if it was given as an argument
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
    