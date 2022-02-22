@IsTest
public class TestDataFactory {

    private static final String CONNECTED_ORG_SETTINGS_CLIENT_KEY = 'test_client_key';
    private static final String CONNECTED_ORG_SETTINGS_CLIENT_SECRET = 'test_client_secret';

    public static void createConnectedOrgSettings() {
        Connected_Orgs_Settings__c connectedOrgsSettings = new Connected_Orgs_Settings__c(
                Client_Key__c = CONNECTED_ORG_SETTINGS_CLIENT_KEY,
                Client_Secret__c = CONNECTED_ORG_SETTINGS_CLIENT_SECRET
        );
        insert connectedOrgsSettings;
    }

    private static final String CONNECTED_ORG_TITLE = 'Test Title Connected Org';
    private static final String CONNECTED_ORG_DESCRIPTION = 'Test Description Connected Org';
    private static final String CONNECTED_ORG_TYPE = 'production';
    private static final String CONNECTED_CODE = 'test_code';
    private static final String CONNECTED_ORG_ACCESS_TOKEN = 'test_Access_Token';
    private static final String CONNECTED_ORG_REFRESH_TOKEN = 'test_Refresh_Token';
    private static final String CONNECTED_ORG_INSTANCE_URL = 'https://test_Instance_Url';
    private static final String CONNECTED_ORG_IDENTITY_URL = 'https://test_Identity_Url';

    public static final String ASYNC_APEX_JOB_JSON = '{' +
            '"attributes":{"type":"AsyncApexJob","url":"/services/data/v52.0/sobjects/AsyncApexJob/707KK00000KKK00KKK"},' +
            '"Id":"707KK00000KKK00KKK",' +
            '"JobType":"BatchApex",' +
            '"ExtendedStatus":"First error: Update failed. First exception on row 0; first error: MISSING_ARGUMENT, Id 707XXX000XXX000XXX not specified in an update call: [707KK00000KKK00KKK]",' +
            '"ApexClassId":"01pXXX000XXX000XXX",' +
            '"Status":"Completed",' +
            '"CompletedDate":' + JSON.serialize(System.now()) + ',' +
            '"ApexClass":{' +
            '"attributes":{' +
            '"type":"ApexClass",' +
            '"url":"/services/data/v52.0/sobjects/ApexClass/01pXXX000XXX000XXX"},' +
            '"Id":"01pXXX000XXX000XXX",' +
            '"Name":"JobBatch"' +
            '}}';

    public static void createConnectedOrg() {
        Connected_Org__c corg = new Connected_Org__c(
                Name = UserInfo.getOrganizationId().left(15),
                Title__c = CONNECTED_ORG_TITLE,
                Description__c = CONNECTED_ORG_DESCRIPTION,
                Type__c = CONNECTED_ORG_TYPE,
                Code__c = CONNECTED_CODE,
                Scheduler_Enabled__c = false,
                Access_Token__c = CONNECTED_ORG_ACCESS_TOKEN,
                Refresh_Token__c = CONNECTED_ORG_REFRESH_TOKEN,
                Token_Refreshed_At__c = Datetime.now(),
                Instance_Url__c = CONNECTED_ORG_INSTANCE_URL,
                Identity_Url__c = CONNECTED_ORG_IDENTITY_URL
        );
        List<Organization> lstOrganizations = [SELECT Id, IsSandbox FROM Organization];
        if (!lstOrganizations.isEmpty() && lstOrganizations[0].IsSandbox) {
            corg.Type__c = 'sandbox';
        }
        insert corg;
    }

    public class MultiRequestMock implements HttpCalloutMock {

        Map<String, HttpCalloutMock> requests;

        public MultiRequestMock(Map<String, HttpCalloutMock> requests) {
            this.requests = requests;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpCalloutMock mock = requests.get(req.getEndpoint());
            if (mock != null) {
                return mock.respond(req);
            }
            else {
                throw new MultiRequestMockException('HTTP callout not supported for test methods');
            }
        }

        public void addRequestMock(String url, HttpCalloutMock mock) {
            requests.put(url, mock);
        }
    }

    public class MultiRequestMockException extends Exception {}

    public class SingleRequestMock implements HttpCalloutMock {

        protected Integer code;
        protected String status;
        protected String body;
        protected String reqBody;

        public SingleRequestMock(Integer code, String status, String body) {
            this.code = code;
            this.status = status;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody(this.body);
            res.setStatusCode(this.code);
            res.setStatus(this.status);
            this.reqBody = req.getBody();
            return res;
        }

        public String getBodyRequest() {
            return this.reqBody;
        }
    }

    public class WebServiceMockImpl implements WebServiceMock {
        public void doInvoke(
                Object stub, Object request, Map<String, Object> response,
                String endpoint, String soapAction, String requestName,
                String responseNS, String responseName, String responseType)
        {
            if (request instanceof  MetadataService.upsertMetadata_element) {
                MetadataService.UpsertResult result = new MetadataService.UpsertResult();
                result.success = true;
                MetadataService.upsertMetadataResponse_element responseElement = new MetadataService.upsertMetadataResponse_element();
                responseElement.result = new MetadataService.UpsertResult[] {result};
                response.put('response_x', responseElement);
            }


        }
    }

