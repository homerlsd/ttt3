public with sharing class ConfigUtil {

    public static final String PHAROS_APP_SETTINGS_NAME = 'Pharos';
    public static final Integer EVENT_CHART_MAX_RECORDS = 9000;
    public static final Integer MAX_LENGTH_TEXT_FIELD = 255;
    public static final String NEW_LINE_CARRIAGE_RETURN = '\r\n';

    public static Logger_Settings__c SETTINGS = Logger_Settings__c.getOrgDefaults();

    public static Map<String, Schema.SObjectType> MAP_GD {
        get {
            if(MAP_GD == null) {
                MAP_GD = Schema.getGlobalDescribe();
            }
            return MAP_GD;
        }
        private set;
    }

    @TestVisible
    public static Map<String, Schema.DescribeFieldResult> MAP_LOG_FIELDS {
        get {
            if(MAP_LOG_FIELDS == null) {
                MAP_LOG_FIELDS = new Map<String, Schema.DescribeFieldResult>();

                Map<String, Schema.SObjectField> sObjectFieldMap = Schema.SObjectType.Log__c.fields.getMap();
                for(String fieldName : sObjectFieldMap.keySet()) {
                    Schema.DescribeFieldResult sObjectFieldDescribe = sObjectFieldMap.get(fieldName).getDescribe();
                    MAP_LOG_FIELDS.put(fieldName, sObjectFieldDescribe);
                }

            }
            return MAP_LOG_FIELDS;
        }
        private set;
    }

    public static String nameSpacePrefix {
        get {
            if(nameSpacePrefix == null) {
              nameSpacePrefix = getNameSpacePrefix();
            }
            return nameSpacePrefix;
        }
        private set;
    }

    public static String URL_VF_CALLBACK_PAGE_SETTINGS {
        get {
            if(URL_VF_CALLBACK_PAGE_SETTINGS == null) {
                URL_VF_CALLBACK_PAGE_SETTINGS = System.URL.getSalesforceBaseUrl().toExternalForm() + '/apex/' + ConfigUtil.getNameSpacePrefix() + 'Settings';
            }
            return URL_VF_CALLBACK_PAGE_SETTINGS;
        }
        private set;
    }

    public static Boolean currentOrgIsSandbox {
        get {
            if(currentOrgIsSandbox == null) {
              currentOrgIsSandbox = currentOrgIsSandbox();
            }
            return currentOrgIsSandbox;
        }
        private set;
    }

    public static String currentOrgNameSpacePrefix {
        get {
            if(currentOrgNameSpacePrefix == null) {
                currentOrgNameSpacePrefix = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
                currentOrgNameSpacePrefix = (currentOrgNameSpacePrefix == null) ? '' : currentOrgNameSpacePrefix;
            }
            return currentOrgNameSpacePrefix;
        }
        private set;
    }

    public static String prefixCurrentOrgNamespace(String postfix) {
        String fullApiName = (String.isNotBlank(ConfigUtil.currentOrgNameSpacePrefix))
            ? (ConfigUtil.currentOrgNameSpacePrefix + '__' + postfix)
            : postfix;
        return fullApiName;
    }

    public static String getNameSpacePrefix() {
        Schema.DescribeSObjectResult dsr = Log__c.sObjectType.getDescribe();
        String namespacePrefix = dsr.getName().remove(dsr.getLocalName());
        return namespacePrefix;
    }

    public static String getNameSpace() {
        return getNameSpacePrefix().replace('__', '');
    }

    public static Boolean currentOrgIsSandbox() {
        return [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }

    public static final String NS = getNameSpacePrefix().replace('__', '');

    //From Logger

    public static final String ERROR_EMAIL_SERVICE_ADDRESS_NOT_FOUND = 'Email Service Address not found';
    public static final String JIRA_CLOUD_API_PREFIX = 'https://api.atlassian.com/ex/jira/';
    public static final String JIRA_CLOUD_API_RESOURCES_ENDPOINT = 'https://api.atlassian.com/oauth/token/accessible-resources';
    public static final String REMOTE_SITE_SETTINGS_JIRA_CLOUD_API_NAME = 'Pharos_ai_JIRA_CLOUD_API_URL';
    public static final String REMOTE_SITE_SETTINGS_JIRA_CLOUD_API_DESCRIPTION = 'Pharos.ai - Jira integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_JIRA_CLOUD_API_URL = 'https://api.atlassian.com';
    public static final String REMOTE_SITE_SETTINGS_JIRA_CLOUD_OAUTH_NAME = 'Pharos_ai_JIRA_CLOUD_OAUTH_URL';
    public static final String REMOTE_SITE_SETTINGS_JIRA_CLOUD_OAUTH_DESCRIPTION = 'Pharos.ai - Jira integration OAuth URL';
    public static final String JIRA_CLOUD_AUTHORIZE_ENDPOINT = 'https://auth.atlassian.com/authorize';
    public static final String JIRA_CLOUD_OAUTH_ENDPOINT = 'https://auth.atlassian.com/oauth/token';
    public static final String JIRA_CLOUD_SETTINGS_NAME = 'Jira';
    public static final String JIRA_CLOUD_OAUTH_USERNAME = 'oAuthUser';

    public class JiraResourceWrapper {
        public String id;
        public String url;
        public String name;
    }

    // From JiraService
    public static final String API_VERSION = '2';
    public static final Set<String> MERGE_FIELDS_SKIP_FIELD_NAMES = new Set<String> {'isdeleted'};
    public static final String GET_PRIORITIES_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/priority';

    // api version 3
    //public static final String GET_PROJECTS_ENDPOINT = ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c + '/rest/api/'+API_VERSION+'/project?expand=issueTypes';
    // api version 2
    public static final String GET_PROJECTS_ENDPOINT = ConfigUtil.JIRA_API_URL +'/rest/api/'+API_VERSION+'/issue/createmeta?';

    public static final String GET_PROJECT_ASSINABLE_USERS_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/user/assignable/search?project=';
    public static final String JQL_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/search';
    public static final String GET_CREATEMETA_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/issue/createmeta';
    public static final String GET_PROJECT_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/project/';
    public static final String GET_PROJECT_COMMENTS_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/project/projectId/components';
    public static final String JIRA_TASK_URL = ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c + '/browse/';
    public static final String CREATE_ISSUE_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/issue';
    public static final String CREATE_JIRA_PROPERTY_PHAROS_LOG_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/issue/issueKey/properties/pharos_log';
    public static final String CREATE_ISSUE_LINK_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/issueLink';
    public static final String GET_ISSUE_DETAILS_ENDPOINT = ConfigUtil.JIRA_API_URL + '/rest/api/'+API_VERSION+'/issue/';

    public static final String EXISTING_TICKET_LINKED_STATUS = 'Existing Ticket Linked';
    public static final String NEW_TICKET_CREATED_STATUS = 'New Ticket Created';
    public static final String TICKET_CREATE_ERROR_STATUS = 'Error';

    public static final String JIRA_API_URL {
        get {
            if(JIRA_API_URL == null) {
                JIRA_API_URL = (String.isNotBlank(JIRA_OAUTH_TOKEN) && ConfigUtil.JIRA_SETTINGS.Jira_Username__c == JIRA_CLOUD_OAUTH_USERNAME)
                    ? JIRA_SETTINGS.Jira_API_Url__c
                    : JIRA_SETTINGS.Jira_Base_Url__c;
            }
            return JIRA_API_URL;
        }
        set;
    }

    public static final String JIRA_OAUTH_TOKEN {
        get {
            if(JIRA_OAUTH_TOKEN == null) {
                // oAuth token
                if(ConfigUtil.JIRA_SETTINGS.Jira_Username__c == JIRA_CLOUD_OAUTH_USERNAME) {
                    JIRA_OAUTH_TOKEN = JiraService.getDecryptedJiraTokenFromCache();
                    if(JIRA_OAUTH_TOKEN == null) {
                        if(ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c != null){
                            JIRA_OAUTH_TOKEN = ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c;
                        }
                        if(ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c != null){
                            JIRA_OAUTH_TOKEN = JIRA_OAUTH_TOKEN + ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c;
                        }
                        if(ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c != null){
                            JIRA_OAUTH_TOKEN = JIRA_OAUTH_TOKEN + ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c;
                        }
                        if(ConfigUtil.JIRA_SETTINGS.Jira_API_Token4__c != null){
                            JIRA_OAUTH_TOKEN = JIRA_OAUTH_TOKEN + ConfigUtil.JIRA_SETTINGS.Jira_API_Token4__c;
                        }
                        if(ConfigUtil.JIRA_SETTINGS.Jira_API_Token5__c != null){
                            JIRA_OAUTH_TOKEN = JIRA_OAUTH_TOKEN + ConfigUtil.JIRA_SETTINGS.Jira_API_Token5__c;
                        }
                        if(ConfigUtil.JIRA_SETTINGS.Jira_API_Token6__c != null){
                            JIRA_OAUTH_TOKEN = JIRA_OAUTH_TOKEN + ConfigUtil.JIRA_SETTINGS.Jira_API_Token6__c;
                        }
                    }
                }
                // api token
                else {
                    JIRA_OAUTH_TOKEN = JIRA_SETTINGS.Jira_API_Token__c;
                }
            }
            return JIRA_OAUTH_TOKEN;
        }
        set;
    }

    public static final String JIRA_OAUTH_REFRESH_TOKEN {
        get {
            if(JIRA_OAUTH_REFRESH_TOKEN == null) {
                JIRA_OAUTH_REFRESH_TOKEN = JiraService.getDecryptedJiraRefreshTokenFromCache();
                if(JIRA_OAUTH_REFRESH_TOKEN == null) {
                    JIRA_OAUTH_REFRESH_TOKEN = ConfigUtil.JIRA_SETTINGS.Refresh_Token__c;
                }
            }
            return JIRA_OAUTH_REFRESH_TOKEN;
        }
        set;
    }

    public static final Map<String, String> JIRA_HEADERS {
        get {
            if (JIRA_HEADERS == null) {

                if(ConfigUtil.JIRA_SETTINGS.Jira_Username__c == JIRA_CLOUD_OAUTH_USERNAME) {
                    JIRA_HEADERS = HttpUtils.getHeadersAuthorizationAcceptJson('Bearer ' + JIRA_OAUTH_TOKEN);
                    JIRA_HEADERS.putAll(HttpUtils.getHeadersContentTypeJSON());
                }
                else {
                    Blob headerValue = Blob.valueOf(ConfigUtil.JIRA_SETTINGS.Jira_Username__c + ':' + JIRA_OAUTH_TOKEN);
                    String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
                    JIRA_HEADERS = HttpUtils.getHeadersAuthorizationAcceptJson(authorizationHeader);
                    JIRA_HEADERS.putAll(HttpUtils.getHeadersContentTypeJSON());
                }
            }
            return JIRA_HEADERS;
        }
        set;
    }

    // From AdminService
    public static final String BASE_URL = System.URL.getOrgDomainUrl().toExternalForm();
    public static final String SOAP_ENDPOINT_PREFIX = '/services/Soap/m/';
    public static final String SOAP_ENDPOINT = BASE_URL + '/services/Soap/m/39.0';
    public static final String TOOLING_ITEMS_KEY_RECORDS = 'records';
    public static final String TOOLING_ITEMS_KEY_SOBJECTS = 'sobjects';
    public static final String TOOLING_API_ENDPOINT = BASE_URL + '/services/data/v43.0/tooling';
    public static final String TOOLING_QUERY_PATH = '/services/data/v43.0/query?q=';
    public static final String DESCRIBE_SOBJECT_PATH = '/services/data/v43.0/sobjects/';
    public static final String TOOLING_QUERY_ENDPOINT = TOOLING_API_ENDPOINT + '/query?q=';
    public static final String TOOLING_QUERY_API_ENDPOINT = '/services/data/v43.0/tooling/query?q=';
    public static final String TOOLING_QUERY_API_51_ENDPOINT = '/services/data/v51.0/tooling/query?q=';
    public static final String TOOLING_QUERY_GET_EMAIL_APEX_EMAIL_NOTIFICATION = 'SELECT+Id,+Email+FROM+ApexEmailNotification+WHERE+UserId=null';
    public static final String TOOLING_API_CREATE_APEX_EMAIL_NOTIFICATION = TOOLING_API_ENDPOINT + '/sobjects/ApexEmailNotification';
    public static final String TOOLING_API_UPDATE_APEX_EMAIL_NOTIFICATION = TOOLING_API_CREATE_APEX_EMAIL_NOTIFICATION + '/';
    public static final String TOOLING_API_UPDATE_APEX_EMAIL_SERVICE_FUNCTION = BASE_URL + '/services/data/v51.0/sobjects/EmailServicesFunction/';
    public static final String TOOLING_API_UPDATE_PLATFORM_EVENT_SUBSCRIBER_CONFIG = '/services/data/v51.0/tooling/sobjects/PlatformEventSubscriberConfig';
    public static final String OVERRIDE_HTTP_METHOD_PATCH = '?_HttpMethod=PATCH';
    public static final String EMAIL_SERVICES_FUNCTION_ENDPOINT = BASE_URL + '/services/data/v39.0/sobjects/EmailServicesFunction';
    public static final String EMAIL_SERVICES_ADDRESS_ENDPOINT = BASE_URL + '/services/data/v39.0/sobjects/EmailServicesAddress';
    public static final String PERMISSIONS_RW_NOT_FOUND_MESSAGE = 'PermissionSet Log_Read_Write not found';
    public static final String PERMISSIONS_READ_NOT_FOUND_MESSAGE = 'PermissionSet Log_Read not found';
    public static final String FAILED_NO_ERRORS_MESSAGE = 'Request failed with no specified error.';
    public static final String MANY_EMAIL_SERVICE_FOUND_MESSAGE = 'There are many Email Services. Please remove all except one.';
    public static final String APEXUTILSOURCE_NOT_FOUND_MESSAGE = 'Static Resource with name ApexUtilSource not found';
    public static final String APEXUTILTESTSOURCE_NOT_FOUND_MESSAGE = 'Static Resource with name ApexUtilTestSource not found';
    public static final String PHAROS_LOG_SERVICE_SCHEDULER_NAME = 'PharosLogServiceScheduler';
    public static final String MONITORING_SERVICE_SCHEDULER_NAME = 'MonitoringServiceScheduler';
	public static final String JIRA_RESOLUTION_SCHEDULER_NAME = 'JiraResolutionServiceScheduler';
    public static final String ARCHIVAL_SCHEDULER_NAME = 'ArchivalServiceScheduler';
    public static final String APEX_UTIL_RESOURCE_NAME = 'ApexUtilSource';
    public static final String APEX_UTIL_TEST_RESOURCE_NAME = 'ApexUtilTestSource';
    public static final String METADATA_CONNECTED_APP_PAYLOAD_RESOURCE_NAME = 'ConnectedAppMetadataPayload';
    public static final String METADATA_REMOTE_SITE_PAYLOAD_RESOURCE_NAME = 'RemoteSiteSettingsPayload';
    public static final String EMAIL_SERVICE_HANDLER_NAME = 'ErrorEmailHandler';
    public static final String LOG_READ_PERMISSION_SET_NAME = 'Log_Read';
    public static final String LOG_READ_WRITE_PERMISSION_SET_NAME = 'Log_Read_Write';
    public static final String DEFAULT_ACTION_EMAIL_TEMPLATE_NAME = 'Default_Notification_Template';

    public static final EmailTemplate DEFAULT_ACTION_TEMPLATE {
        get {
            if (DEFAULT_ACTION_TEMPLATE == null) {
                DEFAULT_ACTION_TEMPLATE = [
                    SELECT Subject, Body
                    FROM EmailTemplate
                    WHERE DeveloperName = :DEFAULT_ACTION_EMAIL_TEMPLATE_NAME LIMIT 1
                ];
            }
            return DEFAULT_ACTION_TEMPLATE;
        }
        private set;
    }

    public static final Map<String, String> SF_REST_API_HEADERS {
        get {
            if (SF_REST_API_HEADERS == null) {
                SF_REST_API_HEADERS = HttpUtils.getHeadersAuthorization('Bearer ' + UserInfo.getSessionId());
                SF_REST_API_HEADERS.putAll(HttpUtils.getHeadersContentTypeJSON());
            }
            return SF_REST_API_HEADERS;
        }
        set;
    }

    // From JIraTaskController
    public static final String JIRA_TASK_NOT_FOUND_MESSAGE = 'JIRA Task not found. Do you want to create new one?';
    public static final String JIRA_SETTINGS_NOT_FOUND_MESSAGE = 'JIRA Settings not found.';

    // From LogDashboardController
    public static final String DAYS_7_OPTION = 'last 7 days';
    public static final String DAYS_30_OPTION = 'last 30 days';
    public static final String DAYS_60_OPTION = 'last 60 days';
    public static final String DAYS_180_OPTION = 'last 6 months';

    public static final String CHART_SAME_STACKTRACE_OPTION = 'Same stack trace';
    public static final String CHART_SIMILAR_STACKTRACE_OPTION = 'Similar stack trace and same method';
    //===timing tab
    public static final String STEP_1_OPTION = '1min';
    public static final String STEP_5_OPTION = '5min';
    public static final String STEP_10_OPTION = '10min';

    public static final String RANGE_10_OPTION = '10min';
    public static final String RANGE_30_OPTION = '30min';
    public static final String RANGE_60_OPTION = '60min';

    // From PagerDutyService
    public static Map<String, String> PAGER_DUTY_HEADERS {
        get {
            if(PAGER_DUTY_HEADERS == null) {
                PAGER_DUTY_HEADERS = HttpUtils.getHeadersAuthorizationAcceptPagerDutyJson('Token token=' + ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_API_Token__c);
                PAGER_DUTY_HEADERS.putAll(HttpUtils.getHeadersContentTypeJSON());
                PAGER_DUTY_HEADERS.putAll(HttpUtils.getHeadersFrom(ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_User_Email__c));
            }
            return PAGER_DUTY_HEADERS;
        }
        set;
    }

    public static Map<String, String> PAGER_DUTY_EVENTS_HEADERS {
        get {
            if(PAGER_DUTY_EVENTS_HEADERS == null) {
                PAGER_DUTY_EVENTS_HEADERS = HttpUtils.getHeadersAuthorization('Token token=' + ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_API_Token__c);
                PAGER_DUTY_EVENTS_HEADERS.putAll(HttpUtils.getHeadersContentTypeJSON());
            }
            return PAGER_DUTY_EVENTS_HEADERS;
        }
        set;
    }

    public static final List<String> EVENT_SEVERITY = new List<String> {
        'critical',
        'error',
        'warning',
        'info'
    };

    public static final String PAGER_DUTY_INCIDENT_ENDPOINT = 'https://api.pagerduty.com/incidents';
    public static final String PAGER_DUTY_SERVICES_ENDPOINT = 'https://api.pagerduty.com/services';
    public static final String PAGER_DUTY_EVENTS_ENDPOINT = 'https://events.pagerduty.com/v2/enqueue';

    // From SlackService
    public static String SLACK_DEFAULT_MESSAGE_TEMPLATE = 'New Log: {!pharos__Log__c.Name}\n{!pharos__Log__c.Link}';
    public static Map<String, String> SLACK_API_HEADERS  {
        get {
            if(SLACK_API_HEADERS == null) {
                SLACK_API_HEADERS = HttpUtils.getHeadersAuthorization('Bearer ' + ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c);
                SLACK_API_HEADERS.putAll(HttpUtils.getHeadersContentTypeJSON());
            }
            return SLACK_API_HEADERS;
        }
        set;
    }
    public static Map<String, String> SLACK_API_CONVERSATION_LIST_HEADERS {
        get {
            if(SLACK_API_CONVERSATION_LIST_HEADERS == null) {
                SLACK_API_CONVERSATION_LIST_HEADERS = HttpUtils.getHeadersAuthorization('Bearer ' + ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c);
                SLACK_API_CONVERSATION_LIST_HEADERS.putAll(HttpUtils.getHeadersContentTypeFormUrlencoded());
            }
            return SLACK_API_CONVERSATION_LIST_HEADERS;
        }
        set;
    }

    public static final String SLACK_AUTHORIZE_URL = 'https://slack.com/oauth/authorize';
    public static final String SLACK_POST_MESSAGE_ENDPOINT = 'https://slack.com/api/chat.postMessage';
    public static final String SLACK_CONVERSATION_LIST_ENDPOINT = 'https://slack.com/api/conversations.list?exclude_archived=true&types=public_channel,private_channel&limit=1000';

    // From SplunkService
    public static final String SPLUNK_TOKEN_ENDPOINT = ConfigUtil.SPLUNK_SETTINGS.Splunk_Url__c + '/services/auth/login?output_mode=json';
    public static final Map<String, String> SPLUNK_API_TOKEN_HEADERS = HttpUtils.getHeadersContentTypeFormUrlencoded();
    public static final String SPLUNK_MESSAGES_ENDPOINT = ConfigUtil.SPLUNK_SETTINGS.Splunk_Url__c + '/services/messages?output_mode=json';
    public static Map<String, String> SPLUNK_API_HEADERS {
        get {
            if(SPLUNK_API_HEADERS == null) {
                SPLUNK_API_HEADERS = HttpUtils.getHeadersAuthorization('Splunk ' + ConfigUtil.SPLUNK_SETTINGS.Splunk_Token__c);
                SPLUNK_API_HEADERS.putAll(SPLUNK_API_TOKEN_HEADERS);
            }
            return SPLUNK_API_HEADERS;
        }
        set;
    }

    public static final String SPLUNK_COLLECTOR_ENDPOINT = ConfigUtil.SPLUNK_SETTINGS.Splunk_Url__c + ':8088/services/collector?output_mode=json';
    public static final Map<String, String> SPLUNK_COLLECTOR_HEADERS {
        get {
            if(SPLUNK_COLLECTOR_HEADERS == null) {
                SPLUNK_COLLECTOR_HEADERS = HttpUtils.getHeadersAuthorization('Splunk ' + ConfigUtil.SPLUNK_SETTINGS.Splunk_Event_Collector_Token__c);
                SPLUNK_COLLECTOR_HEADERS.putAll(HttpUtils.getHeadersContentTypeFormUrlencoded());
            }
            return SPLUNK_COLLECTOR_HEADERS;
        }
        set;
    }

    // From StackTraceParser
    public static String STACKTRACE_BAD_SETTINGS_MESSAGE = 'Connection settings not found. Please setup Logger App.';
    public static String STACKTRACE_BASE_URL {
        get {
            if (String.isBlank(ConfigUtil.CONNECTED_ORGS_SETTINGS.Instance_Url__c)) {
                throw new StacktraceParser.StackTraceParserException(STACKTRACE_BAD_SETTINGS_MESSAGE);
            }
            return ConfigUtil.CONNECTED_ORGS_SETTINGS.Instance_Url__c + '/services/data/v43.0/tooling';
        }
        set;
    }

    public static String generateUUID4() {
        Blob b = Crypto.GenerateAESKey(128);
        String h = EncodingUtil.ConvertTohex(b);
        String guid = h.SubString(0,8)+ '-' + h.SubString(8,12) + '-' + h.SubString(12,16) + '-' + h.SubString(16,20) + '-' + h.substring(20);
        return guid;
    }

    // from ConnectedOrgService
    public static String INVALID_OAUTH_STATE_MESSAGE = 'Invalid OAuth State ';
    public static String CONNECTED_ORG_NOT_FOUND_MESSAGE = 'Connected Org not found ';
    public static String CONNECTED_ORG_NOT_SETTED = 'Environment information is not available. Org Id {0} not found. Please set up a connection to this org under Connected Orgs in Pharos Admin.';
    public static String getConnectedOrgNotSetError(String connectedOrgId) {
        return String.format(CONNECTED_ORG_NOT_SETTED, new List<String>{connectedOrgId});
    }
    public static String SF_OAUTH_TOKEN_ENDPOINT = '/services/oauth2/token';
    public static Map<String, String> OAUTH_HEADERS_MAP {
        get {
            if(OAUTH_HEADERS_MAP == null) {
                OAUTH_HEADERS_MAP = HttpUtils.getHeadersContentTypeFormUrlencoded();
                OAUTH_HEADERS_MAP.putAll(HttpUtils.getHeadersAcceptJson());
            }
            return OAUTH_HEADERS_MAP;
        }
        private set;
    }

    public static Map<String, String> getSFRestAPIHeaders(String accessToken) {
        Map<String, String> headers = HttpUtils.getHeadersAuthorization('Bearer ' + accessToken);
        headers.putAll(HttpUtils.getHeadersContentTypeJSON());
        return headers;
    }

    // from PassthroughtModeService and DataDirectionService
    public static String CONNECTED_ORG_NOT_FOUND_PASSTHROUGHMODE = 'Connected Org not found (PassthroughMode)';
    public static String CONNECTED_ORG_NOT_FOUND_BROADCAST = 'Connected Org not found (Broadcast)';
    public static String PARAMS_TYPE = 'type';
    public static String TYPE_PASSTHROUGH_MODE = 'passthroughMode';
    public static String TYPE_BROADCAST = 'broadcast';
    public static String ORIGINATED_FROM_BROADCAST = 'Broadcast';
    public static String ORIGINATED_FROM_PASSTHROUGH = 'Passthrough';
    public static String PHAROS_REST_SERVICE_ENDPOINT = '/services/apexrest/' + ConfigUtil.NS + '/logs';

    // Configs

    public class SplunkFieldsConfig {
        public List<String> splunk_fields;
        public SplunkFieldsConfig(){}
    }

    public class JiraFieldsMappingsConfig {
        public List<JiraFieldsMapping> jira_fields_mapping;
        public JiraFieldsMappingsConfig(){}
    }

    public class JiraFieldsMapping {
        public String logField;
        public String jiraField;
        public String issueTypeId;
    }

    public static JiraFieldsMappingsConfig JIRA_FIELDS_MAPPINGS {
        get {
            if (JIRA_FIELDS_MAPPINGS == null) {
                initJiraFieldsMappings();
            }
            return JIRA_FIELDS_MAPPINGS;
        }
        private set;
    }

    public static SplunkFieldsConfig SPLUNK_FIELDS {
        get {
            if (SPLUNK_FIELDS == null) {
                initSplunkFields();
            }
            return SPLUNK_FIELDS;
        }
        private set;
    }

    public static Jira_Settings__c JIRA_SETTINGS {
        get {
            if (JIRA_SETTINGS == null) {
                initJiraSettings();
            }
            return JIRA_SETTINGS;
        }
        private set;
    }

    public static Slack_Settings__c SLACK_SETTINGS {
        get {
            if (SLACK_SETTINGS == null) {
                initSlackSettings();
            }
            return SLACK_SETTINGS;
        }
        private set;
    }

    public static Graph_API_Settings__c GRAPH_API_SETTINGS {
        get {
            if (GRAPH_API_SETTINGS == null) {
                initGraphAPISettings();
            }
            return GRAPH_API_SETTINGS;
        }
        private set;
    }

    public static Pager_Duty_Settings__c PAGER_DUTY_SETTINGS {
        get {
            if (PAGER_DUTY_SETTINGS == null) {
                initPagerDutySettings();
            }
            return PAGER_DUTY_SETTINGS;
        }
        private set;
    }

    public static Connected_Orgs_Settings__c CONNECTED_ORGS_SETTINGS {
        get {
            if (CONNECTED_ORGS_SETTINGS == null) {
                initConnectedOrgsSettings();
            }
            return CONNECTED_ORGS_SETTINGS;
        }
        private set;
    }

    public static Splunk_Settings__c SPLUNK_SETTINGS {
        get {
            if (SPLUNK_SETTINGS == null) {
                initSplunkSettings();
            }
            return SPLUNK_SETTINGS;
        }
        private set;
    }

    public static Git_API_Settings__c GIT_API_SETTINGS {
        get {
            if (GIT_API_SETTINGS == null) {
                initGitAPISettings();
            }
            return GIT_API_SETTINGS;
        }
        private set;
    }

    public static Change_Tracking__c CHANGE_TRACKING_SETTINGS {
        get {
            if (CHANGE_TRACKING_SETTINGS == null) {
                initChangeTrackingSettings();
            }
            return CHANGE_TRACKING_SETTINGS;
        }
        private set;
    }

    public static void initChangeTrackingSettings() {
        CHANGE_TRACKING_SETTINGS = Change_Tracking__c.getOrgDefaults();
    }

    public static void initGitAPISettings() {
        GIT_API_SETTINGS = Git_API_Settings__c.getOrgDefaults();
    }

    public static Pharos_Settings__c PHAROS_SETTINGS {
        get {
            if (PHAROS_SETTINGS == null) {
                initPharosSettings();
            }
            return PHAROS_SETTINGS;
        }
        private set;
    }

    public static void initPharosSettings() {
        PHAROS_SETTINGS = Pharos_Settings__c.getOrgDefaults();
    }

    public static void initSplunkSettings() {
        SPLUNK_SETTINGS = Splunk_Settings__c.getOrgDefaults();
    }

    public static void initJiraSettings() {
        JIRA_SETTINGS = JIRA_Settings__c.getOrgDefaults();
    }

    public static void initConnectedOrgsSettings() {
        CONNECTED_ORGS_SETTINGS = Connected_Orgs_Settings__c.getOrgDefaults();
    }

    public static void initPagerDutySettings() {
        PAGER_DUTY_SETTINGS = Pager_Duty_Settings__c.getOrgDefaults();
    }

    public static void initSlackSettings() {
        SLACK_SETTINGS = Slack_Settings__c.getOrgDefaults();
    }

    public static void initGraphAPISettings() {
        GRAPH_API_SETTINGS = Graph_API_Settings__c.getOrgDefaults();
    }

    public static void initJiraFieldsMappings() {
        JIRA_FIELDS_MAPPINGS = new JiraFieldsMappingsConfig();
        JIRA_FIELDS_MAPPINGS.jira_fields_mapping = getJiraFieldsMappings();
    }

    public static void initSplunkFields() {
        SPLUNK_FIELDS = new SplunkFieldsConfig();
        SPLUNK_FIELDS.splunk_fields = getSplunkFields();
    }

    public static List<JiraFieldsMapping> getJiraFieldsMappings() {
        List<JiraFieldsMapping> result = new List<JiraFieldsMapping>();

        Map<String, Jira_Fields_Mapping__c> allSettings = Jira_Fields_Mapping__c.getAll();
        for(Jira_Fields_Mapping__c setting : allSettings.values()) {
            JiraFieldsMapping mapping = new JiraFieldsMapping();
            if(String.isNotBlank(setting.Log_Field__c)
                    && String.isNotBlank(setting.Jira_Field__c)) {

                mapping.logField = setting.Log_Field__c;
                mapping.jiraField = setting.Jira_Field__c;
                mapping.issueTypeId = setting.Issue_Type_Id__c;
                result.add(mapping);
            }
        }

        return result;
    }

    public static void setJiraFieldsMappings(List<JiraFieldsMapping> mappings) {
        List<Jira_Fields_Mapping__c> toUpsert = new List<Jira_Fields_Mapping__c>();
        List<Jira_Fields_Mapping__c> toDelete = new List<Jira_Fields_Mapping__c>();
        Map<String, Jira_Fields_Mapping__c> allSettings = Jira_Fields_Mapping__c.getAll();
        Set<String> existJiraFields = new Set<String>();

        for(JiraFieldsMapping mapping : mappings) {
            if(String.isNotBlank(mapping.logField)
                && String.isNotBlank(mapping.jiraField)) {

                existJiraFields.add(mapping.jiraField);
                toUpsert.add(new Jira_Fields_Mapping__c(
                    Name = mapping.jiraField,
                    Log_Field__c = mapping.logField,
                    Jira_Field__c = mapping.jiraField,
                    Issue_Type_Id__c = mapping.issueTypeId
                ));
            }
        }
        for(Jira_Fields_Mapping__c setting : allSettings.values()) {
            if(String.isNotBlank(setting.Jira_Field__c) && !existJiraFields.contains(setting.Jira_Field__c)) {
                toDelete.add(setting);
            }
        }


        if(!toUpsert.isEmpty()) {
            upsert toUpsert Name;
        }
        if(!toDelete.isEmpty()) {
            delete toDelete;
        }
    }

    public static List<String> getSplunkFields() {
        List<String> result = new List<String>();

        Map<String, Splunk_Fields__c> allSettings = Splunk_Fields__c.getAll();
        for(Splunk_Fields__c setting : allSettings.values()) {
            if(String.isNotBlank(setting.Field_Name__c)) {
                result.add(setting.Field_Name__c);
            }
        }

        return result;
    }

    public static void setSplunkFields(List<String> fields) {
        List<Splunk_Fields__c> toUpsert = new List<Splunk_Fields__c>();

        for(String fieldName : fields) {
            toUpsert.add(new Splunk_Fields__c(Name = fieldName, Field_Name__c = fieldName));
        }
        upsert toUpsert Name;
    }

    public static List<String> getAvailableSplunkFields() {
        List<String> fields = new List<String>();
        List<FieldSetMember> fieldsFS = SObjectType.Log__c.FieldSets.Splunk_Fields.getFields();
        Set<String> skipFieldNames = new Set<String>();
        for(Schema.FieldSetMember fsm : fieldsFS) {
            fields.add(fsm.getFieldPath());
        }
        return fields;
    }

    public static Action__c getDefaultJiraAction() {
        return getDefaultAction(MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION);
    }

    public static Action__c getDefaultAction(String type) {
        List<Action__c> actions = [
            SELECT Id, Subject__c, Body__c, JIRAAssignee__c, JIRAAssignee_Id__c, JIRAComponents__c,
                JIRAEpic__c, JIRAIssueType__c, JIRALabels__c, JIRAPriority__c, JIRAProject__c
            FROM Action__c
            WHERE (Type__c = :type OR Action_Type__c = :type) AND Subtype__c = :MonitoringUtil.ACTION_SUBTYPE_DEFAULT
            LIMIT 1
        ];
        return actions.isEmpty() ? null : actions.get(0);
    }

    public static Action__c createDefaultJiraAction() {
        Action__c defaultJiraAction = new Action__c(Action_Type__c = MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION, Subtype__c = MonitoringUtil.ACTION_SUBTYPE_DEFAULT);
        insert defaultJiraAction;
        return defaultJiraAction;
    }

    // AdminService

    public static final String REST_REMOTE_SITE_SETTINGS_QUERY = 'SELECT+Id,IsActive,SiteName,EndpointUrl+FROM+RemoteProxy+WHERE+IsActive+=+TRUE';

    public static Map<String, String> getRemoteSiteSettingsHeadersMap(String sessionId) {
        return new Map<String, String> {
            'Authorization' => 'Bearer ' + sessionId,
            'Content-Type' => 'application/json'
        };
    }

    public static final String REMOTE_SITE_SETTINGS_KEY_RECORDS = 'records';
    public static final String CONNECTED_ORGS_INFO_KEY_SETTINGS = 'settings';
    public static final String CONNECTED_ORGS_INFO_KEY_CONNECTED_ORGS = 'connectedOrgs';
    public static final String CONNECTION_ORG_KEY_CORG = 'corg';
    public static final String CONNECTION_ORG_KEY_CLIENT_KEY = 'clientKey';
    public static final String EXCEPTION_CONNECTED_ORG_NOT_FOUND = 'Connected Org not found';
    public static final String EXCEPTION_CONNECTED_ORG_DELETE_FAIL = 'Org not found. Unable to delete connected org';
    public static final String CONNECTED_ORG_TESTING_KEY_SUCCESS = 'Success!';
    public static final String CONNECTED_ORG_TESTING_KEY_FAIL = 'Connection Test Fail';
    public static final String CURRENT_ORG_IS_SANDBOX_KEY = 'isSandbox';


    public static Map<String, String> REQUEST_CREATE_REMOTE_SITE_SETTINGS_HEADERS_MAP {
        get {
            return new Map<String, String> {
                'SOAPAction' => '""',
                'Content-Type' => 'text/xml'
            };
        }
        private set;
    }

    public static final String REMOTE_SITE_SETTINGS_GIT_HUB_API_NAME = 'Pharos_ai_GitHub_API_token_URL';
    public static final String REMOTE_SITE_SETTINGS_GIT_HUB_API_DESCRIPTION = 'Pharos.ai - GitHubAPI integration URL';
    public static final String REMOTE_SITE_SETTINGS_GIT_HUB_API_URL = 'https://api.github.com';

    public static final String REMOTE_SITE_SETTINGS_GIT_HUB_NAME = 'Pharos_ai_GitHub_token_URL';
    public static final String REMOTE_SITE_SETTINGS_GIT_HUB_DESCRIPTION = 'Pharos.ai - GitHub integration URL';
    public static final String REMOTE_SITE_SETTINGS_GIT_HUB_URL = 'https://github.com';


    public static final String REMOTE_SITE_SETTINGS_GRAPH_API_TOKEN_REQUEST_NAME = 'Pharos_ai_Graph_API_token_URL';
    public static final String REMOTE_SITE_SETTINGS_GRAPH_API_TOKEN_REQUEST_DESCRIPTION = 'Pharos.ai - Graph integration API token URL';
    public static final String REMOTE_SITE_SETTINGS_GRAPH_API_TOKEN_REQUEST_URL = 'https://login.microsoftonline.com';

    public static final String REMOTE_SITE_SETTINGS_GRAPH_API_REQUEST_NAME = 'Pharos_ai_Graph_API_URL';
    public static final String REMOTE_SITE_SETTINGS_GRAPH_API_REQUEST_DESCRIPTION = 'Pharos.ai - Graph integration API URL';
    public static final String REMOTE_SITE_SETTINGS_GRAPH_API_REQUEST_URL = 'https://graph.microsoft.com';

    public static final String REMOTE_SITE_SETTINGS_SLACK_API_NAME = 'Pharos_ai_Slack_API_URL';
    public static final String REMOTE_SITE_SETTINGS_SLACK_DESCRIPTION = 'Pharos.ai - Slack integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_SLACK_API_URL = 'https://slack.com';
    public static final String SAVE_SLACK_SETTINGS_SUCCESS = 'success';

    public static final String REMOTE_SITE_SETTINGS_PAGER_DUTY_API_NAME = 'Pharos_ai_PagerDuty_API_URL';
    public static final String REMOTE_SITE_SETTINGS_PAGER_DUTY_DESCRIPTION = 'Pharos.ai - PagerDuty integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_PAGER_DUTY_URL = 'https://api.pagerduty.com';
    public static final String REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_API_NAME = 'Pharos_ai_PagerDutyEvent_API_URL';
    public static final String REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_DESCRIPTION = 'Pharos.ai - PagerDutyEvent integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_URL = 'https://events.pagerduty.com';
    public static final String SAVE_PAGER_DUTY_SETTINGS_SUCCESS = 'success';

    public static final String EMAIL_SERVICE_DATA_KEY_EMAIL  = 'email';
    public static final String EMAIL_SERVICE_DATA_KEY_ERROR_CODE  = 'errorCode';
    public static final String EMAIL_SERVICE_DATA_KEY_CONFIRMED  = 'confirmed';
    public static final String EMAIL_SERVICE_DATA_KEY_EMAIL_SYMBOL  = '@';

    public static final String LOGGER_WRAPPER_INFO_KEY_CODE = 'code';
    public static final String LOGGER_WRAPPER_INFO_KEY_TEST_CODE = 'testCode';

    public static String getRequestBodyCreateEmailServiceFunction(String ehClassId) {
        return '{'+
            '  "IsActive": true,'+
            '  "ApexClassId": "'+ehClassId+'",'+
            '  "FunctionName": "ErrorEmailHandler",'+
            '  "IsTlsRequired": false,'+
            '  "OverLimitAction": "2",'+
            '  "AttachmentOption": "3",'+
            '  "AuthorizedSenders": "",'+
            '  "ErrorRoutingAddress": "",'+
            '  "AddressInactiveAction": "2",'+
            '  "IsErrorRoutingEnabled": false,'+
            '  "FunctionInactiveAction": "2",'+
            '  "IsAuthenticationRequired": false,'+
            '  "IsTextAttachmentsAsBinary": false,'+
            '  "AuthorizationFailureAction": "2",'+
            '  "AuthenticationFailureAction": "2"'+
        '}';
    }

    public static String getRequestBodyCreateEmailService(String responseId) {
        return '{'+
            '  "IsActive": true,'+
            '  "LocalPart": "ErrorEmailHandlerAddress",'+
            '  "FunctionId": "'+responseId+'",'+
            '  "RunAsUserId": "'+UserInfo.getUserId()+'",'+
            '  "AuthorizedSenders": ""'+
        '}';
    }

    public static final String CONFIRM_EMAIL_SERVICE_KEY_VALUE = 'value';
    public static final String CONFIRM_EMAIL_SERVICE_KEY_EMAIL = 'email';
    public static final String CONFIRM_AUTOMATED_FLOW_ERROR_TRACKING_KEY = 'flowErrorTracking';
    public static final String CONFIRM_EMAIL_TO_CASE_ERROR_TRACKING_KEY = 'emailToCaseTracking';
    public static final String CONFIRM_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_KEY = 'emailToCaseTrackingStatus';
    public static final String CONFIRM_EMAIL_TO_CASE_ERROR_TRACKING_ENABLED_KEY = 'enabledEmailToCaseTracking';
    public static final String EXCEPTION_ERROR_EMAIL_HANDLER_NOT_FOUND = '__ErrorEmailHandler not found';

    public static final String BATCH_ERROR_TRACKING_ENABLED = 'batchErrorTrackingEnabled';

    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG0 = 'flag0';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG1 = 'flag1';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG2 = 'flag2';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG3 = 'flag3';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG4 = 'flag4';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG5 = 'flag5';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG6 = 'flag6';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG7 = 'flag7';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG8 = 'flag8';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_FLAG9 = 'flag9';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS = 'progress';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_PASSTHROUGHT_MODE_ENABLED = 'passthroughtModeEnabled';
    public static final String CONFIGURATION_OVERVIEW_DATA_KEY_INTEGRATION_PROGRESS = 'integrationProgress';
    public static final String PHAROS_LOG_SERVICE_SCHEDULER_CRON_EXP = '0 0 */1 * * ?';
    public static final String JIRA_RESOLUTION_SCHEDULER_CRON_EXPR = '0 5 */8 * * ?';
    public static final String ARCHIVAL_SCHEDULER_CRON_EXPR = '0 0 * * * ?';

    public static final String CREATE_META_REQUEST_DATA_KEY_PROJECT_ID = 'projectId';
    public static final String CREATE_META_REQUEST_DATA_KEY_ISSUE_TYPE_ID = 'issueTypeId';
    public static final String CREATE_META_REQUEST_DATA_KEY_META = 'meta';
    public static final String CREATE_META_REQUEST_DATA_KEY_LOG_FIELDS = 'logFields';
    public static final String CREATE_META_REQUEST_DATA_KEY_COMPONENTS = 'components';
    public static final String CREATE_META_REQUEST_DATA_KEY_EPICS = 'epics';
    public static final String CREATE_META_REQUEST_DATA_KEY_FIELDS_MAPPING = 'fieldsMapping';

    public static final String SAVE_JIRA_FIELDS_MAPPINGS_SUCCESS = 'Ok';
    public static final String SAVE_JIRA_SETTINGS_SUCCESS = 'success';
    public static final String PICKLIST_KEY_NAME = 'name';
    public static final String PICKLIST_KEY_LABEL = 'label';
    public static final String PICKLIST_KEY_VALUE = 'value';
    public static final String PICKLIST_KEY_VALUES = 'values';
    public static final String PICKLIST_KEY_TYPE = 'type';

    public static final String REMOTE_SITE_SETTINGS_JIRA_NAME = 'Pharos_ai_Jira_API_URL';
    public static final String REMOTE_SITE_SETTINGS_JIRA_DESCRIPTION = 'Pharos.ai - Jira integration API login URL';
    public static final String SEND_SPLUNK_MESSAGE_KEY_MESSAGE = 'message';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_WEB_NAME = 'Pharos_ai_SplunkWeb_URL';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_WEB_DESCRIPTION = 'Pharos.ai - SplunkWeb integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_API_NAME = 'Pharos_ai_Splunk_API_URL';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_API_DESCRIPTION = 'Pharos.ai - Splunk integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_API_PORT = ':8089';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_NAME = 'Pharos_ai_SplunkEventCollector_API_URL';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_DESCRIPTION = 'Pharos.ai - SplunkEventCollector integration API login URL';
    public static final String REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_PORT = ':8088';

    public static final String CONNECTED_APP_NAME = 'Pharos.ai';//'PharosApp';
    public static final String  CONNECTED_APP_API_NAME = 'Pharos_ai';
    public static final String PHAROS_PACKAGE_PUBLISHER = 'Golden Ratio Systems LLC';
    // https://loggertest1.ap4.visual.force.com/apex/Settings
    public static final String CONNECTED_APP_CALLBACK_PAGE_URL = '/apex/Settings';

    public static final String HANDLE_SAVE_RESULT_KEY_ERROR = 'Error ';
    public static final String HANDLE_SAVE_RESULT_KEY_ERRORS = 'Errors ';
    public static final String HANDLE_SAVE_RESULT_KEY_COMPONENTS = 'occured processing component ';
    public static final String HANDLE_SAVE_RESULT_KEY_FIELDS = ' Fields ';

    public static final String SENSETIVE_MASK_KEY_ID = 'id';
    public static final String SENSETIVE_MASK_KEY_TEXT = 'text';
    public static final String SENSETIVE_MASK_KEY_REGEX = 'regex';
    public static final String SENSETIVE_MASK_KEY_MASK = '********';

    public static final String PERMISSION_SET_KEY_USER_ID = 'userId';
    public static final String PERMISSION_SET_KEY_PERMISSION_SET_ID = 'permissionSetId';
	public static final String SLACK_SERVICE_NAME = 'Slack';
	public static final String PAGER_DUTY_SERVICE_NAME = 'PagerDuty';
    public static final String TEAMS_SERVICE_NAME = 'Teams';

    public static final String PERMISSION_SET_ASSIGNMENT_KEY_ID = 'assignmentId';
    public static final String LOG_CATEGORIES_KEY_CATEGORIES = 'categories';
    public static final String LOG_CATEGORIES_KEY_RECORDTYPES = 'recordtypes';
    public static final String LOG_CATEGORIES_KEY_MAPPINGS = 'mappings';
    public static final String SAVE_LOG_CATEGORIES_SUCCESS = 'success';

    public static final String MONITORING_APP_KEY_JIRA_RULES = 'jirarules';
    public static final String MONITORING_APP_KEY_RULE_COMPARISON_OPERATORS = 'comparisonoperators';
    public static final String MONITORING_APP_KEY_RULE_FILTER_COMPARISON_OPERATORS = 'rulefiltercomparisonoperators';
    public static final String MONITORING_APP_KEY_FILTERS = 'filters';
    public static final String MONITORING_APP_KEY_ACTIONS = 'notifications';
    public static final String MONITORING_APP_KEY_RULE_ACTIONS = 'notificationsassignee';
    public static final String MONITORING_APP_KEY_LOG_FIELDS = 'logfields';
    public static final String MONITORING_APP_KEY_SERVICE_ENABLE = 'servicesenable';
    public static final String MONITORING_APP_KEY_ACTION_TYPES = 'actiontypesmap';
    public static final String MONITORING_APP_KEY_RULE_SUB_TYPES = 'rulesubtypes';
    public static final String MONITORING_APP_KEY_USER_TIMEZONE_OFFSET = 'usertimezoneoffset';

    public static final String MONITORING_APP_KEY_NOTIFICATION_ENABLED = 'notificationEnabled';
    public static final String MONITORING_APP_KEY_NOTIFICATION_RULES = 'notificationrules';

    public static final String MONITORING_APP_KEY_ARCHIVAL_ENABLED = 'archivalEnabled';
    public static final String MONITORING_APP_KEY_ARCHIVAL_RULES = 'archivalrules';
    public static final String MONITORING_APP_KEY_MONITORING_ENABLED = 'monitoringEnabled';
    public static final String MONITORING_APP_KEY_MONITORING_RULES = 'monitoringrules';

    public static final String MONITORING_APP_KEY_BROADCAST_RULES = 'broadcastrules';

    public static final String MONITORING_APP_KEY_ACTION_ID = 'actionid';
    public static final String MONITORING_APP_KEY_ASSIGNED_RULES = 'assignedRules';
    public static final String MONITORING_APP_KEY_ENABLED = 'enabled';

    public static final String MONITORING_APP_KEY_RULE_ID = 'ruleid';
    public static final String MONITORING_APP_KEY_RULE_TYPE = 'ruleType';
    public static final String MONITORING_APP_KEY_JIRA_RULE_ID = 'jirarule';
    public static final String MONITORING_APP_KEY_ARCHIVAL_RULE_ID = 'archivalrule';
    public static final String MONITORING_APP_KEY_MONITORING_RULE_ID = 'monitoringrule';
    public static final String MONITORING_APP_KEY_NOTIFICATION_RULE_ID = 'notificationrule';
    public static final String MONITORING_APP_KEY_BROADCAST_RULE_ID = 'broadcastrule';
    public static final String MONITORING_APP_KEY_RULE_ACTION_ID = 'ruleactionid';
    public static final String MONITORING_APP_KEY_RULE_INDEX = 'ruleindex';
    public static final String DELETE_MONITORING_RULE_KEY_SUCCESS = 'success';
    public static final String DELETE_MONITORING_RULE_KEY_MESSAGE = 'message';
    public static final String DELETE_MONITORING_RULE_MESSAGE_BAD_PARAMS = 'bad Rule Id';
    public static final String DELETE_MONITORING_RULE_ACTION_KEY_SUCCESS = 'success';
    public static final String DELETE_MONITORING_RULE_ACTION_KEY_MESSAGE = 'message';
    public static final String DELETE_MONITORING_RULE_ACTION_KEY_ACTION_RESULT = 'actionResult';
    public static final String DELETE_MONITORING_RULE_ACTION_KEY_RULE_ACTION_RESULT = 'ruleActionResult';

    public static final String PLATFORM_EVENT_SUBSCRIBER_CONFIG_TRIGGER_NAME = 'LogEventTrigger';
    public static final String PLATFORM_EVENT_SUBSCRIPTION_CONFIG_URL = System.Url.getOrgDomainUrl().toExternalForm() + '/setup/build/SharedSubscriptionsPage.apexp';

    public static String PRODUCTION_LOGIN_URL = 'login.salesforce.com';
    public static String SANDBOX_LOGIN_URL = 'test.salesforce.com';
    public static String SALESFORCE_DOMAIN = 'my.salesforce.com';
    public static String CUSTOM_DOMAIN_SYMBOLS = '--';

    public static final String EVENT_ACTION_DELIVERED_TO_SLACK = 'Slack Channels:';
    public static final String EVENT_ACTION_DELIVERED_TO_JIRA = 'JIRA Ticket:';
    public static final String EVENT_ACTION_DELIVERED_TO_EMAIL = 'Emails:';
    public static final String EVENT_ACTION_DELIVERED_TO_PAGER_DUTY = 'Pager Duty ';
    public static final String EVENT_ACTION_DELIVERED_TO_REMOVAL = 'Record Removed';
    public static final String EVENT_ACTION_DELIVERED_TO_LOCAL_ARCHIVAL = 'Archival_Log__b Big Object';
    public static final String EVENT_ACTION_DELIVERED_TO_SPLUNK = 'Sent to Splunk';

    public static final Pattern SOBJECT_ID_PATTERN = Pattern.compile('([a-zA-Z0-9]{15,18})');
    public static final String REGEX_SOBJECT_ID = '([a-zA-Z0-9]{15,18})';
    public static final String REGEX_DIGIT = '[0-9]';

}