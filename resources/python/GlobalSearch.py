from base64 import b64encode
import json

def get_search_query(term: str, record_type: str="") -> str:
    """Creates a base64 encoded search query for a global search url
    Search all record types:
        GetSearchQuery    something
    Search specific record type, for example account
        GetSearchQuery    Some account name    Account
    """
    query_dict = {
        "componentDef":"forceSearch:searchPageDesktop",
        "attributes":{
            "term":term,
            "context":{
                "FILTERS":{},
                "searchSource":"ASSISTANT_DIALOG",
                "disableIntentQuery":True,
                "disableSpellCorrection":True,
                "searchDialogSessionId":"00000000-0000-0000-0000-000000000000"
            },
            "groupId":"DEFAULT"},
        "state":{}
    }
    
    if record_type == "":
        query_dict['attributes']['scopeMap'] = {
                "type":"TOP_RESULTS",
                "namespace":"",
                "label":"Top Results",
                "labelPlural":"Top Results",
                "resultsCmp":"forceSearch:predictedResults"
            }
    else:
        query_dict['attributes']['scopeMap'] = {
                "label": record_type,
                "name":record_type,
                "id":record_type,
                "entity":record_type
            }
    
    return b64encode(
                json.dumps(query_dict).encode("utf-8")
            ).decode("utf-8")