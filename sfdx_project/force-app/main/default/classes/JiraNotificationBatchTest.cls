@IsTest
public class JiraNotificationBatchTest {

	@TestSetup
	private static void testSetup() {
		Logger_Settings__c settings = Logger_Settings__c.getOrgDefaults();
		settings.Monitoring_Enabled__c = false;
		insert settings;

		Jira_Settings__c jiraSettings = new Jira_Settings__c();
		jiraSettings.Jira_Base_Url__c = 'http://test.jira.com';
		jiraSettings.Jira_API_Url__c = 'http://test.jira.com';
		jiraSettings.Jira_Username__c = 'jirausername';
		jiraSettings.Jira_API_Token__c = 'sometoken';
		jiraSettings.Create_Unique_Tickets_by_Org__c = true;
		insert jiraSettings;

		Jira_Fields_Mapping__c jiraMappings = new Jira_Fields_Mapping__c();
		jiraMappings.Name = ConfigUtil.generateUUID4();
		jiraMappings.Log_Field__c = 'Id';
		jiraMappings.Jira_Field__c = 'Id';
		jiraMappings.Issue_Type_Id__c = '10001';
		insert jiraMappings;

		ConfigUtil.createDefaultJiraAction();
	}

	@IsTest
	private static void test_notifications_slack_positive() {
		test_notifications_slack(true);
	}
	@IsTest
	private static void test_notifications_slack_negative() {
		test_notifications_slack(false);
	}
	private static void test_notifications_slack(Boolean positiveResult) {
		createSlackNotificationRule();

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(ConfigUtil.SLACK_POST_MESSAGE_ENDPOINT, createSlackRequestMock());
		endpoint2TestResp.put(ConfigUtil.SLACK_CONVERSATION_LIST_ENDPOINT, createSlackChannelsRequestMock());

		TestDataFactory.MultiRequestMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		if(positiveResult) {
			TestDataFactory.createSlackSettings();
		}

		Test.startTest();
		Log__c log = TestDataFactory.createTestNotificationLog();

		log.Post_Processing_Status__c = LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED;
		update log;

		log = [SELECT Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING, log.Notification_Integration_Status__c);

		Test.stopTest();
		log = [SELECT Slack_Integration_Status__c, Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		if(positiveResult) {
			System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_COMPLETED, log.Notification_Integration_Status__c);
		}
		else {
			System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_FAILED, log.Notification_Integration_Status__c);
			System.assertNotEquals(null, log.Slack_Integration_Status__c);
		}
	}

	@IsTest
	private static void test_notifications_teams_positive() {
		test_notifications_teams(true);
	}
	@IsTest
	private static void test_notifications_teams_negative() {
		test_notifications_teams(false);
	}
	private static void test_notifications_teams(Boolean positiveResult) {
		createTeamsNotificationRule();

		String endpoint = String.format(GraphAPIService.GRAPH_API_SEND_CHANNEL_MESSAGE, new List<String>{'testTeamId', 'testChannelId'});
		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(endpoint, positiveResult ? getTeamsSendMock(positiveResult) : null);
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_ORGANIZATION_ENDPOINT, getOrganizationMock(true));

		TestDataFactory.MultiRequestMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		PermissionsUtil.TeamsIntegrationEnabled = true;
		TestDataFactory.createTeamsSettings();

		Test.startTest();
		Log__c log = TestDataFactory.createTestNotificationLog();

		log.Post_Processing_Status__c = LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED;
		update log;

		log = [SELECT Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING, log.Notification_Integration_Status__c);

		Test.stopTest();
		log = [SELECT Teams_Integration_Status__c, Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		if(positiveResult) {
			System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_COMPLETED, log.Notification_Integration_Status__c);
		}
		else {
			System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_FAILED, log.Notification_Integration_Status__c);
			System.assertNotEquals(null, log.Teams_Integration_Status__c);
		}
	}

	@IsTest
	private static void test_notifications_pagerDuty_incedent_positive() {
		test_notifications_pagerDuty(true, 'Incident');
	}
	@IsTest
	private static void test_notifications_pagerDuty_incedent_negative() {
		test_notifications_pagerDuty(false, 'Incident');
	}
	@IsTest
	private static void test_notifications_pagerDuty_event_positive() {
		test_notifications_pagerDuty(true, 'Event');
	}
	@IsTest
	private static void test_notifications_pagerDuty_event_negative() {
		test_notifications_pagerDuty(false, 'Event');
	}
	private static void test_notifications_pagerDuty(Boolean positiveResult, String pagerDutyType) {
		createPagerDutyNotificationRule(pagerDutyType);

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(ConfigUtil.PAGER_DUTY_INCIDENT_ENDPOINT, createPagerDutyRequestIncidentMock());
		endpoint2TestResp.put(ConfigUtil.PAGER_DUTY_EVENTS_ENDPOINT, createPagerDutyRequestEventsMock());

		TestDataFactory.MultiRequestMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		if(positiveResult) {
			TestDataFactory.createPagerDutySettings();
		}

		Test.startTest();
		Log__c log = TestDataFactory.createTestNotificationLog();

		log.Post_Processing_Status__c = LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED;
		update log;

		log = [SELECT Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING, log.Notification_Integration_Status__c);

		Test.stopTest();
		log = [SELECT PagerDuty_Integration_Status__c, Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		if(positiveResult) {
			System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_COMPLETED, log.Notification_Integration_Status__c);
		}
		else {
			System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_FAILED, log.Notification_Integration_Status__c);
			System.assertNotEquals(null, log.PagerDuty_Integration_Status__c);
		}

	}

	@IsTest
	private static void test_notifications_email() {
		createEmailNotificationRule();

		Test.startTest();
		Log__c log = TestDataFactory.createTestNotificationLog();

		log.Post_Processing_Status__c = LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED;
		update log;

		log = [SELECT Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING, log.Notification_Integration_Status__c);

		Test.stopTest();
		log = [SELECT Email_Integration_Status__c, Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_COMPLETED, log.Notification_Integration_Status__c);
	}

	private static void createTeamsNotificationRule() {
		TestDataFactory.createNotificationRule(TestDataFactory.createTeamsAction());
	}

	private static void createSlackNotificationRule() {
		TestDataFactory.createNotificationRule(TestDataFactory.createSlackAction());
	}

	private static void createEmailNotificationRule() {
		TestDataFactory.createNotificationRule(TestDataFactory.createEmailAction());
	}

	private static void createPagerDutyNotificationRule(String pagerDutyType) {
		TestDataFactory.createNotificationRule(TestDataFactory.createPagerDutyAction(pagerDutyType));
	}

	@IsTest
	private static void test_all_notifications_positive() {
		createEmailNotificationRule();
		createPagerDutyNotificationRule('Event');
		createSlackNotificationRule();

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(ConfigUtil.PAGER_DUTY_INCIDENT_ENDPOINT, createPagerDutyRequestIncidentMock());
		endpoint2TestResp.put(ConfigUtil.PAGER_DUTY_EVENTS_ENDPOINT, createPagerDutyRequestEventsMock());
		endpoint2TestResp.put(ConfigUtil.SLACK_POST_MESSAGE_ENDPOINT, createSlackRequestMock());
		SingleRequestMock createRelatedTaskMock = createRelatedTaskMock();
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue/createmeta?projectIds=test&issuetypeIds=test&expand=projects.issuetypes.fields', createJiraTicketMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue', createJiraTicketResponseMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue/test/properties/pharos_log', createAddJiraPropertiesMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=project+%3D+%27test%27+AND+labels+%3D+%27h2_hash2%27+AND+statusCategory+%21%3D+%27done%27+ORDER+BY+created+ASC', createJQLSearchByHash2Mock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=project+%3D+%27test%27+AND+labels+%3D+%27h3_hash3%27+AND+statusCategory+%21%3D+%27done%27+ORDER+BY+created+ASC', createJQLSearchByHash3Mock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issueLink', createRelatedTaskMock);


		TestDataFactory.MultiRequestMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		TestDataFactory.createPagerDutySettings();
		TestDataFactory.createSlackSettings();

		createJiraUpdateRule();

		Test.startTest();
		Log__c log = TestDataFactory.createTestNotificationLog();
		log.Post_Processing_Status__c = LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED;
		update log;

		log = [SELECT Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING, log.Notification_Integration_Status__c);

		Test.stopTest();
		log = [SELECT Email_Integration_Status__c, Notification_Integration_Status__c FROM Log__c WHERE Id = :log.Id];
		System.assertEquals(MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_COMPLETED, log.Notification_Integration_Status__c);
	}

	@IsTest
	private static void test_related_open_logs_by_hash1() {
		String orgID = ConfigUtil.generateUUID4().left(15);

		Log__c log3 = new Log__c();
		log3.Hash_1__c = 'hash1';
		log3.Hash_2__c = 'hash2';
		log3.Hash_3__c = 'hash3';
		log3.Bug_Tracker__c = null;
		log3.Organization_Id__c = orgID;
		log3.Jira_Integration_Status__c = ConfigUtil.TICKET_CREATE_ERROR_STATUS;
		log3.Resolved_On__c = null;
		insert log3;

		Log__c log2 = new Log__c();
		log2.Hash_1__c = 'hash1';
		log2.Hash_2__c = 'hash2';
		log2.Hash_3__c = 'hash3';
		log2.Bug_Tracker__c = null;
		log2.Organization_Id__c = orgID;
		log2.Jira_Integration_Status__c = MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING;
		log2.Resolved_On__c = null;
		insert log2;

		Log__c log1 = new Log__c();
		log1.Hash_1__c = 'hash1';
		log1.Hash_2__c = 'hash2';
		log1.Hash_3__c = 'hash3';
		log1.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey';
		log1.Organization_Id__c = orgID;
		log1.Resolved_On__c = Datetime.now();
		insert log1;

		log2 = [SELECT Jira_Integration_Status__c FROM Log__c WHERE Id = :log2.Id];
		System.assertEquals(MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING, log2.Jira_Integration_Status__c);
		log3 = [SELECT Jira_Integration_Status__c FROM Log__c WHERE ID = :log3.Id];
		System.assertEquals(ConfigUtil.TICKET_CREATE_ERROR_STATUS, log3.Jira_Integration_Status__c);

		createJiraUpdateRule();

		Test.startTest();

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		SingleRequestMock createRelatedTaskMock = createRelatedTaskMock();

		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue/createmeta?projectIds=test&issuetypeIds=test&expand=projects.issuetypes.fields', createJiraTicketMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue', createJiraTicketResponseMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue/test/properties/pharos_log', createAddJiraPropertiesMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=project+%3D+%27test%27+AND+labels+%3D+%27h2_hash2%27+AND+statusCategory+%21%3D+%27done%27+ORDER+BY+created+ASC', createJQLSearchByHash2Mock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=project+%3D+%27test%27+AND+labels+%3D+%27h3_hash3%27+AND+statusCategory+%21%3D+%27done%27+ORDER+BY+created+ASC', createJQLSearchByHash3Mock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issueLink', createRelatedTaskMock);

		HttpCalloutMock multiCalloutMock = new MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Database.executeBatch(new JiraNotificationBatch(), 1);

		Test.stopTest();
		log2 = [SELECT Bug_Tracker__c FROM Log__c WHERE Id = :log2.Id LIMIT 1];
		log3 = [SELECT Bug_Tracker__c, Jira_Integration_Status__c FROM Log__c WHERE Id = :log3.Id LIMIT 1];
		System.assertNotEquals(log1.Bug_Tracker__c, log2.Bug_Tracker__c);
		System.assertNotEquals(log1.Bug_Tracker__c, log3.Bug_Tracker__c);
		System.assertEquals(ConfigUtil.EXISTING_TICKET_LINKED_STATUS, log3.Jira_Integration_Status__c);
	}

	@IsTest
	private static void test_related_closed_logs_by_hash1() {
		Log__c log1 = new Log__c();
		log1.Hash_1__c = 'hash1';
		log1.Hash_2__c = 'hash2';
		log1.Hash_3__c = 'hash3';
		log1.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey';
		log1.Organization_Id__c = ConfigUtil.generateUUID4().left(15);
		log1.Resolved_On__c = Datetime.now().addDays(-1);
		insert log1;

		log1 = [SELECT Id, Resolved_On__c, Organization_Id__c, Bug_Tracker__c FROM Log__c WHERE Id = :log1.Id LIMIT 1];
		System.assertNotEquals(null, log1.Resolved_On__c);

		Log__c log2 = new Log__c();
		log2.Hash_1__c = 'hash1';
		log2.Hash_2__c = 'hash2';
		log2.Hash_3__c = 'hash3';
		log2.Bug_Tracker__c = null;
		log2.Organization_Id__c = log1.Organization_Id__c;
		log2.Jira_Integration_Status__c = MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING;
		log2.Resolved_On__c = null;
		insert log2;

		log2 = [SELECT Id, Resolved_On__c, Organization_Id__c, Jira_Integration_Status__c FROM Log__c WHERE Id = :log2.Id LIMIT 1];
		System.assertEquals(MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING, log2.Jira_Integration_Status__c);

		createJiraUpdateRule();

		Test.startTest();

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		SingleRequestMock createRelatedTaskMock = createRelatedTaskMock();

		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue/createmeta?projectIds=test&issuetypeIds=test&expand=projects.issuetypes.fields', createJiraTicketMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue', createJiraTicketResponseMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issue/test/properties/pharos_log', createAddJiraPropertiesMock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=project+%3D+%27test%27+AND+labels+%3D+%27h2_hash2%27+AND+statusCategory+%21%3D+%27done%27+ORDER+BY+created+ASC', createJQLSearchByHash2Mock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=project+%3D+%27test%27+AND+labels+%3D+%27h3_hash3%27+AND+statusCategory+%21%3D+%27done%27+ORDER+BY+created+ASC', createJQLSearchByHash3Mock());
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/issueLink', createRelatedTaskMock);

		HttpCalloutMock multiCalloutMock = new MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Database.executeBatch(new JiraNotificationBatch(), 1);

		Test.stopTest();
		log2 = [SELECT Bug_Tracker__c FROM Log__c WHERE Id = :log2.Id LIMIT 1];
		System.assertNotEquals(log1.Bug_Tracker__c, log2.Bug_Tracker__c);
	}

	private static void createJiraUpdateRule() {
		Rule__c mr1 = new Rule__c();
		mr1.Active__c = true;
		mr1.Type__c = 'JIRA Update';
		mr1.Index__c = 1;
		insert mr1;

		Id recordtypeId = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get('Monitoring').getRecordtypeId();

		Action__c rn1 = new Action__c();
		rn1.RecordTypeId = recordtypeId;
		rn1.Description__c = 'test';
		rn1.Subject__c = 'test';
		rn1.Body__c = 'test';
		rn1.JIRALabels__c = 'test';
		rn1.JIRAComponents__c = 'test';
		rn1.JIRAEpic__c = 'test';
		rn1.JIRAPriority__c = 'test';
		rn1.JIRAProject__c = 'test';
		rn1.JIRAIssueType__c = 'test';
		rn1.Action_Type__c = 'Jira Notification';
		insert rn1;

		RuleAction__c en1 = new RuleAction__c();
		en1.Action__c = rn1.Id;
		en1.Rule__c = mr1.Id;
		insert en1;
	}

	private static SingleRequestMock createJiraTicketMock() {
		JiraService.CreateMeta meta1 = new JiraService.CreateMeta();
		JiraService.CreateMetaProject project1 = new JiraService.CreateMetaProject();
		JiraService.CreateMetaIssueType itype1 = new JiraService.CreateMetaIssueType();
		JiraService.CreateMetaField mfield1 = new JiraService.CreateMetaField();
		mfield1.required = false;
		mfield1.name = 'Epic Link';
		mfield1.key = 'test';

		itype1.id = 'test';
		itype1.name = 'test';
		itype1.fields = new Map<String, JiraService.CreateMetaField>{'test' => mfield1};

		project1.id = 'test';
		project1.key = 'test';
		project1.issuetypes = new List<JiraService.CreateMetaIssueType>{itype1};
		meta1.projects = new List<JiraService.CreateMetaProject>{project1};

		SingleRequestMock getIssueMeta = new SingleRequestMock(
			200,
			'OK',
			JSON.serialize(meta1)
		);
		return getIssueMeta;
	}

	private static SingleRequestMock createAddJiraPropertiesMock() {
		SingleRequestMock addPropertiesMock = new SingleRequestMock(
			201,
			'OK',
			'{}'
		);
		return addPropertiesMock;
	}

	private static SingleRequestMock createJiraTicketResponseMock() {
		JiraService.NewTaskCreatedResponse createdResponse1 = new JiraService.NewTaskCreatedResponse();
		createdResponse1.id = 'test';
		createdResponse1.key = 'test';
		createdResponse1.self = 'test';

		SingleRequestMock createTaskResponse = new SingleRequestMock(
			201,
			'OK',
			JSON.serialize(createdResponse1)
		);
		return createTaskResponse;
	}

	private static SingleRequestMock createJQLSearchByHash2Mock() {
		JiraService.JQLResponse jqlSearchByHash2 = new JiraService.JQLResponse();
		jqlSearchByHash2.total = 0;

		SingleRequestMock searchHash2Mock = new SingleRequestMock(
			200,
			'OK',
			JSON.serialize(jqlSearchByHash2)
		);
		return searchHash2Mock;
	}

	private static SingleRequestMock createJQLSearchByHash3Mock() {
		JiraService.JQLResponse jqlSearchByHash3 = new JiraService.JQLResponse();
		jqlSearchByHash3.total = 0;

		SingleRequestMock searchHash3Mock = new SingleRequestMock(
			200,
			'OK',
			JSON.serialize(jqlSearchByHash3)
		);
		return searchHash3Mock;
	}

	private static SingleRequestMock createRelatedTaskMock() {
		SingleRequestMock createRelatedTaskMock = new SingleRequestMock(
			201,
			'OK',
			'{}'
		);
		return createRelatedTaskMock;
	}

	private static TestDataFactory.SingleRequestMock getTeamsSendMock(Boolean positiveResult) {
		GraphAPIService.ChatMessage wrapper = new GraphAPIService.ChatMessage('testTeamId', 'testChannelId');
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
				positiveResult ? 201 : 500,
				'OK',
				JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock getOrganizationMock(Boolean isValidRequest) {
		GraphAPIService.OrganizationWrapper wrapper = new GraphAPIService.OrganizationWrapper();
		wrapper.value = new List<GraphAPIService.Organization>{
			new GraphAPIService.Organization('testTenantId')
		};
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			isValidRequest ? 200 : 400,
			'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock createSlackRequestMock() {
		TestDataFactory.SingleRequestMock slackRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			'{}'
		);
		return slackRequestMock;
	}

	private static TestDataFactory.SingleRequestMock createSlackChannelsRequestMock() {
		TestDataFactory.SingleRequestMock slackRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
				'{"ok":true, "channels":[{"id":"@test"}]}'
		);
		return slackRequestMock;
	}

	private static TestDataFactory.SingleRequestMock createPagerDutyRequestIncidentMock() {
		TestDataFactory.SingleRequestMock slackRequestMock = new TestDataFactory.SingleRequestMock(
			201,
			'OK',
			'{}'
		);
		return slackRequestMock;
	}

	private static TestDataFactory.SingleRequestMock createPagerDutyRequestEventsMock() {
		TestDataFactory.SingleRequestMock slackRequestMock = new TestDataFactory.SingleRequestMock(
			202,
			'OK',
			'{}'
		);
		return slackRequestMock;
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
}