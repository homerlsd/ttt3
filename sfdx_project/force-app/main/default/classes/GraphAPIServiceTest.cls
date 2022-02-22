@IsTest
private class GraphAPIServiceTest {

	@TestSetup
	private static void testSetup() {
		ConfigUtil.GRAPH_API_SETTINGS.Enabled__c = true;
		ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c = TEST_GRAPH_API_TENANT_ID;
		upsert ConfigUtil.GRAPH_API_SETTINGS;
	}

	@IsTest
	static void test_getTeams() {
		List<GraphAPIService.Team> testTeams;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_ALL_TEAMS_ENDPOINT, getAllTeamsMock());
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		testTeams = GraphAPIService.getTeams();
		Test.stopTest();

		System.assertNotEquals(null, testTeams);
		System.assertEquals(1, testTeams.size());
	}

	@IsTest
	static void test_getTeamChannels() {
		List<GraphAPIService.Channel> testChannels;
		String testEndpoint = String.format(GraphAPIService.GRAPH_API_GET_TEAM_CHANNELS, new List<String>{TEST_GRAPH_API_TEAM_ID});
		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(testEndpoint, getChannelsMock());
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		testChannels = GraphAPIService.getChannels(TEST_GRAPH_API_TEAM_ID);
		Test.stopTest();

		System.assertNotEquals(null, testChannels);
		System.assertEquals(1, testChannels.size());
	}

	@IsTest
	static void test_getOrganization() {
		GraphAPIService.Organization testOrganization;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_ORGANIZATION_ENDPOINT, getOrganizationMock(true));
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		testOrganization = GraphAPIService.getOrganization(TEST_GRAPH_API_TOKEN);
		Test.stopTest();

		System.assertNotEquals(null, testOrganization);
		System.assertEquals(TEST_GRAPH_API_TENANT_ID, testOrganization.id);
	}

	@IsTest
	static void test_sendChannelMessage() {
		GraphAPIService.ChatMessage testChatMessage;
		String endpoint = String.format(GraphAPIService.GRAPH_API_SEND_CHANNEL_MESSAGE, new List<String>{TEST_GRAPH_API_TEAM_ID, TEST_GRAPH_API_TEAM_CHANNEL_ID});
		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(endpoint, getSendChannelMock());
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		testChatMessage = new GraphAPIService.ChatMessage(TEST_GRAPH_API_CHAT_MESSAGE_SUBJECT, TEST_GRAPH_API_CHAT_MESSAGE_BODY);
		testChatMessage = GraphAPIService.sendChannelMessage(TEST_GRAPH_API_TEAM_ID, TEST_GRAPH_API_TEAM_CHANNEL_ID, testChatMessage);
		Test.stopTest();

		System.assertNotEquals(null, testChatMessage);
	}

	@IsTest
	static void test_refresh_token() {
		ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = 'oldRefreshToken';
		upsert ConfigUtil.GRAPH_API_SETTINGS;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_ORGANIZATION_ENDPOINT, getOrganizationMock(false));
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_TOKEN_ENDPOINT, getRefreshTokenMock());
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		PermissionsUtil.TeamsIntegrationEnabled = true;
		GraphAPIService.validateAndRefreshGraphApiOauthToken();
		Test.stopTest();

		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token6__c);
	}

	@IsTest
	static void test_async_refresh_token() {
		ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = 'oldRefreshToken';
		upsert ConfigUtil.GRAPH_API_SETTINGS;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_ORGANIZATION_ENDPOINT, getOrganizationMock(false));
		endpoint2TestResp.put(GraphAPIService.GRAPH_API_GET_TOKEN_ENDPOINT, getRefreshTokenMock());
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		PermissionsUtil.TeamsIntegrationEnabled = true;
		GraphAPIService.validateAndRefreshGraphApiOauthTokenFuture();
		Test.stopTest();

		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token6__c);
	}

	@IsTest
	static void test_getGraphAPIToken() {
		String testToken;

		String endpoint = String.format(GraphAPIService.GET_GRAPH_API_TOKEN_ENDPOINT, new List<String>{TEST_GRAPH_API_TENANT_ID});
		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(endpoint, getTokenMock());
		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		testToken = GraphAPIService.getGraphAPIToken();
		Test.stopTest();

		System.assertNotEquals(null, testToken);
	}

	@IsTest
	static void test_splitToken() {

		Test.startTest();
		GraphAPIService.splitToken(generateRandomString(255*1));
		GraphAPIService.splitToken(generateRandomString(255*2));
		GraphAPIService.splitToken(generateRandomString(255*3));
		GraphAPIService.splitToken(generateRandomString(255*4));
		GraphAPIService.splitToken(generateRandomString(255*5));
		GraphAPIService.splitToken(generateRandomString(255*6));
		Test.stopTest();

		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c);
		System.assertNotEquals(null, ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token6__c);
	}

	private static final String TEST_GRAPH_API_TEAM_ID = 'someTestGraphTeamId';
	private static final String TEST_GRAPH_API_TEAM_DISPLAY_NAME = 'someTestGraphTeamLabel';
	private static final String TEST_GRAPH_API_TEAM_CHANNEL_ID = 'someTestGraphChannelTeamId';
	private static final String TEST_GRAPH_API_TEAM_CHANNEL_DISPLAY_NAME = 'someTestGraphTeamChannelLabel';
	private static final String TEST_GRAPH_API_TENANT_ID = 'someTenantId';
	private static final String TEST_GRAPH_API_TOKEN = 'someToken';
	private static final String TEST_GRAPH_API_TOKEN_ID = 'someTokenId';
	private static final String TEST_GRAPH_API_REFRESH_TOKEN_ID = 'someRefreshTokenId';
	private static final String TEST_GRAPH_API_CHAT_MESSAGE_SUBJECT = 'subject';
	private static final String TEST_GRAPH_API_CHAT_MESSAGE_BODY = 'body';

	public static String generateRandomString(Integer len) {
		final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
		String randStr = '';
		while (randStr.length() < len) {
			Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
			randStr += chars.substring(idx, idx+1);
		}
		return randStr;
	}

	private static TestDataFactory.SingleRequestMock getTokenMock() {
		ConnectedOrgService.AuthTokenResponse wrapper = new ConnectedOrgService.AuthTokenResponse();
		wrapper.access_token = TEST_GRAPH_API_TOKEN_ID;
		wrapper.refresh_token = TEST_GRAPH_API_REFRESH_TOKEN_ID;
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock getRefreshTokenMock() {
		ConnectedOrgService.AuthTokenResponse wrapper = new ConnectedOrgService.AuthTokenResponse();
		wrapper.access_token = TEST_GRAPH_API_TOKEN_ID;
		wrapper.refresh_token = generateRandomString(6*255);
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock getSendChannelMock() {
		GraphAPIService.ChatMessage wrapper = new GraphAPIService.ChatMessage(TEST_GRAPH_API_CHAT_MESSAGE_SUBJECT, TEST_GRAPH_API_CHAT_MESSAGE_BODY);
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			201,
			'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock getOrganizationMock(Boolean isValidRequest) {
		GraphAPIService.OrganizationWrapper wrapper = new GraphAPIService.OrganizationWrapper();
		wrapper.value = new List<GraphAPIService.Organization>{
			new GraphAPIService.Organization(TEST_GRAPH_API_TENANT_ID)
		};
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			isValidRequest ? 200 : 400,
			'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock getChannelsMock() {
		GraphAPIService.TeamChannelWrapper wrapper = new GraphAPIService.TeamChannelWrapper();
		wrapper.value = new List<GraphAPIService.Channel>{
			new GraphAPIService.Channel(TEST_GRAPH_API_TEAM_CHANNEL_ID, TEST_GRAPH_API_TEAM_CHANNEL_DISPLAY_NAME)
		};
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}

	private static TestDataFactory.SingleRequestMock getAllTeamsMock() {
		GraphAPIService.TeamRequestWrapper wrapper = new GraphAPIService.TeamRequestWrapper();
		wrapper.value = new List<GraphAPIService.Team>{
			new GraphAPIService.Team(TEST_GRAPH_API_TEAM_ID, TEST_GRAPH_API_TEAM_DISPLAY_NAME)
		};
		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
		200,
		'OK',
			JSON.serialize(wrapper)
		);
		return singleRequestMock;
	}
}