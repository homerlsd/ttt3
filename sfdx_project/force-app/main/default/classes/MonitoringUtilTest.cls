@IsTest
public class MonitoringUtilTest {

    @TestSetup
    private static void testSetup() {
        Slack_Settings__c slackSettings = new Slack_Settings__c(
            Slack_Enabled__c = true,
            Slack_API_Token__c = '123321'
        );
        insert slackSettings;

        Logger_Settings__c settings = Logger_Settings__c.getOrgDefaults();
        settings.Monitoring_Enabled__c = true;
        insert settings;

        Jira_Settings__c jiraSettings = new Jira_Settings__c();
        jiraSettings.Jira_Base_Url__c = 'http://test.jira.com';
        jiraSettings.Jira_Username__c = 'jirausername';
        jiraSettings.Jira_API_Token__c = 'sometoken';
        insert jiraSettings;

        Jira_Fields_Mapping__c jiraMappings = new Jira_Fields_Mapping__c();
        jiraMappings.Name = ConfigUtil.generateUUID4();
        jiraMappings.Log_Field__c = 'Id';
        jiraMappings.Jira_Field__c = 'Id';
        jiraMappings.Issue_Type_Id__c = '10001';
        insert jiraMappings;

        Splunk_Fields__c splunkFields = new Splunk_Fields__c();
        splunkFields.Name = 'Id';
        splunkFields.Field_Name__c = 'Id';
        insert splunkFields;
    }

    public class MultiRequestMock implements HttpCalloutMock {
        Map<String, HttpCalloutMock> requests;

        public MultiRequestMock(Map<String, HttpCalloutMock> requests) {
            this.requests = requests;
        }