    public static Log__c createTestNotificationLog() {
        String orgID = ConfigUtil.generateUUID4().left(15);
        Log__c log = new Log__c();
        log.Hash_1__c = 'hash1';
        log.Hash_2__c = 'hash2';
        log.Hash_3__c = 'hash3';
        log.Organization_Id__c = orgID;
        insert log;
        return log;
    }

    public static Action__c createEmailAction() {
        Action__c rn1 = createNotificationRuleAction();
        rn1.Subject__c = 'test';
        rn1.EmailBody__c = 'test';
        rn1.EmailTo__c = 'test@test.com';
        rn1.Action_Type__c = MonitoringUtil.ACTION_TYPE_EMAIL_NOTIFICATION;
        insert rn1;
        return rn1;
    }

    public static Action__c createTeamsAction() {
        Action__c rn1 = createNotificationRuleAction();
        rn1.Subject__c = 'test';
        rn1.Body__c = 'test';
        rn1.Team_Id__c = 'testTeamId';
        rn1.Channel_Id__c = 'testChannelId';
        rn1.Action_Type__c = MonitoringUtil.ACTION_TYPE_TEAMS_NOTIFICATION;
        insert rn1;
        return rn1;
    }

    public static Action__c createSlackAction() {
        Action__c rn1 = createNotificationRuleAction();
        rn1.Subject__c = 'test';
        rn1.Body__c = 'test';
        rn1.SlackChannels__c = '@test';
        rn1.Action_Type__c = MonitoringUtil.ACTION_TYPE_SLACK_NOTIFICATION;
        insert rn1;
        return rn1;
    }

    public static Action__c createPagerDutyAction(String pagerDutyType) {
        Action__c rn1 = createNotificationRuleAction();
        rn1.Subject__c = 'test';
        rn1.Body__c = 'test';
        rn1.Action_Type__c = MonitoringUtil.ACTION_TYPE_PAGERDUTY_NOTIFICATION;
        rn1.PagerDuty_Type__c = pagerDutyType;
        insert rn1;
        return rn1;
    }

    public static Action__c createNotificationRuleAction() {
        Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get('Monitoring').getRecordtypeId();
        Action__c rn1 = new Action__c();
        rn1.RecordTypeId = recordtypeId;
        rn1.Description__c = 'test';
        rn1.Subtype__c = MonitoringUtil.RULE_TYPE_NOTIFICATION;
        return rn1;
    }

    public static void createNotificationRule(Action__c action) {
        Rule__c mr1 = new Rule__c();
        mr1.Active__c = true;
        mr1.Type__c = MonitoringUtil.RULE_TYPE_NOTIFICATION;
        mr1.Index__c = 1;
        insert mr1;

        RuleAction__c en1 = new RuleAction__c();
        en1.Action__c = action.Id;
        en1.Rule__c = mr1.Id;
        insert en1;
    }

