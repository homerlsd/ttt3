@IsTest
private class TestDataGeneratorTest {

	@TestSetup
	private static void testSetup() {
		Slack_Settings__c slackSettings = new Slack_Settings__c(
			Slack_Enabled__c = true,
			Slack_API_Token__c = '123321'
		);
		insert slackSettings;

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

		Test_LogService.initSettings();

	}

	@IsTest
	static void testEmailExceptionSendMeAnEmail() {
		Test.startTest();
		TestDataGenerator.testEmailExceptionSendMeAnEmail();
		Test.stopTest();
	}

	@IsTest
	static void monitoringTestSendMeAnEmail() {
		Test.startTest();
		TestDataGenerator.monitoringTestSendMeAnEmail();
		Test.stopTest();
	}

	@IsTest
	static void connectedAppSendMeAnEmail() {
		Test.startTest();
		TestDataGenerator.connectedAppSendMeAnEmail();
		Test.stopTest();
	}

	@IsTest
	static void createMonitoringSpikeRule() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.TEST_MONITORING_SPIKE_KEY_SLACK_CHANNEL, 'test-test');
		TestDataGenerator.createMonitoringSpikeRule(input);
		Test.stopTest();

		TestDataGenerator.getExistMonitoringRules();
		TestDataGenerator.getTestMonitoringSpikeRuleLog();
	}

	@IsTest
	static void createMonitoringSpikeRuleEmail() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.TEST_MONITORING_SPIKE_KEY_EMAIL, 'test@test.com');
		TestDataGenerator.createMonitoringSpikeRule(input);
		Test.stopTest();

		TestDataGenerator.getExistMonitoringRules();
		TestDataGenerator.getTestMonitoringSpikeRuleLog();
	}

	@IsTest
	static void startMonitoringRuleTest() {
		Test.startTest();
		//TODO
		//System.UnexpectedException: No more than one executeBatch can be called from
		//within a test method.  Please make sure the iterable returned from your start
		//method matches the batch size, resulting in one executeBatch invocation.
		try{
			TestDataGenerator.deleteMonitoringSpikeRuleLogs();
			TestDataGenerator.deleteMonitoringSpikeRuleEvents();
			TestDataGenerator.deleteMonitoringImpactRuleLogs();
			TestDataGenerator.deleteMonitoringImpactRuleEvents();
			TestDataGenerator.getUsers();
			TestDataGenerator.getTestMonitoringImpactRuleRelatedErrorLogs(new List<Id>());
			TestDataGenerator.getTestMonitoringSpikeRuleRelatedErrorLogs(new List<Id>());
			//TestDataGenerator.startMonitoringRuleTest();
		}
		catch(Exception e){}
		Test.stopTest();
	}

	@IsTest
	static void createMonitoringImpactRule() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.TEST_MONITORING_IMPACT_KEY_SLACK_CHANNEL, 'test-test');
		TestDataGenerator.createMonitoringImpactRule(input);
		Test.stopTest();

		TestDataGenerator.getExistMonitoringRules();
		TestDataGenerator.getTestMonitoringImpactRuleLog();
	}

	@IsTest
	static void createMonitoringImpactRuleEmail() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.TEST_MONITORING_IMPACT_KEY_EMAIL, 'test@test.com');
		TestDataGenerator.createMonitoringImpactRule(input);
		Test.stopTest();

		TestDataGenerator.getExistMonitoringRules();
		TestDataGenerator.getTestMonitoringImpactRuleLog();
	}

	@IsTest
	static void startSlackIntegrationTest() {
		mockPostProcessingRequests();
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = UserInfo.getOrganizationId();
		TestDataGenerator.startSlackIntegrationTest();
		Test.stopTest();

		TestDataGenerator.getTestSlackRuleLog();
	}

	@IsTest
	static void startJiraRuleTest() {
		mockPostProcessingRequests();
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = UserInfo.getOrganizationId();
		TestDataGenerator.startJiraRuleTest();
		Test.stopTest();

		TestDataGenerator.getTestJiraRuleLog();
	}

	@IsTest
	static void startTestExceptionEmail() {
		Test.startTest();
		try {
			TestDataGenerator.sendTestEmailException();
		}
		catch(Exception e){}
		Test.stopTest();

		TestDataGenerator.getTestEmailExceptionLog();
	}

	@IsTest
	static void sendTestEmailExceptionLogEmail() {
		createTestEmailTemplate(TestDataGenerator.TEST_EMAIL_EXCEPTION_EMAIL_TEMPLATE_NAME);
		Test.startTest();
		TestDataGenerator.sendTestEmailExceptionLogEmail(UserInfo.getUserId(),'');
		Test.stopTest();
	}

	@IsTest
	static void sendMonitoringTestEmail() {
		createTestEmailTemplate(TestDataGenerator.TEST_MONITORING_EVENTS_EMAIL_TEMPLATE_NAME);
		Test.startTest();
		TestDataGenerator.sendMonitoringTestEmail(UserInfo.getUserId(), '');
		Test.stopTest();
	}

	@IsTest
	static void sendConnectedAppReadyEmail() {
		createTestEmailTemplate(TestDataGenerator.CONNECTED_APP_READY_EMAIL_TEMPLATE_NAME);
		Test.startTest();
		TestDataGenerator.sendConnectedAppReadyEmail(UserInfo.getUserId());
		Test.stopTest();
	}

	private static void createTestEmailTemplate(String templateName) {
		EmailTemplate validEmailTemplate = new EmailTemplate();
		validEmailTemplate.isActive = true;
		validEmailTemplate.Name = templateName;
		validEmailTemplate.DeveloperName = templateName;
		validEmailTemplate.TemplateType = 'text';
		validEmailTemplate.Subject = 'test subject';
		validEmailTemplate.Body = 'some test body <link>';
		validEmailTemplate.FolderId = UserInfo.getUserId();

		insert validEmailTemplate;
	}

	@IsTest
	static void testDataGeneratorSchedulerMonitoring() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.MONITORING_EVENTS_KEY_USER, UserInfo.getUserId());
		input.put(TestDataGenerator.MONITORING_EVENTS_KEY_START_TIME, DateTime.now());
		String cronExp = TestDataGenerator.getNextFireTime(Datetime.now().addMinutes(10));
		String jobId = System.schedule('testDataGeneratorSchedulerMonitoring',
			cronExp,
			new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CEHCK_MONITORING_EVENTS, JSON.serialize(input)));
		Test.stopTest();
	}

	@IsTest
	static void testDataGeneratorSchedulerConnectedApp() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.TEST_EMAIL_SERVICE_KEY_USER, UserInfo.getUserId());
		String cronExp = TestDataGenerator.getNextFireTime(Datetime.now().addMinutes(10));
		String jobId = System.schedule('testDataGeneratorSchedulerConnectedApp',
			cronExp,
			new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CHECK_COMPLETE_SETUP_CONNECTED_APP_AND_SEND_EMAIL, JSON.serialize(input)));
		Test.stopTest();
	}

	@IsTest
	static void testDataGeneratorSchedulerTestEmailException() {
		Test.startTest();
		TestDataGenerator.CURRENT_CONNECTED_ORG_TITLE = Test_LogService.CONNECETED_ORG_NAME;
		Map<String, Object> input = new Map<String, Object>();
		input.put(TestDataGenerator.TEST_EMAIL_EXCEPTION_KEY_USER, UserInfo.getUserId());
		input.put(TestDataGenerator.TEST_EMAIL_EXCEPTION_KEY_START_TIME, DateTime.now());
		String cronExp = TestDataGenerator.getNextFireTime(Datetime.now().addMinutes(10));
		String jobId = System.schedule('testDataGeneratorSchedulerTestEmailException',
			cronExp,
			new TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE.CHECK_TEST_EMAIL_EXCEPTION, JSON.serialize(input)));
		Test.stopTest();
	}



	private static void mockPostProcessingRequests() {
		ConnectedOrgService.AuthTokenResponse oAuthResponse = new ConnectedOrgService.AuthTokenResponse();
		oAuthResponse.access_token = 'token';
		oAuthResponse.refresh_token = 'token';

		MonitoringUtilTest.SingleRequestMock getOAuthToken = new MonitoringUtilTest.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(oAuthResponse)
		);

		MonitoringUtilTest.SingleRequestMock monitorDeployments = new MonitoringUtilTest.SingleRequestMock(
			200,
			'OK',
			LogPostProcessingService.PAGE_MONITOR_DEPLOYMENT_STATUS_DEPLOYMENT
		);

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(System.Url.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token', getOAuthToken);
		endpoint2TestResp.put(System.Url.getOrgDomainUrl().toExternalForm() + LogPostProcessingService.PAGE_MONITOR_DEPLOYMENT_URL, monitorDeployments);

		HttpCalloutMock multiCalloutMock = new MonitoringUtilTest.MultiRequestMock(endpoint2TestResp);

		Test.setMock(HttpCalloutMock.class, multiCalloutMock);
	}
}