        public HTTPResponse respond(HTTPRequest req) {
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

        public HTTPResponse respond(HTTPRequest req) {

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

    @IsTest
    public static void test_scheduler() {
        Test.startTest();

        Datetime dt = DateTime.now().addSeconds(30);
        String cronExp = dt.second() + ' ' + dt.minute() + ' ' + dt.hour() +
                ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();

        String jobId = System.schedule('testMonitoringBatch',
                cronExp,
                new MonitoringBatch());

        Test.stopTest();
    }

    @IsTest
    public static void test_archival_rule_archival_bigobject_positive() {
        test_archival_rule('Local Archival', false, true);
    }
    @IsTest
    public static void test_archival_rule_archival_bigobject_with_event_positive() {
        test_archival_rule('Local Archival', true, true);
    }
    @IsTest
    public static void test_archival_rule_removal_positive() {
        test_archival_rule('Removal', false, true);
    }
    @IsTest
    public static void test_archival_rule_removal_with_event_positive() {
        test_archival_rule('Removal', true, true);
    }
    @IsTest
    public static void test_archival_rule_external_archival_positive() {
        test_archival_rule('External Archival', false, true);
    }
    @IsTest
    public static void test_archival_rule_external_archival_with_event_positive() {
        test_archival_rule('External Archival', true, true);
    }
    public static void test_archival_rule(String notificationType, Boolean withEvent, Boolean isPositive) {
        String packagePrefix = ConfigUtil.nameSpacePrefix;

        Rule__c mr1 = new Rule__c();
        mr1.Active__c = true;
        mr1.Type__c = MonitoringUtil.RULE_TYPE_ARCHIVAL;
        mr1.EventTimeInterval__c = withEvent ? 1*60 : 5*60;
        insert mr1;

        Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get(MonitoringUtil.RULE_TYPE_ARCHIVAL).getRecordtypeId();

        Action__c rn1 = new Action__c();
        rn1.RecordTypeId = recordtypeId;
        rn1.Description__c = 'test';
        rn1.Subject__c = 'test';
        rn1.Body__c = 'test';
        rn1.EmailBody__c = 'test';
        rn1.SlackChannels__c = 'test';
        rn1.EmailTo__c = 'test@test.cc';
        rn1.EmailCC__c = 'test2@test.cc';
        rn1.JIRALabels__c = 'test';
        rn1.JIRAComponents__c = 'test';
        rn1.JIRAEpic__c = 'test';
        rn1.JIRAPriority__c = 'test';
        rn1.JIRAProject__c = 'test';
        rn1.JIRAIssueType__c = 'test';
        rn1.Action_Type__c = notificationType;
        insert rn1;

        RuleAction__c en1 = new RuleAction__c();
        en1.Action__c = rn1.Id;
        en1.Rule__c = mr1.Id;
        insert en1;

        RuleFilter__c rf1 = new RuleFilter__c();
        rf1.Index__c = 1;
        rf1.Rule__c = mr1.Id;
        rf1.ComparisonOperator__c = 'Greater than';
        rf1.FieldName__c = 'Created_At__c';
        rf1.Value__c = '13600';
        rf1.Comparison_Type__c = 'Value';
        insert rf1;

        Log__c log = new Log__c();
        log.Category__c = 'TestCategory';
        log.Type__c = 'TestType' ;
        log.Area__c = 'Apex';
        log.Details__c = 'pass pass pass pass pass pass pass';

        DateTime dtnow = Datetime.now();
        DateTime currentTime = DateTime.newInstance(dtnow.year(), dtnow.month(), dtnow.day(), dtnow.hour(), dtnow.minute(), dtnow.second());//DateTime.now();
        DateTime time_2h_ago = currentTime.addHours(-2);
        DateTime time_3h_ago = currentTime.addHours(-3);
        DateTime time_6h_ago = currentTime.addHours(-6);

        Log__c log_2h_ago = log.clone(); log_2h_ago.Created_At__c = time_2h_ago;
        Log__c log_3h_ago = log.clone(); log_3h_ago.Created_At__c = time_3h_ago;
        Log__c log_6h_ago = log.clone(); log_6h_ago.Created_At__c = time_6h_ago;
        List<Log__c> allLogs = new List<Log__c>{log, log_2h_ago, log_3h_ago, log_6h_ago};
        insert allLogs;

        List<Inbound_Email__c> logEmails = new List<Inbound_Email__c>();
        for(Log__c logIterator : allLogs) {
            logEmails.add(createInboundEmail(logIterator.Id));
        }
        insert logEmails;

        Event__c lastEvent = null;
        if(withEvent) {
            lastEvent = new Event__c();
            lastEvent.RecordCount__c = 1;
            lastEvent.Rule__c = mr1.Id;
            insert lastEvent;
            Test.setCreatedDate(lastEvent.Id, currentTime.addMinutes(-2*60));
        }

        Test.startTest();
        Database.executeBatch(new MonitoringBatch(MonitoringBatch.BATCH_MODE.ARCHIVAL), 1);
        Test.stopTest();

        List<Event__c> events;
        List<EventAction__c> eventActions;
        if(withEvent) {
            events = [SELECT Id, RecordCount__c, Records__c FROM Event__c WHERE Id != :lastEvent.Id LIMIT 1];
            eventActions = [SELECT Id, Contents__c, Event__c FROM EventAction__c WHERE Event__c != :lastEvent.Id LIMIT 1];
        }
        else {
            events = [SELECT Id, RecordCount__c, Records__c FROM Event__c LIMIT 1];
            eventActions = [SELECT Id, Contents__c, Event__c FROM EventAction__c LIMIT 1];
        }
        if(isPositive) {
            System.assertEquals(1, events.size());
            System.assertEquals(1, events.get(0).RecordCount__c);
            System.assertNotEquals(null, events.get(0).Records__c);

            if(notificationType == MonitoringUtil.ACTION_TYPE_REMOVAL) {
                Id removedLogId = (withEvent) ? log_2h_ago.Id : log_6h_ago.Id;
                List<Log__c> removedLogs = [SELECT Id FROM Log__c WHERE Id =:removedLogId];
                System.assertEquals(0, removedLogs.size());
                List<Inbound_Email__c> removedEmailLogs = [SELECT Id FROM Inbound_Email__c WHERE Log__c =:removedLogId];
                System.assertEquals(0, removedEmailLogs.size());
            }
            // TBD
            if(notificationType == MonitoringUtil.ACTION_TYPE_LOCAL_ARCHIVAL) {

            }
            if(notificationType == MonitoringUtil.ACTION_TYPE_EXTERNAL_ARCHIVAL) {

            }
        }
        else {
            System.assertEquals(0, events.size());
        }

        if(isPositive) {
            System.assertEquals(1, eventActions.size());
            System.assertEquals(events.get(0).Id, eventActions.get(0).Event__c);
        }
        else {
            System.assertEquals(0, eventActions.size());
        }
    }

    @IsTest
    public static void test_rule_notification_email_positive() {
        test_rule_notification('Monitoring', 'Email Notification', true);
    }
    @IsTest
    public static void test_rule_notification_email_negative() {
        test_rule_notification('Monitoring', 'Email Notification', false);
    }
    @IsTest
    public static void test_rule_notification_slack_positive() {
        test_rule_notification('Monitoring', 'Slack Notification', true);
    }
    @IsTest
    public static void test_rule_notification_slack_negative() {
        test_rule_notification('Monitoring', 'Slack Notification', false);
    }
    @IsTest
    public static void test_rule_notification_jira_positive() {
        test_rule_notification('Monitoring', 'Jira Notification', true);
    }
    @IsTest
    public static void test_rule_notification_jira_negative() {
        test_rule_notification('Monitoring', 'Jira Notification', false);
    }
    @IsTest
    public static void test_rule_notification_pagerduty_positive() {
        test_rule_notification('Monitoring', 'PagerDuty Notification', true);
    }
    @IsTest
    public static void test_rule_notification_pagerduty_negative() {
        test_rule_notification('Monitoring', 'PagerDuty Notification', false);
    }


    public static void test_rule_notification(String type, String eventType, Boolean isPositive) {

        TestDataWrapper data = prepareTestLogs(type, 'Count', 'Spike', 'Greater or equal', 'Equal', eventType, 40, false, false, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);

        List<EventAction__c> eventActions = [SELECT Id, Contents__c, Event__c FROM EventAction__c];
        if(isPositive) {
            System.assertEquals(1, eventActions.size());
            System.assertNotEquals(null, eventActions.get(0).Contents__c);
        }
        else {
            System.assertEquals(0, eventActions.size());
        }
    }

    @IsTest
    public static void test_rule_impact_type_count_greater_or_equal_filters_equal_positive() {
        test_rule_impact_greater_or_equal('Count', 'Equal', false, false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_or_equal_filters_equal_negative() {
        test_rule_impact_greater_or_equal('Count', 'Equal', false, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_greater_or_equal('Count', 'Equal', true, false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_greater_or_equal('Count', 'Equal', true, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_or_equal_with_multigroup_filter_positive() {
        test_rule_impact_greater_or_equal('Count', 'Equal', false, true, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_or_equal_with_multigroup_filter_negative() {
        test_rule_impact_greater_or_equal('Count', 'Equal', false, true, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_or_equal_filters_equal_negative() {
        test_rule_impact_greater_or_equal('Average', 'Equal', false, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_greater_or_equal('Average', 'Equal', true, false, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_greater_or_equal('Average', 'Equal', true, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_or_equal_with_multigroup_filter_positive() {
        test_rule_impact_greater_or_equal('Average', 'Equal', false, true, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_or_equal_with_multigroup_filter_negative() {
        test_rule_impact_greater_or_equal('Average', 'Equal', false, true, false);
    }

    public static void test_rule_impact_greater_or_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean withMultiGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withMultiGroupFilter) ? 2 : withGroupFilter ? 1 : 10;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.25 : 0.5;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Impact', 'Greater or equal', filtersComparisonOperator, threshold, withGroupFilter, withMultiGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_frequency_type_count_greater_or_equal_filters_equal_positive() {
        test_rule_frequency_greater_or_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_greater_or_equal_filters_equal_negative() {
        test_rule_frequency_greater_or_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_count_greater_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_greater_or_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_greater_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_greater_or_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_or_equal_filters_equal_positive() {
        test_rule_frequency_greater_or_equal('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_or_equal_filters_equal_negative() {
        test_rule_frequency_greater_or_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_greater_or_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_greater_or_equal('Average', 'Equal', true, false);
    }

    public static void test_rule_frequency_greater_or_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter) ? 2 : 10;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.5 : 0.625;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Frequency', 'Greater or equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_impact_type_count_greater_than_filters_equal_positive() {
        test_rule_impact_greater_than('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_than_filters_equal_negative() {
        test_rule_impact_greater_than('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_than_filters_equal_with_group_filter_positive() {
        test_rule_impact_greater_than('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_greater_than_filters_equal_with_group_filter_negative() {
        test_rule_impact_greater_than('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_than_filters_equal_negative() {
        test_rule_impact_greater_than('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_than_filters_equal_with_group_filter_positive() {
        test_rule_impact_greater_than('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_greater_than_filters_equal_with_group_filter_negative() {
        test_rule_impact_greater_than('Average', 'Equal', true, false);
    }

    public static void test_rule_impact_greater_than(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter) ? 0 : 9;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.2 : 2.5;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Impact', 'Greater than', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_frequency_type_count_greater_than_filters_equal_positive() {
        test_rule_frequency_greater_than('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_greater_than_filters_equal_negative() {
        test_rule_frequency_greater_than('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_count_greater_than_filters_equal_with_group_filter_positive() {
        test_rule_frequency_greater_than('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_greater_than_filters_equal_with_group_filter_negative() {
        test_rule_frequency_greater_than('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_than_filters_equal_positive() {
        test_rule_frequency_greater_than('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_than_filters_equal_negative() {
        test_rule_frequency_greater_than('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_than_filters_equal_with_group_filter_positive() {
        test_rule_frequency_greater_than('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_greater_than_filters_equal_with_group_filter_negative() {
        test_rule_frequency_greater_than('Average', 'Equal', true, false);
    }

    public static void test_rule_frequency_greater_than(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter) ? 2 : 9;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.25 : 0.5;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Frequency', 'Greater than', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_impact_type_count_equal_filters_equal_positive() {
        test_rule_impact_equal('Count', 'Equal', false, false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_equal_filters_equal_negative() {
        test_rule_impact_equal('Count', 'Equal', false, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_equal('Count', 'Equal', true, false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_equal_with_multigroup_filter_positive() {
        test_rule_impact_equal('Count', 'Equal', false, true, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_equal('Count', 'Equal', true, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_equal_with_multigroup_filter_negative() {
        test_rule_impact_equal('Count', 'Equal', false, true, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_equal_filters_equal_negative() {
        test_rule_impact_equal('Average', 'Equal', false, false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_equal('Average', 'Equal', true, false, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_equal('Average', 'Equal', true, false, false);
    }

    public static void test_rule_impact_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean withMultiGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withMultiGroupFilter) ? 1 : (withGroupFilter) ? 1 : 40;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.25 : 10;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Impact', 'Equal', filtersComparisonOperator, threshold, withGroupFilter, withMultiGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_frequency_type_count_equal_filters_equal_positive() {
        test_rule_frequency_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_equal_filters_equal_negative() {
        test_rule_frequency_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_count_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_equal_filters_equal_positive() {
        test_rule_frequency_equal('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_equal_filters_equal_negative() {
        test_rule_frequency_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_equal('Average', 'Equal', true, false);
    }

    public static void test_rule_frequency_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter) ? 8 : 10;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.5 : 0.625;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Frequency', 'Equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_impact_type_count_not_equal_filters_equal_positive() {
        test_rule_impact_not_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_not_equal_filters_equal_negative() {
        test_rule_impact_not_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_not_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_not_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_not_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_not_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_not_equal_filters_equal_negative() {
        test_rule_impact_not_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_not_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_not_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_not_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_not_equal('Average', 'Equal', true, false);
    }
    public static void test_rule_impact_not_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 11.5 : 0;
            }
            when 'Average' {
                threshold = isPositive ? 3.5 : 0;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Impact', 'Not equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_frequency_type_count_not_equal_filters_equal_positive() {
        test_rule_frequency_not_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_not_equal_filters_equal_negative() {
        test_rule_frequency_not_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_count_not_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_not_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_not_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_not_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_not_equal_filters_equal_positive() {
        test_rule_frequency_not_equal('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_not_equal_filters_equal_negative() {
        test_rule_frequency_not_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_not_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_not_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_not_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_not_equal('Average', 'Equal', true, false);
    }
    public static void test_rule_frequency_not_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 11.5 : 0;
            }
            when 'Average' {
                threshold = isPositive ? 3.5 : 0;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Frequency', 'Not equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_impact_type_count_less_than_filters_equal_positive() {
        test_rule_impact_less_than('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_less_than_filters_equal_negative() {
        test_rule_impact_less_than('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_less_than_filters_equal_with_group_filter_positive() {
        test_rule_impact_less_than('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_less_than_filters_equal_with_group_filter_negative() {
        test_rule_impact_less_than('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_less_than_filters_equal_negative() {
        test_rule_impact_less_than('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_less_than_filters_equal_with_group_filter_positive() {
        test_rule_impact_less_than('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_less_than_filters_equal_with_group_filter_negative() {
        test_rule_impact_less_than('Average', 'Equal', true, false);
    }
    public static void test_rule_impact_less_than(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter,  Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? (withGroupFilter) ? 12 : 41 : 0;
            }
            when 'Average' {
                threshold = isPositive ? 11 : -1;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Impact', 'Less than', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_frequency_type_count_less_than_filters_equal_positive() {
        test_rule_frequency_less_than('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_less_than_filters_equal_negative() {
        test_rule_frequency_less_than('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_count_less_than_filters_equal_with_group_filter_positive() {
        test_rule_frequency_less_than('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_less_than_filters_equal_with_group_filter_negative() {
        test_rule_frequency_less_than('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_than_filters_equal_positive() {
        test_rule_frequency_less_than('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_than_filters_equal_negative() {
        test_rule_frequency_less_than('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_than_filters_equal_with_group_filter_positive() {
        test_rule_frequency_less_than('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_than_filters_equal_with_group_filter_negative() {
        test_rule_frequency_less_than('Average', 'Equal', true, false);
    }
    public static void test_rule_frequency_less_than(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter,  Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 12 : 0;
            }
            when 'Average' {
                threshold = isPositive ? 3.44 : -1;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Frequency', 'Less than', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_impact_type_count_less_or_equal_filters_equal_positive() {
        test_rule_impact_less_or_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_less_or_equal_filters_equal_negative() {
        test_rule_impact_less_or_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_count_less_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_less_or_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_count_less_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_less_or_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_less_or_equal_filters_equal_negative() {
        test_rule_impact_less_or_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_impact_type_average_less_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_impact_less_or_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_impact_type_average_less_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_impact_less_or_equal('Average', 'Equal', true, false);
    }
    public static void test_rule_impact_less_or_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? (withGroupFilter ? 1 : 41) : -1;
            }
            when 'Average' {
                threshold = isPositive ? (withGroupFilter ? 1 : 11) : -1;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Impact', 'Less or equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }


    @IsTest
    public static void test_rule_frequency_type_count_less_or_equal_filters_equal_positive() {
        test_rule_frequency_less_or_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_less_or_equal_filters_equal_negative() {
        test_rule_frequency_less_or_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_count_less_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_less_or_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_count_less_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_less_or_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_or_equal_filters_equal_positive() {
        test_rule_frequency_less_or_equal('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_or_equal_filters_equal_negative() {
        test_rule_frequency_less_or_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_frequency_less_or_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_frequency_type_average_less_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_frequency_less_or_equal('Average', 'Equal', true, false);
    }
    public static void test_rule_frequency_less_or_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 10 : -1;
            }
            when 'Average' {
                threshold = isPositive ? 2.66 : -1;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Frequency', 'Less or equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }


    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_equal_positive() {
        test_rule_spike_greater_or_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_not_equal_positive() {
        test_rule_spike_greater_or_equal('Count', 'Not equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_greater_than_positive() {
        test_rule_spike_greater_or_equal('Count', 'Greater than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_greater_or_equal_positive() {
        test_rule_spike_greater_or_equal('Count', 'Greater or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_less_than_positive() {
        test_rule_spike_greater_or_equal('Count', 'Less than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_less_or_equal_positive() {
        test_rule_spike_greater_or_equal('Count', 'Less or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_not_equal_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Count', 'Not equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_greater_than_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Count', 'Greater than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_greater_or_equal_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Count', 'Greater or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_less_than_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Count', 'Less than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_less_or_equal_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Count', 'Less or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_equal_negative() {
        test_rule_spike_greater_or_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_or_equal_filters_equal_positive() {
        test_rule_spike_greater_or_equal('Average', 'Equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_or_equal_filters_equal_negative() {
        test_rule_spike_greater_or_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_greater_or_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_greater_or_equal('Average', 'Equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_greater_or_equal('Average', 'Equal', true, false);
    }

    public static void test_rule_spike_greater_or_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter) ? 5 : 40;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.5 : 2.4;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Spike', 'Greater or equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_equal_positive() {
        test_rule_spike_greater_than('Count', 'Equal',  false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_not_equal_positive() {
        test_rule_spike_greater_than('Count', 'Not equal',  false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_greater_than_positive() {
        test_rule_spike_greater_than('Count', 'Greater than',  false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_greater_or_equal_positive() {
        test_rule_spike_greater_than('Count', 'Greater or equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_less_than_positive() {
        test_rule_spike_greater_than('Count', 'Less than',false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_less_or_equal_positive() {
        test_rule_spike_greater_than('Count', 'Less or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_equal_with_group_filter_positive() {
        test_rule_spike_greater_than('Count', 'Equal',  true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_not_equal_with_group_filter_positive() {
        test_rule_spike_greater_than('Count', 'Not equal',  true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_greater_than_with_group_filter_positive() {
        test_rule_spike_greater_than('Count', 'Greater than',  true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_greater_or_equal_with_group_filter_positive() {
        test_rule_spike_greater_than('Count', 'Greater or equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_less_than_with_group_filter_positive() {
        test_rule_spike_greater_than('Count', 'Less than',true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_less_or_equal_with_group_filter_positive() {
        test_rule_spike_greater_than('Count', 'Less or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_equal_negative() {
        test_rule_spike_greater_than('Count','Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_than_filters_equal_positive() {
        test_rule_spike_greater_than('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_than_filters_equal_negative() {
        test_rule_spike_greater_than('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_count_greater_than_filters_equal_with_group_filter_negative() {
        test_rule_spike_greater_than('Count','Equal', true, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_than_filters_equal_with_group_filter_positive() {
        test_rule_spike_greater_than('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_greater_than_filters_equal_with_group_filter_negative() {
        test_rule_spike_greater_than('Average', 'Equal', true, false);
    }

    public static void test_rule_spike_greater_than(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter) ? 31 : 39;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.5 : 2.4;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Spike', 'Greater than', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_spike_type_count_equal_filters_equal_positive() {
        test_rule_spike_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_not_equal_positive() {
        test_rule_spike_equal('Count', 'Not equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_not_equal_with_group_filter_positive() {
        test_rule_spike_equal('Count', 'Not equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_greater_than_positive() {
        test_rule_spike_equal('Count', 'Greater than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_greater_than_with_group_filter_positive() {
        test_rule_spike_equal('Count', 'Greater than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_greater_or_equal_positive() {
        test_rule_spike_equal('Count', 'Greater or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_greater_or_equal_with_group_filter_positive() {
        test_rule_spike_equal('Count', 'Greater or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_less_than_positive() {
        test_rule_spike_equal('Count', 'Less than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_less_than_with_group_filter_positive() {
        test_rule_spike_equal('Count', 'Less than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_less_or_equal_positive() {
        test_rule_spike_equal('Count', 'Less or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_less_or_equal_with_group_filter_positive() {
        test_rule_spike_equal('Count', 'Less or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_equal_negative() {
        test_rule_spike_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_count_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_equal_filters_equal_positive() {
        test_rule_spike_equal('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_equal_filters_equal_negative() {
        test_rule_spike_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_equal('Average', 'Equal', true, false);
    }

    public static void test_rule_spike_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        Integer recordsCount = null;
        switch on aggregateType {
            when 'Count' {
                threshold = (withGroupFilter && filtersComparisonOperator != 'Greater than' && filtersComparisonOperator != 'Greater or equal') ? 32 : 40;
            }
            when 'Average' {
                threshold = (withGroupFilter) ? 0.5 : 2.5;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Spike', 'Equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_equal_positive() {
        test_rule_spike_not_equal('Count', 'Equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_not_equal_positive() {
        test_rule_spike_not_equal('Count', 'Not equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_greater_than_positive() {
        test_rule_spike_not_equal('Count', 'Greater than', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_greater_or_equal_positive() {
        test_rule_spike_not_equal('Count', 'Greater or equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_less_than_positive() {
        test_rule_spike_not_equal('Count', 'Less than', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_less_or_equal_positive() {
        test_rule_spike_not_equal('Count', 'Less or equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_not_equal('Count', 'Equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_not_equal_with_group_filter_positive() {
        test_rule_spike_not_equal('Count', 'Not equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_greater_than_with_group_filter_positive() {
        test_rule_spike_not_equal('Count', 'Greater than', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_greater_or_equal_with_group_filter_positive() {
        test_rule_spike_not_equal('Count', 'Greater or equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_less_than_with_group_filter_positive() {
        test_rule_spike_not_equal('Count', 'Less than', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_less_or_equal_with_group_filter_positive() {
        test_rule_spike_not_equal('Count', 'Less or equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_equal_negative() {
        test_rule_spike_not_equal('Count', 'Equal', false,  false);
    }
    @IsTest
    public static void test_rule_spike_type_average_not_equal_filters_equal_positive() {
        test_rule_spike_not_equal('Average', 'Equal', false,  true);
    }
    @IsTest
    public static void test_rule_spike_type_average_not_equal_filters_equal_negative() {
        test_rule_spike_not_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_count_not_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_not_equal('Count', 'Equal', true,  false);
    }
    @IsTest
    public static void test_rule_spike_type_average_not_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_not_equal('Average', 'Equal', true,  true);
    }
    @IsTest
    public static void test_rule_spike_type_average_not_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_not_equal('Average', 'Equal', true, false);
    }

    public static void test_rule_spike_not_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 41 : 0;
            }
            when 'Average' {
                threshold = isPositive ? 11 : 0;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Spike', 'Not equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_equal_positive() {
        test_rule_spike_less_than('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_not_equal_positive() {
        test_rule_spike_less_than('Count', 'Not equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_greater_than_positive() {
        test_rule_spike_less_than('Count', 'Greater than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_greater_or_equal_positive() {
        test_rule_spike_less_than('Count', 'Greater or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_less_than_positive() {
        test_rule_spike_less_than('Count', 'Less than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_less_or_equal_positive() {
        test_rule_spike_less_than('Count', 'Less or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_equal_with_group_filter_positive() {
        test_rule_spike_less_than('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_not_equal_with_group_filter_positive() {
        test_rule_spike_less_than('Count', 'Not equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_greater_than_with_group_filter_positive() {
        test_rule_spike_less_than('Count', 'Greater than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_greater_or_equal_with_group_filter_positive() {
        test_rule_spike_less_than('Count', 'Greater or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_less_than_with_group_filter_positive() {
        test_rule_spike_less_than('Count', 'Less than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_less_or_equal_with_group_filter_positive() {
        test_rule_spike_less_than('Count', 'Less or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_equal_negative() {
        test_rule_spike_less_than('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_than_filters_equal_positive() {
        test_rule_spike_less_than('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_than_filters_equal_negative() {
        test_rule_spike_less_than('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_than_filters_equal_with_group_filter_negative() {
        test_rule_spike_less_than('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_than_filters_equal_with_group_filter_positive() {
        test_rule_spike_less_than('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_than_filters_equal_with_group_filter_negative() {
        test_rule_spike_less_than('Average', 'Equal', true, false);
    }

    public static void test_rule_spike_less_than(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter,  Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 50 : 0;
            }
            when 'Average' {
                threshold = isPositive ? 11 : -1;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Spike', 'Less than', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }

    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_equal_positive() {
        test_rule_spike_less_or_equal('Count', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_not_equal_positive() {
        test_rule_spike_less_or_equal('Count', 'Not equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_greater_than_positive() {
        test_rule_spike_less_or_equal('Count', 'Greater than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_greater_or_equal_positive() {
        test_rule_spike_less_or_equal('Count', 'Greater or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_less_than_positive() {
        test_rule_spike_less_or_equal('Count', 'Less than', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_less_or_equal_positive() {
        test_rule_spike_less_or_equal('Count', 'Less or equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Count', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_not_equal_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Count', 'Not equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_greater_than_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Count', 'Greater than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_greater_or_equal_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Count', 'Greater or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_less_than_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Count', 'Less than', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_less_or_equal_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Count', 'Less or equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_equal_negative() {
        test_rule_spike_less_or_equal('Count', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_or_equal_filters_equal_positive() {
        test_rule_spike_less_or_equal('Average', 'Equal', false, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_or_equal_filters_equal_negative() {
        test_rule_spike_less_or_equal('Average', 'Equal', false, false);
    }
    @IsTest
    public static void test_rule_spike_type_count_less_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_less_or_equal('Count', 'Equal', true, false);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_or_equal_filters_equal_with_group_filter_positive() {
        test_rule_spike_less_or_equal('Average', 'Equal', true, true);
    }
    @IsTest
    public static void test_rule_spike_type_average_less_or_equal_filters_equal_with_group_filter_negative() {
        test_rule_spike_less_or_equal('Average', 'Equal', true, false);
    }

    public static void test_rule_spike_less_or_equal(String aggregateType, String filtersComparisonOperator, Boolean withGroupFilter, Boolean isPositive) {
        Decimal threshold = null;
        switch on aggregateType {
            when 'Count' {
                threshold = isPositive ? 40 : -1;
            }
            when 'Average' {
                threshold = isPositive ? 11 : -1;
            }
        }

        TestDataWrapper data = prepareTestLogs(aggregateType, 'Spike', 'Less or equal', filtersComparisonOperator, threshold, withGroupFilter, isPositive);
        List<Log__c> logs = data.logs;
        Event__c lastEvent = data.lastEvent;

        Test.startTest();
        insert logs;
        Test.stopTest();

        assertEventResults(lastEvent.Id, isPositive);
    }


    private static void assertEventResults(Id lastEventId, Boolean isPositive) {
        List<Event__c> events = [SELECT Id, RecordCount__c, Records__c, Grouped_Field_Values__c FROM Event__c WHERE Id != :lastEventId];
        if(isPositive) {
            for(Event__c event : events) {
                if(event.Grouped_Field_Values__c == 'Workflow') {
                    System.assertEquals(8, event.RecordCount__c);
                }
                if(event.Grouped_Field_Values__c == 'Apex') {
                    System.assertEquals(32, event.RecordCount__c);
                }
                System.assertNotEquals(null, event.Records__c);
            }
        }
        else {
            System.assertEquals(0, events.size());
        }
    }


    public class TestDataWrapper {
        List<Log__c> logs;
        Event__c lastEvent;

        public TestDataWrapper(List<Log__c> logs, Event__c lastEvent) {
            this.logs = logs;
            this.lastEvent = lastEvent;
        }
    }

    private static TestDataWrapper prepareTestLogs(String aggregateType, String eventType, String comparisonOperator, String filtersComparisonOperator, Decimal threshold, Boolean isPositive) {
        return prepareTestLogs('Monitoring', aggregateType, eventType, comparisonOperator, filtersComparisonOperator, null, threshold, false, false, isPositive);
    }

    private static TestDataWrapper prepareTestLogs(String aggregateType, String eventType, String comparisonOperator, String filtersComparisonOperator, Decimal threshold, Boolean withGroupFilter, Boolean isPositive) {
        return prepareTestLogs('Monitoring', aggregateType, eventType, comparisonOperator, filtersComparisonOperator, null, threshold, withGroupFilter, false, isPositive);
    }

    private static TestDataWrapper prepareTestLogs(String aggregateType, String eventType, String comparisonOperator, String filtersComparisonOperator, Decimal threshold, Boolean withGroupFilter, Boolean withMultiGroupFilter, Boolean isPositive) {
        return prepareTestLogs('Monitoring', aggregateType, eventType, comparisonOperator, filtersComparisonOperator, null, threshold, withGroupFilter, withMultiGroupFilter, isPositive);
    }

    private static TestDataWrapper prepareTestLogs(String type, String aggregateType, String eventType, String comparisonOperator, String filtersComparisonOperator, String notificationType , Decimal threshold, Boolean withGroupFilter, Boolean withMultiGroupFilter, Boolean isPositive) {
        String packagePrefix = ConfigUtil.nameSpacePrefix;

        Rule__c mr1 = new Rule__c();
        mr1.Active__c = true;
        mr1.AggregateType__c = aggregateType;
        mr1.AggregateInterval__c = (aggregateType == 'Average' || eventType == 'Frequency' ) ? 180 : null;
        mr1.Type__c = type;
        mr1.SubType__c = eventType;
        mr1.ComparisonOperator__c = comparisonOperator;
        mr1.EventTimeInterval__c = 12*60;
        mr1.FilterLogic__c = (!withMultiGroupFilter) ? '1 OR 2' : null;
        mr1.Threshold__c = threshold;
        insert mr1;

        List<RuleFilter__c> monitoringRuleFilters = new List<RuleFilter__c>();

        if(!withMultiGroupFilter) {
            RuleFilter__c rf1 = new RuleFilter__c();
            rf1.Index__c = 1;
            rf1.Rule__c = mr1.Id;
            switch on filtersComparisonOperator {
                when 'Equal' {
                    rf1.ComparisonOperator__c = 'Equal';
                    rf1.FieldName__c = packagePrefix + 'Type__c';
                    rf1.Value__c = 'TestType';
                    rf1.Comparison_Type__c = 'Value';
                    rf1.Field_Type__c = 'STRING';
                }
                when 'Not equal' {
                    rf1.ComparisonOperator__c = 'Not equal';
                    rf1.FieldName__c = packagePrefix + 'Type__c';
                    rf1.Value__c = 'notTestType';
                    rf1.Comparison_Type__c = 'Value';
                    rf1.Field_Type__c = 'STRING';
                }
                when 'Greater than' {
                    rf1.ComparisonOperator__c = 'Greater than';
                    rf1.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf1.Value__c = '1';
                    rf1.Comparison_Type__c = 'Value';
                    rf1.Field_Type__c = 'DOUBLE';
                }
                when 'Greater or equal' {
                    rf1.ComparisonOperator__c = 'Greater or equal';
                    rf1.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf1.Value__c = '2';
                    rf1.Comparison_Type__c = 'Value';
                    rf1.Field_Type__c = 'DOUBLE';
                }
                when 'Less than' {
                    rf1.ComparisonOperator__c = 'Less than';
                    rf1.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf1.Value__c = '10';
                    rf1.Comparison_Type__c = 'Value';
                    rf1.Field_Type__c = 'DOUBLE';
                }
                when 'Less or equal' {
                    rf1.ComparisonOperator__c = 'Less or equal';
                    rf1.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf1.Value__c = '9';
                    rf1.Comparison_Type__c = 'Value';
                    rf1.Field_Type__c = 'DOUBLE';
                }
            }

            RuleFilter__c rf2 = new RuleFilter__c();
            rf2.Index__c = 2;
            rf2.Rule__c = mr1.Id;
            switch on filtersComparisonOperator {
                when 'Equal' {
                    rf2.ComparisonOperator__c = 'Equal';
                    rf2.FieldName__c = packagePrefix + 'Category__c';
                    rf2.Value__c = 'TestCategory';
                    rf2.Comparison_Type__c = 'Value';
                    rf2.Field_Type__c = 'STRING';
                }
                when 'Not equal' {
                    rf2.ComparisonOperator__c = 'Not equal';
                    rf2.FieldName__c = packagePrefix + 'Category__c';
                    rf2.Value__c = 'notTestCategory';
                    rf2.Comparison_Type__c = 'Value';
                    rf2.Field_Type__c = 'STRING';
                }
                when 'Greater than' {
                    rf2.ComparisonOperator__c = 'Greater than';
                    rf2.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf2.Value__c = '12';
                    rf2.Comparison_Type__c = 'Value';
                    rf2.Field_Type__c = 'DOUBLE';
                }
                when 'Greater or equal' {
                    rf2.ComparisonOperator__c = 'Greater or equal';
                    rf2.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf2.Value__c = '12';
                    rf2.Comparison_Type__c = 'Value';
                    rf2.Field_Type__c = 'DOUBLE';
                }
                when 'Less than' {
                    rf2.ComparisonOperator__c = 'Less than';
                    rf2.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf2.Value__c = '-1';
                    rf2.Comparison_Type__c = 'Value';
                    rf2.Field_Type__c = 'DOUBLE';
                }
                when 'Less or equal' {
                    rf2.ComparisonOperator__c = 'Less or equal';
                    rf2.FieldName__c = packagePrefix + 'Total_Active_Sessions__c';
                    rf2.Value__c = '-1';
                    rf2.Comparison_Type__c = 'Value';
                    rf2.Field_Type__c = 'DOUBLE';
                }
            }
            monitoringRuleFilters.add(rf1);
            monitoringRuleFilters.add(rf2);
        }

        if(withGroupFilter) {
            RuleFilter__c rf11 = new RuleFilter__c();
            rf11.Index__c = 1;
            rf11.FieldName__c = packagePrefix + 'Area__c';
            rf11.Comparison_Type__c = 'Field';
            rf11.Field_Type__c = 'STRING';
            rf11.Rule__c = mr1.Id;
            monitoringRuleFilters.add(rf11);
        }
        if(withMultiGroupFilter) {
            RuleFilter__c rf22 = new RuleFilter__c();
            rf22.Index__c = 1;
            rf22.FieldName__c = packagePrefix + 'Type__c';
            rf22.Comparison_Type__c = 'Field';
            rf22.Field_Type__c = 'STRING';
            rf22.Rule__c = mr1.Id;

            RuleFilter__c rf33 = new RuleFilter__c();
            rf33.Index__c = 2;
            rf33.FieldName__c = packagePrefix + 'Area__c';
            rf33.Comparison_Type__c = 'Field';
            rf33.Field_Type__c = 'STRING';
            rf33.Rule__c = mr1.Id;
            monitoringRuleFilters.add(rf22);
            monitoringRuleFilters.add(rf33);
        }

        insert monitoringRuleFilters;

        List<Log__c> logs = new List<Log__c>();
        for(Integer i = 0; i < 12; i++){
            Log__c log = new Log__c();
            log.Category__c = (i < 10) ? 'TestCategory' : 'notTestCategory';
            log.Type__c = (i < 10) ? 'TestType' : 'notTestType';
            log.Area__c = (i < 2) ? 'Workflow' : 'Apex';
            log.Total_Active_Sessions__c = i;
            log.Details__c = (i < 10) ? 'pass pass pass pass pass pass pass' : 'fail fail fail fail fail fail fail';
            logs.add(log);
        }
        DateTime dtnow = Datetime.now();
        DateTime currentTime = DateTime.newInstance(dtnow.year(), dtnow.month(), dtnow.day(), dtnow.hour(), dtnow.minute(), dtnow.second());

        List<Log__c> logs_3h_ago = new List<Log__c>();
        DateTime time_3h_ago = currentTime.addHours(-3);
        logs_3h_ago.addAll(setCreatedDateLogs(logs, time_3h_ago));

        List<Log__c> logs_6h_ago = new List<Log__c>();
        DateTime time_6h_ago = currentTime.addHours(-6);
        logs_6h_ago.addAll(setCreatedDateLogs(logs, time_6h_ago));

        List<Log__c> logs_9h_ago = new List<Log__c>();
        DateTime time_9h_ago = currentTime.addHours(-9);
        logs_9h_ago.addAll(setCreatedDateLogs(logs, time_9h_ago));

        List<Log__c> logs_12h_ago = new List<Log__c>();
        DateTime time_12h_ago = currentTime.addHours(-12);
        logs_12h_ago.addAll(setCreatedDateLogs(logs, time_12h_ago));

        List<Log__c> logs_13h_ago = new List<Log__c>();
        DateTime time_13h_ago = currentTime.addHours(-13);
        logs_13h_ago.addAll(setCreatedDateLogs(logs, time_13h_ago));

        List<Log__c> testLogs = new List<Log__c>();

        if(isPositive) {
            testLogs.addAll(logs_3h_ago);
            testLogs.addAll(logs_6h_ago);
            testLogs.addAll(logs_9h_ago);
            testLogs.addAll(logs_12h_ago);
            testLogs.addAll(logs_13h_ago);
        }
        else if (eventType == 'Frequency' && !isPositive) {
            testLogs.addAll(logs_3h_ago);
            testLogs.addAll(logs_9h_ago);
            testLogs.addAll(logs_13h_ago);
        }
        else {
            testLogs.addAll(logs_13h_ago);
        }

        if(String.isNotBlank(notificationType)) {
            String ruleType = (type == 'JIRA Update') ? 'Monitoring' : type;
            Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get(ruleType).getRecordtypeId();

            Action__c rn1 = new Action__c();
            rn1.RecordTypeId = recordtypeId;
            rn1.Description__c = 'test';
            rn1.Subject__c = 'test';
            rn1.Body__c = 'test';
            rn1.EmailBody__c = 'test';
            rn1.SlackChannels__c = 'test';
            rn1.EmailTo__c = 'test@test.cc';
            rn1.EmailCC__c = 'test2@test.cc';
            rn1.JIRALabels__c = 'test';
            rn1.JIRAComponents__c = 'test';
            rn1.JIRAEpic__c = 'test';
            rn1.JIRAPriority__c = 'test';
            rn1.JIRAProject__c = 'test';
            rn1.JIRAIssueType__c = 'test';
            rn1.Action_Type__c = notificationType;
            insert rn1;

            RuleAction__c en1 = new RuleAction__c();
            en1.Action__c = rn1.Id;
            en1.Rule__c = mr1.Id;
            insert en1;
        }

        insert testLogs;

        Event__c lastEvent = new Event__c();
        lastEvent.Criteria__c = 'some test criteria';
        lastEvent.RecordCount__c = 1;
        lastEvent.Records__c = '{}';
        lastEvent.Rule__c = mr1.Id;
        insert lastEvent;

        DateTime lastProcessedDatetime = time_13h_ago;//currentTime.addHours(-14);
        Test.setCreatedDate(lastEvent.Id, lastProcessedDatetime);

        LogTriggerHelper.currentTime = DateTime.now().addMinutes(-2);

        List<Log__c> toTest = new List<Log__c>();
        toTest.addAll(setCreatedDateLogs(logs, isPositive ? DateTime.now() : time_13h_ago));

        return new TestDataWrapper(toTest, lastEvent);
    }

    public static List<Log__c> setCreatedDateLogs(List<Log__c> logs, DateTime createdDate) {
        List<Log__c> result = new List<Log__c>();

        for(Log__c log : logs) {
            Log__c logResult = log.clone();
            logResult.Created_At__c = createdDate;
            result.add(logResult);
        }
        return result;
    }

    private static final String GMT_FORMAT_DATE = 'yyyy-MM-dd';
    private static final String GMT_FORMAT_TIME = 'HH:mm:ss';

    @IsTest
    private static void test_evaluate_filter_DateTime_equal_positive() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Equal', localeDT, gmtStringDT, true);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_equal_negative() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Equal', localeDT, gmtStringDT, false);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_not_equal_positive() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Not equal', localeDT, gmtStringDT, true);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_not_equal_negative() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Not equal', localeDT, gmtStringDT, false);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_greater_than_positive() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(-10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Greater than', localeDT, gmtStringDT, true);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_greater_than_negative() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Greater than', localeDT, gmtStringDT, false);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_greater_or_equal_positive() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Greater or equal', localeDT, gmtStringDT, true);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_greater_or_equal_negative() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Greater or equal', localeDT, gmtStringDT, false);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_less_than_positive() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Less than', localeDT, gmtStringDT, true);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_less_than_negative() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(-10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Less than', localeDT, gmtStringDT, false);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_less_or_equal_positive() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Less or equal', localeDT, gmtStringDT, true);
    }

    @IsTest
    private static void test_evaluate_filter_DateTime_less_or_equal_negative() {
        DateTime localeDT = DateTime.now();
        String gmtStringDT = localeDT.formatGmt(GMT_FORMAT_DATE) + ' ' + localeDT.addMinutes(-10).formatGmt(GMT_FORMAT_TIME);
        test_evaluate_DateTime_filter('Less or equal', localeDT, gmtStringDT, false);
    }

    private static void test_evaluate_DateTime_filter(String comparisonOperator, DateTime logDateTime, String filterDateTime, Boolean expectedTestResult) {
        test_evaluate_DateTime_filter('CreatedDate', 'DATETIME', comparisonOperator, logDateTime, filterDateTime, expectedTestResult);
    }

    @IsTest
    private static void test_evaluate_filter_Date_equal_positive() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Equal', localeDate, gmtStringDate, true);
    }

    @IsTest
    private static void test_evaluate_filter_Date_equal_negative() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Equal', localeDate, gmtStringDate, false);
    }

    @IsTest
    private static void test_evaluate_filter_Date_not_equal_positive() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Not equal', localeDate, gmtStringDate, true);
    }

    @IsTest
    private static void test_evaluate_filter_Date_not_equal_negative() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Not equal', localeDate, gmtStringDate, false);
    }

    @IsTest
    private static void test_evaluate_filter_Date_greater_than_positive() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(-1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Greater than', localeDate, gmtStringDate, true);
    }

    @IsTest
    private static void test_evaluate_filter_Date_greater_than_negative() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Greater than', localeDate, gmtStringDate, false);
    }

    @IsTest
    private static void test_evaluate_filter_Date_greater_or_equal_positive() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(-1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Greater or equal', localeDate, gmtStringDate, true);
    }

    @IsTest
    private static void test_evaluate_filter_Date_greater_or_equal_negative() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Greater or equal', localeDate, gmtStringDate, false);
    }

    @IsTest
    private static void test_evaluate_filter_Date_less_than_positive() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Less than', localeDate, gmtStringDate, true);
    }

    @IsTest
    private static void test_evaluate_filter_Date_less_than_negative() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(-1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Less than', localeDate, gmtStringDate, false);
    }

    @IsTest
    private static void test_evaluate_filter_Date_less_or_equal_positive() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Less or equal', localeDate, gmtStringDate, true);
    }

    @IsTest
    private static void test_evaluate_filter_Date_less_or_equal_negative() {
        DateTime localeDT = DateTime.now();
        Date localeDate = localeDT.dateGMT();
        String gmtStringDate = localeDT.addDays(-1).formatGmt(GMT_FORMAT_DATE);
        test_evaluate_Date_filter('Less or equal', localeDate, gmtStringDate, false);
    }

    private static void test_evaluate_Date_filter(String comparisonOperator, Date logDateTime, String filterDate, Boolean expectedTestResult) {
        test_evaluate_Date_filter('Birthdate', 'DATE', comparisonOperator, logDateTime, filterDate, expectedTestResult);
    }

    private static void setFakeDescribeLogFields() {
        ConfigUtil.MAP_LOG_FIELDS = new Map<String, Schema.DescribeFieldResult>();
        Map<String, Schema.SObjectField> sObjectFieldMap = Schema.SObjectType.Contact.fields.getMap();
        for(String fieldName : sObjectFieldMap.keySet()) {
            Schema.DescribeFieldResult sObjectFieldDescribe = sObjectFieldMap.get(fieldName).getDescribe();
            ConfigUtil.MAP_LOG_FIELDS.put(fieldName, sObjectFieldDescribe);
        }
    }

    private static void test_evaluate_Date_filter(
            String fieldName, String fieldType, String comparisonOperator,
            Date logDate, String filterDate,
            Boolean expectedTestResult) {

        Rule__c mr1 = TestDataFactory.createTestFilterRule();

        RuleFilter__c rf1 = new RuleFilter__c();
        rf1.Index__c = 1;
        rf1.FieldName__c = fieldName;
        rf1.Comparison_Type__c = 'Value';
        rf1.Value__c = filterDate;
        rf1.Field_Type__c = fieldType;
        rf1.Rule__c = mr1.Id;
        rf1.ComparisonOperator__c = comparisonOperator;
        insert rf1;

        Contact contact = new Contact(FirstName = 'test1', LastName = 'test2', Birthdate = logDate);
        insert contact;

        contact = [SELECT Id, Birthdate FROM Contact WHERE Id = :contact.Id LIMIT 1];
        Boolean testResult;

        Test.startTest();
        setFakeDescribeLogFields();
        RuleFilter__c rf = [SELECT Id, Index__c, Comparison_Type__c, Value__c, Field_Type__c, FieldName__c, Rule__c, ComparisonOperator__c FROM RuleFilter__c WHERE Id = :rf1.Id LIMIT 1];
        MonitoringUtil.RuleFilter rfInstance = new MonitoringUtil.RuleFilter(rf);
        Map<String, Object> objectMap = contact.getPopulatedFieldsAsMap();
        testResult = rfInstance.evaluateFilter(objectMap);

        Test.stopTest();

        System.assertEquals(expectedTestResult, testResult);
    }

    private static void test_evaluate_DateTime_filter(
            String fieldName, String fieldType, String comparisonOperator,
            DateTime logDateTime, String filterDateTime,
            Boolean expectedTestResult) {

        Rule__c mr1 = TestDataFactory.createTestFilterRule();

        RuleFilter__c rf1 = new RuleFilter__c();
        rf1.Index__c = 1;
        rf1.FieldName__c = fieldName;
        rf1.Comparison_Type__c = 'Value';
        rf1.Value__c = filterDateTime;
        rf1.Field_Type__c = fieldType;
        rf1.Rule__c = mr1.Id;
        rf1.ComparisonOperator__c = comparisonOperator;
        insert rf1;

        Log__c log = new Log__c();
        log.hash_1__c = '1234567890';
        insert log;

        Test.setCreatedDate(log.Id, logDateTime);
        log = [SELECT Id, CreatedDate FROM Log__c WHERE Id = :log.Id LIMIT 1];
        Boolean testResult;

        Test.startTest();

        RuleFilter__c rf = [SELECT Id, Index__c, Comparison_Type__c, Value__c, Field_Type__c, FieldName__c, Rule__c, ComparisonOperator__c FROM RuleFilter__c WHERE Id = :rf1.Id LIMIT 1];
        MonitoringUtil.RuleFilter rfInstance = new MonitoringUtil.RuleFilter(rf);
        Map<String, Object> objectMap = log.getPopulatedFieldsAsMap();
        testResult = rfInstance.evaluateFilter(objectMap);

        Test.stopTest();

        System.assertEquals(expectedTestResult, testResult);
    }

    @IsTest
    private static void test_evaluate_filter_Boolean_equal_positive() {
        test_evaluate_Boolean_filter('Equal', 'true', true, true);
    }

    @IsTest
    private static void test_evaluate_filter_Boolean_equal_negative() {
        test_evaluate_Boolean_filter('Equal', 'true', false, false);
    }

    @IsTest
    private static void test_evaluate_filter_Boolean_not_equal_positive() {
        test_evaluate_Boolean_filter('Not equal', 'false', true, true);
    }

    @IsTest
    private static void test_evaluate_filter_Boolean_not_equal_negative() {
        test_evaluate_Boolean_filter('Not equal', 'false', false, false);
    }

    private static void test_evaluate_Boolean_filter(
        String comparisonOperator,
        String filterValue,
        Boolean recordValue,
        Boolean expectedTestResult) {

        String packagePrefix = ConfigUtil.nameSpacePrefix;

        Rule__c mr1 = TestDataFactory.createTestFilterRule();

        RuleFilter__c rf1 = new RuleFilter__c();
        rf1.Index__c = 1;
        rf1.FieldName__c = packagePrefix + 'Regression__c';
        rf1.Comparison_Type__c = 'Value';
        rf1.Value__c = filterValue;
        rf1.Field_Type__c = 'BOOLEAN';
        rf1.Rule__c = mr1.Id;
        rf1.ComparisonOperator__c = comparisonOperator;
        insert rf1;

        Log__c log = new Log__c();
        log.hash_1__c = '1234567890';
        log.Regression__c = recordValue;
        insert log;

        log = [SELECT Id, Regression__c FROM Log__c WHERE Id = :log.Id LIMIT 1];
        Boolean testResult;

        Test.startTest();

        RuleFilter__c rf = [SELECT Id, Index__c, Comparison_Type__c, Value__c, Field_Type__c, FieldName__c, Rule__c, ComparisonOperator__c FROM RuleFilter__c WHERE Id = :rf1.Id LIMIT 1];
        MonitoringUtil.RuleFilter rfInstance = new MonitoringUtil.RuleFilter(rf);
        Map<String, Object> objectMap = log.getPopulatedFieldsAsMap();
        testResult = rfInstance.evaluateFilter(objectMap);

        Test.stopTest();

        System.assertEquals(expectedTestResult, testResult);
    }

    public static final String INBOUND_EMAIL_SUBJECT = 'Subject';
    public static final String INBOUND_EMAIL_PLAIN_TEXT = 'Please review error';
    public static final String INBOUND_EMAIL_FROM = 'erroruser@somedomain.com';

    private static Inbound_Email__c createInboundEmail(Id logId) {
        Inbound_Email__c inboundEmail = new Inbound_Email__c();
        inboundEmail.Subject__c = INBOUND_EMAIL_SUBJECT;
        inboundEmail.Plain_Text__c = INBOUND_EMAIL_PLAIN_TEXT;
        inboundEmail.From__c = INBOUND_EMAIL_FROM;
        return inboundEmail;
    }

}