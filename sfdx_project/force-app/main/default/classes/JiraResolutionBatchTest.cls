@IsTest
private class JiraResolutionBatchTest {

	@TestSetup
	private static void testSetup() {

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

	@IsTest
	static void testLogRegression_positive() {
		Log__c log1 = new Log__c();
		log1.Hash_1__c = 'hash1';
		log1.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey';
		log1.Resolved_On__c = DateTime.now().addDays(-1);
		insert log1;

		Test.startTest();
		Log__c log2 = new Log__c();
		log2.Hash_1__c = 'hash1';
		log2.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey';
		insert log2;
		Test.stopTest();

		log2 = [SELECT Id, Regression__c, Regressed_On__c FROM Log__c WHERE Id =: log2.Id LIMIT 1];
		System.assertEquals(true, log2.Regression__c);
		System.assertNotEquals(null, log2.Regressed_On__c);
	}

	@IsTest
	static void testLogRegression_negative() {
		Log__c log1 = new Log__c();
		log1.Hash_1__c = 'hash1';
		log1.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey';
		insert log1;

		Test.startTest();
		Log__c log2 = new Log__c();
		log2.Hash_1__c = 'hash1';
		log2.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey';
		insert log2;
		Test.stopTest();

		log2 = [SELECT Id, Regression__c, Regressed_On__c FROM Log__c WHERE Id =: log2.Id LIMIT 1];
		System.assertEquals(false, log2.Regression__c);
		System.assertEquals(null, log2.Regressed_On__c);
	}

	@IsTest
	static void testBatch() {
		Log__c log1 = new Log__c();
		log1.Hash_1__c = 'hash1';
		log1.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey1';
		Log__c log2 = new Log__c();
		log2.Hash_1__c = 'hash2';
		log2.Bug_Tracker__c = ConfigUtil.JIRA_TASK_URL + 'TaskKey2';
		insert new List<Log__c>{log1, log2};

		Test.startTest();

		Map<String, Object> jiraData = new Map<String, Object> {
			'issues' => new List<Object> {
				new Map<String, Object> {
					'key' => 'TaskKey1',
					'fields' => new Map<String, Object> {
						'resolutiondate' => '2020-04-24T10:41:33.239-0700'
					}
				},
				new Map<String, Object> {
					'key' => 'TaskKey2',
					'fields' => new Map<String, Object> {
						'resolutiondate' => null
					}
				}
			}

		};

		SingleRequestMock resolutionMock = new SingleRequestMock(
			200,
			'OK',
			JSON.serialize(jiraData)
		);
		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put('http://test.jira.com/rest/api/'+ConfigUtil.API_VERSION+'/search?jql=KEY%20IN%20(TaskKey1,TaskKey2)&fields=resolutiondate&maxResults=100&validateQuery=false', resolutionMock);
		HttpCalloutMock multiCalloutMock = new MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Database.executeBatch( new JiraResolutionBatch(), 100);
		Test.stopTest();

		log1 = [SELECT Id, Resolved_On__c FROM Log__c WHERE Id =: log1.Id LIMIT 1];
		log2 = [SELECT Id, Resolved_On__c FROM Log__c WHERE Id =: log2.Id LIMIT 1];
		System.assertNotEquals(null, log1.Resolved_On__c);
		System.assertEquals(null, log2.Resolved_On__c);
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