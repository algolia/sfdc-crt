SETTING UP
    Credentials:
        From CRT dashboard go to Robot's 'Details & settings'
            create variables
                username
                password
        Alternatively you can set the credentials to
            resources/common/secrets.resource

            However this will mean that the credentials will be stored in VCS as plain text
    Create three suites from the UI with the CRT repo
        For one suite set execution parameter for V8 Standard tcs
            -i: v8-standard
        For one suite set execution parameter for V8.5 Elevate Ecomm tcs
            -i: v8.5-elevate-ecomm
        For one suite set execution parameter for generic cases (not tied to potential plan/price book)
            -i no-pricebook
    Execution parameters
        From CRT dashboard go to Robot's 'Details & settings'
            create execution parameter to exclude the test cases for creating base opportunities for manual Service Order document testing
                -e : so-gen

Test Cases
    All test cases have the Test Cases and tc-specific implementation keywords, most often there's a single kw called 'Test Implementation'
    TC data is specified in ../resources/test_data/cpq-xxx.yaml
        For the existing cases TC data has variables (keys) for each applicable pricebook / potential plan
        These variables will falsely show in IDE as errors as the IDE is not aware of these variables.
        For details about the data itself look at resources/test_data/data.md

Checking and creating daily accounts
    This is done with "CheckDailyAccount" kw
    For some reason the first account creation of the day tends to take a long time and might fail due to timeout (150s)
    If the account creation kw fails but account gets created, check that the AlgoliaApp and account contact have been created

Adjustments for testing with LiveEditor
    Comment out "CheckDailyAccount" from "Suite Setup Actions"
        LiveEditor startup has hidden timeout value and this kw will cause timeout almost certainly.
    Under kw "Test Implementation" add following lines to the start of the kw
        CheckDailyAccount
        ${data_dict}=    SetVariable    ${v8_standard}    # or some other data dictionary variable from the .yaml file
    Start LiveEditor with the "Live Test" button in the top bar
    Execute the lines added in previous steps under "Test implementation"