    public static void createTeamsSettings() {
        Graph_API_Settings__c graphSettings = new Graph_API_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Enabled__c = true,
            Tenant_Id__c = 'testTenantId'
        );
        insert graphSettings;
    }

    public static void createSlackSettings() {
        Slack_Settings__c slackSettings = new Slack_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Slack_Enabled__c = true,
            Slack_API_Token__c = '123321'
        );
        insert slackSettings;
    }

    public static void createPagerDutySettings() {
        Pager_Duty_Settings__c pagerDutySettings = new Pager_Duty_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            PagerDuty_Enabled__c = true,
            PagerDuty_API_Token__c = 'token',
            PagerDuty_Service_ID__c = 'serviceid',
            PagerDuty_User_Email__c = 'user@email.com',
            PagerDuty_Service_Integration_Key__c = 'key'
        );
        insert pagerDutySettings;
    }

    public static Rule__c createTestFilterRule() {
        Rule__c mr1 = new Rule__c();
        mr1.Index__c = 0;
        mr1.Active__c = true;
        mr1.Type__c =  MonitoringUtil.RULE_TYPE_JIRA_UPDATE;
        insert mr1;
        return mr1;
    }

    public static void setValidMonitoringRuleFields(Rule__c rule) {
        rule.AggregateType__c = 'Count';
        rule.AggregateInterval__c = 30;
        rule.Type__c = 'Monitoring';
        rule.Subtype__c = 'Spike';
        rule.ComparisonOperator__c = 'Greater or equal';
        rule.EventTimeInterval__c = 60;
        rule.FilterLogic__c = '1 OR 2';
        rule.Threshold__c = 1;
    }

    public static Rule__c createMonitoringRule(Boolean isValidRule, Boolean isValidFilters) {
        Rule__c mr1 = new Rule__c();
        mr1.Active__c = true;
        if(isValidRule) {
            setValidMonitoringRuleFields(mr1);
        }
        insert mr1;

        Action__c emailAction = TestDataFactory.createEmailAction();
        RuleAction__c en1 = new RuleAction__c();
        en1.Action__c = emailAction.Id;
        en1.Rule__c = mr1.Id;
        insert en1;

        String packagePrefix = ConfigUtil.nameSpacePrefix;
        RuleFilter__c rf1 = new RuleFilter__c();
        rf1.Index__c = isValidFilters ? 1 : 2;
        rf1.Rule__c = mr1.Id;
        rf1.ComparisonOperator__c = isValidFilters ? 'Not equal' : 'Contains';
        rf1.FieldName__c = packagePrefix + 'Type__c';
        rf1.Value__c = 'notTestType';
        rf1.Comparison_Type__c = 'Value';
        rf1.Field_Type__c = 'STRING';

        RuleFilter__c rf2 = new RuleFilter__c();
        rf2.Index__c = isValidFilters ? 2 : 3;
        rf2.Rule__c = mr1.Id;
        rf2.ComparisonOperator__c = 'Equal';
        rf2.FieldName__c = packagePrefix + 'Category__c';
        rf2.Value__c = 'TestCategory';
        rf2.Comparison_Type__c = 'Value';
        rf2.Field_Type__c = 'STRING';
        insert new List<RuleFilter__c>{rf1, rf2};
        return mr1;
    }

    public static Rule__c createArchivalRule(Boolean isValidRule, Boolean isValidFilters) {
        Rule__c mr1 = new Rule__c();
        mr1.Active__c = true;
        mr1.Type__c = MonitoringUtil.RULE_TYPE_ARCHIVAL;
        if(isValidRule) {
            mr1.EventTimeInterval__c = 60;
        }
        insert mr1;

        Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get(MonitoringUtil.RULE_TYPE_ARCHIVAL).getRecordtypeId();

        Action__c rn1 = new Action__c();
        rn1.RecordTypeId = recordtypeId;
        rn1.Description__c = 'test';
        rn1.Action_Type__c = 'Removal';
        insert rn1;

        RuleAction__c en1 = new RuleAction__c();
        en1.Action__c = rn1.Id;
        en1.Rule__c = mr1.Id;
        insert en1;

        String packagePrefix = ConfigUtil.nameSpacePrefix;
        if(isValidFilters) {
            RuleFilter__c rf1 = new RuleFilter__c();
            rf1.Index__c = 1;
            rf1.Rule__c = mr1.Id;
            rf1.ComparisonOperator__c = 'Greater than';
            rf1.FieldName__c = 'Created_At__c';
            rf1.Value__c = '3600';
            rf1.Comparison_Type__c = 'Value';

            RuleFilter__c rf2 = new RuleFilter__c();
            rf2.Index__c = 2;
            rf2.Rule__c = mr1.Id;
            rf2.ComparisonOperator__c = 'Equal';
            rf2.FieldName__c = packagePrefix + 'Category__c';
            rf2.Value__c = 'TestCategory';
            rf2.Comparison_Type__c = 'Value';
            rf2.Field_Type__c = 'STRING';
            insert new List<RuleFilter__c>{rf1, rf2};
        }
        return mr1;
    }

    public static Rule__c createJiraUpdateRule(Boolean isValidRule, Boolean isValidFilters) {
        Rule__c mr1 = new Rule__c();
        mr1.Active__c = true;
        mr1.Index__c = 0;
        if(isValidRule) {
            mr1.Type__c = MonitoringUtil.RULE_TYPE_JIRA_UPDATE;
        }
        insert mr1;

        Action__c defaultJiraAction = ConfigUtil.createDefaultJiraAction();
        RuleAction__c en1 = new RuleAction__c();
        en1.Action__c = defaultJiraAction.Id;
        en1.Rule__c = mr1.Id;
        insert en1;

        RuleFilter__c isNewFilter = new RuleFilter__c();
        isNewFilter.Index__c = 1;
        isNewFilter.Rule__c = mr1.Id;
        isNewFilter.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_EQUAL;
        isNewFilter.FieldName__c = Schema.sObjectType.Log__c.fields.Is_New__c.getName();
        isNewFilter.Value__c = (isValidFilters) ? 'true' : '123123123';
        isNewFilter.Comparison_Type__c = MonitoringUtil.COMPARISON_TYPE_VALUE;
        isNewFilter.Field_Type__c = MonitoringUtil.FIELD_TYPE_BOOLEAN;

        RuleFilter__c orgNameFilter = new RuleFilter__c();
        orgNameFilter.Index__c = 2;
        orgNameFilter.Rule__c = mr1.Id;
        orgNameFilter.ComparisonOperator__c = MonitoringUtil.COMPARISON_OPERATOR_EQUAL;
        orgNameFilter.FieldName__c = Schema.sObjectType.Log__c.fields.Organization_Name__c.getName();
        orgNameFilter.Value__c = UserInfo.getOrganizationName();
        orgNameFilter.Comparison_Type__c = MonitoringUtil.COMPARISON_TYPE_VALUE;
        orgNameFilter.Field_Type__c = MonitoringUtil.FIELD_TYPE_STRING;
        insert new List<RuleFilter__c>{isNewFilter, orgNameFilter};

        return mr1;
    }

}